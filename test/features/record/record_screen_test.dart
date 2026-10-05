import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/checkin/checkin_controller.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/record/photo_metadata.dart';
import 'package:ramen_in_cho/features/record/photo_picker.dart';
import 'package:ramen_in_cho/features/record/record_draft.dart';
import 'package:ramen_in_cho/features/record/record_result_screen.dart';
import 'package:ramen_in_cho/features/record/record_screen.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/nearby_shop_finder.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';

import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  late AppDatabase database;
  late FakeShopFinder overpass;
  late FakePhotoPicker picker;
  late MemoryRecordDraftStore drafts;

  Future<void> pumpScreen(
    WidgetTester tester, {
    RecordScreen screen = const RecordScreen(),
  }) async {
    database = createTestDatabase();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          // driftの監視はテストの偽の時間の中で止まってしまうため、一覧は固定の値にする。
          visitsProvider.overrideWithValue(const AsyncData([])),
          activeCheckinProvider.overrideWithValue(const AsyncData(null)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          documentsDirectoryProvider.overrideWithValue(createTempDirectory()),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(position: const GeoPoint(35.0, 139.0)),
          ),
          nearbyShopFinderProvider.overrideWithValue(overpass),
          photoPickerProvider.overrideWithValue(picker),
          photoMetadataReaderProvider.overrideWithValue(
            FakePhotoMetadataReader(),
          ),
          recordDraftStoreProvider.overrideWithValue(drafts),
        ],
        child: localizedApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<bool>(builder: (_) => screen)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    picker = FakePhotoPicker();
    drafts = MemoryRecordDraftStore();
    overpass = FakeShopFinder(
      shops: const [
        FoundShop(
          osmId: 'node/1',
          name: '麺屋テスト',
          location: GeoPoint(35.001, 139.0),
        ),
      ],
    );
  });

  testWidgets('候補の店と出典を表示し、店と★を選ぶと「着丼！」で保存して結果を見せる', (tester) async {
    await pumpScreen(tester);

    expect(find.text('麺屋テスト'), findsOneWidget);
    expect(find.text('111m'), findsOneWidget);
    expect(find.text(ja.shopSearchAttribution), findsOneWidget);
    final saveButton = find.widgetWithText(AiFuda, ja.save);
    expect(tester.widget<AiFuda>(saveButton).onPressed, isNull);

    await tester.tap(find.text('麺屋テスト'));
    await tester.pump();
    // ★は食べ終わってから付けることが多いため、店が決まれば保存できる。
    expect(tester.widget<AiFuda>(saveButton).onPressed, isNotNull);
    await tester.tap(find.byTooltip(ja.ratingStar(4)));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(saveButton);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    // 結果の画面は読み込み中の表示が回り続けるため、一定時間だけ進める。
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(RecordScreen), findsNothing);
    expect(find.byType(RecordResultScreen), findsOneWidget);
    final visits = await tester.runAsync(
      () => RecordRepository(database).watchVisits().first,
    );
    expect(visits!.single.shop.name, '麺屋テスト');
    expect(visits.single.visit.rating, 4);
  });

  testWidgets('開いただけではカメラを起動せず、ボタンを押すと起動する。くわしくは最初から開いている', (tester) async {
    await pumpScreen(tester);

    expect(picker.cameraOpens, 0);
    expect(find.text(ja.memoLabel), findsOneWidget);

    await tester.tap(find.text(ja.takePhoto));
    await tester.pumpAndSettle();

    expect(picker.cameraOpens, 1);
  });

  testWidgets('並んでいなければ「いま並んでいる」を出す', (tester) async {
    await pumpScreen(tester);

    expect(find.text(ja.checkinStart), findsOneWidget);
  });

  testWidgets('店名を1文字入れても入力欄が作り直されない（変換中の文字が確定しない）', (tester) async {
    await pumpScreen(tester);
    final field = find.widgetWithText(TextField, ja.shopNameLabel);
    final before = tester.state<EditableTextState>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );

    await tester.enterText(field, 'ら');
    await tester.pump();

    final after = tester.state<EditableTextState>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(identical(before, after), isTrue);
    expect(find.text(ja.checkinStart), findsNothing);
  });

  testWidgets('検索に失敗しても、店名を入力して保存できる', (tester) async {
    overpass.error = const SocketException('offline');
    await pumpScreen(tester);

    expect(find.text(ja.shopSearchFailed), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '電波のない店');
    await tester.tap(find.byTooltip(ja.ratingStar(3)));
    await tester.pump();

    final saveButton = find.widgetWithText(AiFuda, ja.save);
    expect(tester.widget<AiFuda>(saveButton).onPressed, isNotNull);
  });

  Future<void> typeShopAndBack(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextField, ja.shopNameLabel),
      '下書きの店',
    );
    await tester.tap(find.byTooltip(ja.ratingStar(3)));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('何も入れていなければ、戻ると確かめずに閉じる', (tester) async {
    await pumpScreen(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(ja.leaveRecordTitle), findsNothing);
    expect(find.byType(RecordScreen), findsNothing);
  });

  testWidgets('入力して戻ると確かめ、「続ける」なら記録画面に残る', (tester) async {
    await pumpScreen(tester);
    await typeShopAndBack(tester);

    expect(find.text(ja.leaveRecordTitle), findsOneWidget);
    await tester.tap(find.text(ja.leaveRecordCancel));
    await tester.pumpAndSettle();
    expect(find.byType(RecordScreen), findsOneWidget);
    expect(find.text('下書きの店'), findsOneWidget);
    expect(drafts.draft?.manualName, '下書きの店');
  });

  testWidgets('「下書きに残してやめる」で閉じ、次に開くと下書きから再開する', (tester) async {
    await pumpScreen(tester);
    expect(find.text(ja.draftResumed), findsNothing);
    await typeShopAndBack(tester);

    await tester.tap(find.text(ja.leaveRecordKeepDraft));
    await tester.pumpAndSettle();
    expect(find.byType(RecordScreen), findsNothing);
    expect(drafts.draft?.manualName, '下書きの店');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(ja.draftResumed), findsOneWidget);
    expect(find.text('下書きの店'), findsOneWidget);
    final saveButton = find.widgetWithText(AiFuda, ja.save);
    expect(tester.widget<AiFuda>(saveButton).onPressed, isNotNull);
  });

  testWidgets('「破棄してやめる」で下書きを消して閉じ、次に開くと何も入っていない', (tester) async {
    await pumpScreen(tester);
    await typeShopAndBack(tester);

    await tester.tap(find.widgetWithText(KeshiFuda, ja.leaveRecordDiscard));
    await tester.pumpAndSettle();
    expect(find.byType(RecordScreen), findsNothing);
    expect(drafts.draft, isNull);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(ja.draftResumed), findsNothing);
    expect(find.text('下書きの店'), findsNothing);
  });

  testWidgets('写真を渡されて開いたとき下書きがあれば、破棄して新しく記録するか確かめる', (tester) async {
    drafts.draft = const RecordDraft(manualName: '下書きの店');
    await pumpScreen(
      tester,
      screen: const RecordScreen(recoveredPhotoPath: '/tmp/shared.jpg'),
    );

    expect(find.text(ja.draftDiscardTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(KeshiFuda, ja.draftDiscardConfirm));
    await tester.pumpAndSettle();
    expect(find.text('下書きの店'), findsNothing);
    expect(find.text(ja.draftResumed), findsNothing);
    expect(drafts.draft?.photoPath, '/tmp/shared.jpg');
    expect(drafts.draft?.manualName, isEmpty);
  });

  testWidgets('写真を渡されて開き、「下書きの続きから記録する」なら下書きから再開する', (tester) async {
    drafts.draft = const RecordDraft(manualName: '下書きの店');
    await pumpScreen(
      tester,
      screen: const RecordScreen(recoveredPhotoPath: '/tmp/shared.jpg'),
    );

    await tester.tap(find.text(ja.draftDiscardCancel));
    await tester.pumpAndSettle();
    expect(find.text(ja.draftResumed), findsOneWidget);
    expect(find.text('下書きの店'), findsOneWidget);
    expect(drafts.draft?.manualName, '下書きの店');
  });

  testWidgets('写真を渡されて開いても、下書きが無ければ確かめない', (tester) async {
    await pumpScreen(
      tester,
      screen: const RecordScreen(recoveredPhotoPath: '/tmp/shared.jpg'),
    );

    expect(find.text(ja.draftDiscardTitle), findsNothing);
    expect(drafts.draft?.photoPath, '/tmp/shared.jpg');
  });

  testWidgets('「下書きを捨てて新しく」で確かめてから入力を消す', (tester) async {
    drafts.draft = const RecordDraft(manualName: '下書きの店', memo: 'かためで');
    await pumpScreen(tester);
    expect(find.text('下書きの店'), findsOneWidget);

    await tester.tap(find.text(ja.draftDiscard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.draftDiscardCancel));
    await tester.pumpAndSettle();
    expect(find.text('下書きの店'), findsOneWidget);

    await tester.tap(find.text(ja.draftDiscard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.draftDiscardConfirm));
    await tester.pumpAndSettle();
    expect(find.text('下書きの店'), findsNothing);
    expect(find.text('かためで'), findsNothing);
    expect(find.text(ja.draftResumed), findsNothing);
    expect(drafts.draft, isNull);
  });
}
