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
import 'package:ramen_in_cho/features/records/visit_details_form.dart';
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

/// 名店の印の切り替えを、下の保存ボタンに隠れない位置まで出す。
Future<void> showFamous(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(VisitDetailsForm.shopFamousSwitchKey));
  await tester.drag(find.byType(ListView).first, const Offset(0, -200));
  await tester.pumpAndSettle();
}

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

  testWidgets('店の覚え書きを表示し、書き直せる', (tester) async {
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

  testWidgets('店のページで名店の印をつけ外しできる', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30)),
    ], 'v');

    final toggle = find.widgetWithText(SwitchListTile, ja.shopFamousToggle);
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(repository.famousShops, {'shop': true});
  });

  testWidgets('店の覚え書きが無い店は「まだありません」と出す', (tester) async {
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

    expect(find.text('前回の記録'), findsNothing);
    expect(find.text(ja.journalTitle), findsOneWidget);
    expect(
      repeatOpening
          .fill({'度': '二'})
          .any((line) => find.text(line).evaluate().isNotEmpty),
      isTrue,
    );
    // 前の1杯は、この道場の印の日付からたどれる。
    expect(find.text('2026/9/1'), findsOneWidget);
    expect(find.text('前回のメモ'), findsNothing);
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
    expect(find.textContaining(ja.deleteConfirmLastOfShop), findsOneWidget);
    expect(find.textContaining(ja.deleteConfirmPhoto), findsOneWidget);

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

  testWidgets('店にほかの記録があれば、削除の確認でそれが残ると伝える', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30)),
      entry(id: 'w', eatenAt: DateTime(2026, 9, 20)),
      entry(id: 'x', eatenAt: DateTime(2026, 9, 10)),
    ], 'v');

    await openMenu(tester, ja.delete);
    await tester.pumpAndSettle();

    expect(find.textContaining(ja.deleteConfirmOthersKept(2)), findsOneWidget);
    expect(find.textContaining(ja.deleteConfirmLastOfShop), findsNothing);
    // 写真の無い記録では、写真のことは書かない。
    expect(find.textContaining(ja.deleteConfirmPhoto), findsNothing);
  });

  testWidgets('撤退の記録の削除は、撤退の記録として確かめる', (tester) async {
    await pumpDetail(tester, [
      VisitWithShop(
        shop: shop,
        visit: buildVisit(
          id: 'r',
          shopId: shop.id,
          result: VisitResult.retreated,
          rating: null,
        ),
      ),
    ], 'r');

    await openMenu(tester, ja.delete);
    await tester.pumpAndSettle();

    expect(find.text(ja.deleteRetreatConfirmTitle), findsOneWidget);
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
    await tester.tap(find.byTooltip(ja.editRemovePhoto));
    await tester.pump();
    expect(find.byTooltip(ja.editRemovePhoto), findsNothing);
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
      find.byKey(VisitDetailsForm.memoFieldKey),
      ' 書き直した ',
    );
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    expect(find.text(ja.editTitle), findsNothing);
    final update = repository.updates.single;
    expect(update.visitId, 'v');
    expect(update.shopName, '麺屋テスト');
    expect(update.rating, 2);
    expect(update.memo, '書き直した');
    expect(update.eatenAt, DateTime(2026, 9, 30, 12));
    expect(update.style, RamenStyle.shoyu);
    expect(update.isLimited, isTrue);
    // 店の覚え書きに触らなければ、店には書かない。
    expect(update.shopMemo, isNull);
  });

  testWidgets('編集画面で「この一杯について」と「店の覚え書き」を両方書き直せる', (tester) async {
    await pumpDetail(tester, [
      VisitWithShop(
        shop: buildShop(name: '麺屋テスト', strategyMemo: '券売機は現金のみ'),
        visit: buildVisit(
          id: 'v',
          eatenAt: DateTime(2026, 9, 30),
          memo: '麺かため',
        ),
      ),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    final memo = find.byKey(VisitDetailsForm.memoFieldKey);
    final shopMemo = find.byKey(VisitDetailsForm.shopMemoFieldKey);
    await tester.ensureVisible(shopMemo);
    expect(tester.widget<TextField>(memo).controller!.text, '麺かため');
    expect(tester.widget<TextField>(shopMemo).controller!.text, '券売機は現金のみ');

    await tester.enterText(memo, '前よりスープが濃い');
    await tester.enterText(shopMemo, ' 11時前に着けば一巡目 ');
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    final update = repository.updates.single;
    expect(update.memo, '前よりスープが濃い');
    expect(update.shopMemo, '11時前に着けば一巡目');
  });

  testWidgets('店名を打ち直して別の店にするときは、店の覚え書きの欄を押せなくし店にも書かない', (tester) async {
    await pumpDetail(tester, [
      VisitWithShop(
        shop: buildShop(name: '麺屋テスト', strategyMemo: '券売機は現金のみ'),
        visit: buildVisit(id: 'v', eatenAt: DateTime(2026, 9, 30)),
      ),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    final shopMemo = find.byKey(VisitDetailsForm.shopMemoFieldKey);
    await tester.ensureVisible(shopMemo);
    await tester.enterText(shopMemo, '書きかけ');
    final name = find.widgetWithText(TextField, ja.editShopName);
    final list = find.byType(ListView).first;
    await tester.dragUntilVisible(name, list, const Offset(0, 300));
    await tester.enterText(name, '別の店');
    await tester.pump();
    final disabled = find.byKey(VisitDetailsForm.shopMemoDisabledFieldKey);
    await tester.dragUntilVisible(disabled, list, const Offset(0, -300));
    expect(shopMemo, findsNothing);
    expect(tester.widget<TextField>(disabled).enabled, isFalse);
    expect(find.text('書きかけ'), findsNothing);

    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();
    expect(repository.updates.single.shopMemo, isNull);
  });

  testWidgets('編集画面で名店の印を付け外しでき、触らなければ店には書かない', (tester) async {
    await pumpDetail(tester, [
      VisitWithShop(
        shop: buildShop(name: '麺屋テスト'),
        visit: buildVisit(id: 'v', eatenAt: DateTime(2026, 9, 30)),
      ),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    final famous = find.byKey(VisitDetailsForm.shopFamousSwitchKey);
    await showFamous(tester);
    expect(tester.widget<SwitchListTile>(famous).value, isFalse);
    await tester.tap(famous);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(famous).value, isTrue);
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();
    expect(repository.updates.single.shopFamous, isTrue);

    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();
    expect(repository.updates.last.shopFamous, isNull);
  });

  testWidgets('店名を打ち直して別の店にするときは、名店の印を押せなくし店にも書かない', (tester) async {
    await pumpDetail(tester, [
      VisitWithShop(
        shop: buildShop(name: '麺屋テスト', isFamous: true),
        visit: buildVisit(id: 'v', eatenAt: DateTime(2026, 9, 30)),
      ),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    final famous = find.byKey(VisitDetailsForm.shopFamousSwitchKey);
    await showFamous(tester);
    expect(tester.widget<SwitchListTile>(famous).value, isTrue);
    await tester.tap(famous);
    await tester.pump();
    final name = find.widgetWithText(TextField, ja.editShopName);
    final list = find.byType(ListView).first;
    await tester.dragUntilVisible(name, list, const Offset(0, 300));
    await tester.enterText(name, '別の店');
    await tester.pump();
    await tester.dragUntilVisible(famous, list, const Offset(0, -300));
    expect(tester.widget<SwitchListTile>(famous).onChanged, isNull);
    expect(find.text(ja.shopFamousNeedsShop), findsOneWidget);

    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();
    expect(repository.updates.single.shopFamous, isNull);
  });

  testWidgets('待ち時間をあとから入れると、その分前を並んだ時刻にする', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    final wait = find.byKey(VisitDetailsForm.waitFieldKey);
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

  testWidgets('編集で何も変えなければ、戻るときに何も聞かない', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text(ja.editLeaveTitle), findsNothing);
    expect(find.text(ja.editTitle), findsNothing);
  });

  testWidgets('編集で変えてから戻ると確かめ、「編集を続ける」なら画面に残る', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(VisitDetailsForm.memoFieldKey), '書き直した');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(ja.editLeaveTitle), findsOneWidget);
    await tester.tap(find.text(ja.editLeaveContinue));
    await tester.pumpAndSettle();

    expect(find.text(ja.editTitle), findsOneWidget);
    expect(find.text('書き直した'), findsOneWidget);
    expect(repository.updates, isEmpty);
  });

  testWidgets('編集で変えてから戻り「戻る」を選ぶと、保存せずに閉じる', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(ja.ratingStar(2)));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ja.editLeaveDiscard));
    await tester.pumpAndSettle();

    expect(find.text(ja.editTitle), findsNothing);
    expect(repository.updates, isEmpty);
  });

  testWidgets('編集で変えて保存すると、確かめずに閉じる', (tester) async {
    await pumpDetail(tester, [
      entry(id: 'v', eatenAt: DateTime(2026, 9, 30, 12)),
    ], 'v');
    await openMenu(tester, ja.edit);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(ja.ratingStar(2)));
    await tester.tap(find.widgetWithText(AiFuda, ja.editSave));
    await tester.pumpAndSettle();

    expect(find.text(ja.editLeaveTitle), findsNothing);
    expect(find.text(ja.editTitle), findsNothing);
    expect(repository.updates, hasLength(1));
  });
}
