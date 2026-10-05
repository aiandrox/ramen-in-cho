import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/record/star_rating.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/shop_candidate.dart';
import 'package:ramen_in_cho/features/shop_search/shop_search_service.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/visit_detail/visit_detail_screen.dart';
import 'package:ramen_in_cho/theme/washi.dart';

import 'package:ramen_in_cho/features/journal/journal_phrases.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  late Directory documents;
  late FakeRecordRepository repository;
  late FakeShopSearchService searchService;
  final shop = buildShop(name: '麺屋テスト');

  VisitWithShop entry({
    required String id,
    required DateTime eatenAt,
    int rating = 4,
    String memo = '',
    String? photoPath,
  }) => VisitWithShop(
    shop: shop,
    visit: buildVisit(
      id: id,
      eatenAt: eatenAt,
      rating: rating,
      memo: memo,
      photoPath: photoPath,
      style: RamenStyle.shoyu,
      isLimited: true,
    ),
  );

  Future<void> pumpDetail(
    WidgetTester tester,
    List<VisitWithShop> visits,
    String visitId,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(visits)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          recordRepositoryProvider.overrideWithValue(repository),
          documentsDirectoryProvider.overrideWithValue(documents),
          shopSearchServiceProvider.overrideWithValue(searchService),
        ],
        child: localizedApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VisitDetailScreen(visitId: visitId),
                  ),
                ),
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

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip(ja.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
  }

  Finder stars(int rating) => find.byWidgetPredicate(
    (widget) =>
        widget is Semantics && widget.properties.label == ja.ratingStar(rating),
  );

  setUp(() {
    documents = createTempDirectory();
    repository = FakeRecordRepository();
    searchService = FakeShopSearchService(const ShopSearchResult());
  });

  testWidgets('記録の内容を表示する。初めての店では前回の記録を出さない', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12, 34), memo: 'スープが濃い'),
    ], 'v');

    expect(
      find.byWidgetPredicate((w) => w is VerticalText && w.text == '麺屋テスト'),
      findsOneWidget,
    );
    expect(tester.widget<StarRating>(find.byType(StarRating)).rating, 4);
    // 系統は印の真ん中だけに出す（札にはしない）。
    expect(find.text(ja.styleShoyu), findsOneWidget);
    expect(find.text(ja.limitedBadge), findsOneWidget);
    expect(find.text('スープが濃い'), findsOneWidget);
    expect(find.text(ja.previousVisit), findsNothing);
  });

  testWidgets('★の無い記録は、詳細で★をタップして評価できる', (tester) async {
    await pumpDetail(tester, [
      VisitWithShop(
        shop: shop,
        visit: buildVisit(
          id: 'v',
          eatenAt: DateTime(2026, 9, 30),
          rating: null,
        ),
      ),
    ], 'v');

    await tester.tap(find.byTooltip(ja.ratingStar(4)));
    await tester.pump();

    expect(repository.ratings, {'v': 4});
  });

  testWidgets('★の保存に失敗したら知らせる', (tester) async {
    repository.ratingError = StateError('db');
    await pumpDetail(tester, [
      VisitWithShop(
        shop: shop,
        visit: buildVisit(
          id: 'v',
          eatenAt: DateTime(2026, 9, 30),
          rating: null,
        ),
      ),
    ], 'v');

    await tester.tap(find.byTooltip(ja.ratingStar(4)));
    await tester.pump();

    expect(find.text(ja.editSaveFailed), findsOneWidget);
  });

  testWidgets('店の攻略メモを表示し、書き直せる', (tester) async {
    await pumpDetail(tester, [
      VisitWithShop(
        shop: buildShop(name: '麺屋テスト', strategyMemo: '券売機は現金のみ'),
        visit: buildVisit(id: 'v', eatenAt: DateTime(2026, 9, 30)),
      ),
    ], 'v');

    expect(find.text('券売機は現金のみ'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip(ja.shopMemoEdit));
    await tester.tap(find.byTooltip(ja.shopMemoEdit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' 開店30分前で1巡目 ');
    await tester.tap(find.text(ja.editSave));
    await tester.pumpAndSettle();

    expect(repository.shopMemos, {'shop': '開店30分前で1巡目'});
  });

  testWidgets('攻略メモが無い店は「まだありません」と出す', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30)),
    ], 'v');

    expect(find.text(ja.shopMemoEmpty), findsOneWidget);
  });

  testWidgets('同じ店の2回目は、前回の日付・★・メモを表示する', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'second', eatenAt: DateTime(2026, 9, 30, 12), rating: 3),
      entry(
        id: 'first',
        eatenAt: DateTime(2026, 9, 1, 12),
        rating: 5,
        memo: '前回のメモ',
      ),
    ], 'second');

    expect(find.text(ja.previousVisit), findsOneWidget);
    expect(find.text(ja.journalTitle), findsOneWidget);
    expect(
      repeatOpening
          .fill({'度': '二'})
          .any((line) => find.text(line).evaluate().isNotEmpty),
      isTrue,
    );
    // 前回の記録と、この道場の印の日付の2か所。
    expect(find.text('2026/9/1'), findsNWidgets(2));
    expect(stars(5), findsOneWidget);
    expect(find.text('前回のメモ'), findsOneWidget);
  });

  testWidgets('この道場の印をタップすると、その1杯に切り替わる', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'second', eatenAt: DateTime(2026, 9, 30, 12), rating: 3),
      entry(
        id: 'first',
        eatenAt: DateTime(2026, 9, 1, 12),
        rating: 5,
        memo: '前回のメモ',
      ),
    ], 'second');

    expect(find.text(ja.shopStamps), findsOneWidget);
    expect(tester.widget<StarRating>(find.byType(StarRating)).rating, 3);

    await tester.tap(find.text('2026/9/1').first);
    await tester.pumpAndSettle();

    expect(tester.widget<StarRating>(find.byType(StarRating)).rating, 5);
    expect(find.text(ja.previousVisit), findsNothing);
  });

  testWidgets('この店の記録が1杯だけなら、印の一覧は出さない', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');

    expect(find.text(ja.shopStamps), findsNothing);
  });

  testWidgets('削除を確認すると、記録と写真を消して一覧に戻る', (tester) async {
    final photo = File(p.join(documents.path, 'photos', 'a.jpg'))
      ..createSync(recursive: true);
    repository.deletedPhotoPath = 'photos/a.jpg';
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30), photoPath: 'photos/a.jpg'),
    ], 'v');

    await openMenu(tester, ja.delete);
    await tester.pumpAndSettle();
    expect(find.text(ja.deleteConfirmTitle), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, ja.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(VisitDetailScreen), findsOneWidget);
    expect(repository.deletedVisitIds, isEmpty);

    await openMenu(tester, ja.delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KeshiFuda, ja.delete));
    await tester.pumpAndSettle();
    // ファイルの削除は実時間で進む。
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text(ja.deleteFailed), findsNothing);

    expect(repository.deletedVisitIds, ['v']);
    expect(find.byType(VisitDetailScreen), findsNothing);
    expect(photo.existsSync(), isFalse);
  });

  testWidgets('削除に失敗したら知らせて、画面に残る', (tester) async {
    repository.error = StateError('db');
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30)),
    ], 'v');

    await openMenu(tester, ja.delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KeshiFuda, ja.delete));
    await tester.pumpAndSettle();

    expect(find.text(ja.deleteFailed), findsOneWidget);
    expect(find.byType(VisitDetailScreen), findsOneWidget);
  });

  testWidgets('編集で写真を外して保存すると、写真なしで更新し前の写真を消す', (tester) async {
    final old = File(p.join(documents.path, 'photos', 'old.jpg'))
      ..createSync(recursive: true);
    repository.unusedPhotoPath = 'photos/old.jpg';
    await pumpDetail(tester, [
      entry(
        id: 'v',
        eatenAt: DateTime(2026, 9, 30, 12),
        photoPath: 'photos/old.jpg',
      ),
    ], 'v');

    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.editRemovePhoto));
    await tester.pump();
    expect(find.text(ja.editRemovePhoto), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final update = repository.updates.single;
    expect(update.changesPhoto, isTrue);
    expect(update.photoPath, isNull);
    expect(old.existsSync(), isFalse);
  });

  testWidgets('編集で写真に触れなければ、写真は変えない', (tester) async {
    await pumpDetail(tester, [
      entry(
        id: 'v',
        eatenAt: DateTime(2026, 9, 30, 12),
        photoPath: 'photos/old.jpg',
      ),
    ], 'v');

    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    expect(repository.updates.single.changesPhoto, isFalse);
  });

  testWidgets('編集で店を選び直すと、選んだ店に付け替えて保存する', (tester) async {
    searchService.result = const ShopSearchResult(
      here: GeoPoint(35.0, 139.0),
      candidates: [
        ShopCandidate(
          osmId: 'node/7',
          name: '麺屋ただしい',
          location: GeoPoint(35.0, 139.0),
          distanceMeters: 40,
          hoursConditions: {HoursCondition.nightOnly},
          conditionsFromMap: true,
        ),
      ],
    );
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');

    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.editShopRepick));
    await tester.pumpAndSettle();
    expect(find.text(ja.editShopRepickTitle), findsOneWidget);
    await tester.tap(find.text('麺屋ただしい'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, ja.editShopName))
          .controller!
          .text,
      '麺屋ただしい',
    );
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    final update = repository.updates.single;
    expect(update.pickedShop?.osmId, 'node/7');
    expect(update.pickedShop?.name, '麺屋ただしい');
    expect(update.pickedShop?.latitude, 35.0);
    expect(update.hoursConditions, {HoursCondition.nightOnly});
  });

  testWidgets('選び直したあとで店名を書き換えたら、店名のほうで保存する', (tester) async {
    searchService.result = const ShopSearchResult(
      here: GeoPoint(35.0, 139.0),
      candidates: [
        ShopCandidate(
          osmId: 'node/7',
          name: '麺屋ただしい',
          location: GeoPoint(35.0, 139.0),
        ),
      ],
    );
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');

    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.editShopRepick));
    await tester.pumpAndSettle();
    await tester.tap(find.text('麺屋ただしい'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, ja.editShopName),
      '麺屋てにゅうりょく',
    );
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    final update = repository.updates.single;
    expect(update.pickedShop, isNull);
    expect(update.shopName, '麺屋てにゅうりょく');
  });

  testWidgets('通信できず候補が無くても、案内を出して店名で保存できる', (tester) async {
    searchService.result = const ShopSearchResult(
      here: GeoPoint(35.0, 139.0),
      failure: ShopSearchFailure.searchFailed,
    );
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');

    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.editShopRepick));
    await tester.pumpAndSettle();
    expect(find.text(ja.editShopRepickFailed), findsOneWidget);
    expect(find.text(ja.editShopRepickByName), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();
    final update = repository.updates.single;
    expect(update.pickedShop, isNull);
    expect(update.shopName, '麺屋テスト');
  });

  testWidgets('編集して保存すると、変更した内容で更新して詳細に戻る', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');

    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();
    expect(find.text(ja.editTitle), findsOneWidget);

    await tester.tap(find.byTooltip(ja.ratingStar(2)));
    await tester.enterText(
      find.widgetWithText(TextField, ja.memoLabel),
      ' 書き直した ',
    );
    final fewDays = find.widgetWithText(FilterChip, ja.hoursFewDays);
    await tester.ensureVisible(fewDays);
    await tester.pumpAndSettle();
    await tester.tap(fewDays);
    await tester.pump();
    final lunchOnly = find.widgetWithText(FilterChip, ja.hoursLunchOnly);
    await tester.ensureVisible(lunchOnly);
    await tester.pumpAndSettle();
    await tester.tap(lunchOnly);
    await tester.pump();
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    expect(find.text(ja.editTitle), findsNothing);
    final update = repository.updates.single;
    expect(update.visitId, 'v');
    expect(update.shopName, '麺屋テスト');
    expect(update.rating, 2);
    expect(update.memo, '書き直した');
    expect(update.hoursConditions, {
      HoursCondition.lunchOnly,
      HoursCondition.fewDays,
    });
    expect(update.eatenAt, DateTime(2026, 9, 30, 12));
    expect(update.style, RamenStyle.shoyu);
    expect(update.isLimited, isTrue);
  });

  testWidgets('待ち時間をあとから入れると、その分前を並んだ時刻にする', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    final wait = find.widgetWithText(TextField, ja.waitMinutesLabel);
    await tester.ensureVisible(wait);
    await tester.enterText(wait, '45');
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    expect(
      repository.updates.single.checkedInAt,
      DateTime(2026, 9, 30, 11, 15),
    );
  });

  testWidgets('待ち時間に触らなければ、並んだ時刻はそのまま', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    expect(repository.updates.single.checkedInAt, isNull);
  });

  testWidgets('待ち時間に触らずに日時だけ変えると、並んだ時刻も一緒にずらす', (tester) async {
    await pumpDetail(tester, [
      VisitWithShop(
        shop: shop,
        visit: buildVisit(
          id: 'v',
          eatenAt: DateTime(2026, 9, 30, 12),
          waitMinutes: 0,
        ),
      ),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.editEatenAt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('29'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    final update = repository.updates.single;
    expect(update.eatenAt, DateTime(2026, 9, 29, 12));
    expect(update.checkedInAt, DateTime(2026, 9, 29, 12));
  });

  testWidgets('営業の条件を変えずに保存したときは、変更なしとして渡す', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    expect(repository.updates.single.hoursConditions, isNull);
  });

  testWidgets('店名を空にすると保存できない', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, ja.editShopName),
      '  ',
    );
    await tester.pump();

    final saveButton = find.widgetWithText(AiFuda, ja.editSave);
    expect(tester.widget<AiFuda>(saveButton).onPressed, isNull);
  });
}
