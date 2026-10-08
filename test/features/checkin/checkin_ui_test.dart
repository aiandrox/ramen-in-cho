import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/checkin/checkin_banner.dart';
import 'package:ramen_in_cho/features/checkin/checkin_screen.dart';
import 'package:ramen_in_cho/features/checkin/retreat_screen.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/shop_candidate.dart';
import 'package:ramen_in_cho/features/shop_search/shop_search_service.dart';
import 'package:ramen_in_cho/features/words/words.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';

import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  late FakeRecordRepository repository;
  final now = DateTime(2026, 9, 30, 12);

  setUp(() => repository = FakeRecordRepository());

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    ShopSearchResult search = const ShopSearchResult(),
    List<VisitWithShop> visits = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordRepositoryProvider.overrideWithValue(repository),
          visitsProvider.overrideWithValue(AsyncData(visits)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          shopSearchServiceProvider.overrideWithValue(
            FakeShopSearchService(search),
          ),
          clockProvider.overrideWithValue(() => now),
        ],
        child: localizedApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('RetreatScreen', () {
    const nearAndFar = ShopSearchResult(
      here: GeoPoint(35.0, 139.0),
      candidates: [
        ShopCandidate(osmId: 'node/near', name: '近い店', distanceMeters: 56),
        ShopCandidate(
          osmId: 'node/far',
          name: '遠い店',
          location: GeoPoint(35.002, 139.0),
          distanceMeters: 222,
        ),
      ],
    );

    testWidgets('100mより遠い店でも選べ、撤退の窓で理由を選ぶと撤退を残す', (tester) async {
      await pump(tester, const RetreatScreen(), search: nearAndFar);

      expect(find.text(ja.retreatPickHint), findsOneWidget);
      expect(find.text('222m'), findsOneWidget);

      await tester.tap(find.text('遠い店'));
      await tester.pumpAndSettle();
      expect(find.text(ja.retreatTitle), findsOneWidget);
      await tester.tap(find.text(ja.retreatReasonSoldOut));
      await tester.pump();
      await tester.tap(find.widgetWithText(KeshiFuda, ja.retreatConfirm));
      await tester.pumpAndSettle();

      final shop = repository.retreatShops.single;
      expect(shop.osmId, 'node/far');
      expect(shop.latitude, 35.002);
      expect(repository.retreatMemos.single, ja.retreatReasonSoldOut);
      expect(repository.retreatWishTriggers.single, ja.wishTriggerRetreat);
      expect(repository.cancelCount, 0);
      expect(find.byType(RetreatScreen), findsNothing);
    });

    testWidgets('撤退の窓でやめれば、何も残さず店選びに戻る', (tester) async {
      await pump(tester, const RetreatScreen(), search: nearAndFar);

      await tester.tap(find.text('近い店'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.cancel));
      await tester.pumpAndSettle();

      expect(repository.retreatShops, isEmpty);
      expect(find.byType(RetreatScreen), findsOneWidget);
    });

    testWidgets('現在地がわからなくても、店名を入力して撤退を残せる', (tester) async {
      await pump(
        tester,
        const RetreatScreen(),
        search: const ShopSearchResult(failure: ShopSearchFailure.noLocation),
      );

      expect(find.text(ja.shopNoLocation), findsOneWidget);
      final button = find.widgetWithText(SumiFuda, ja.retreatManualButton);
      expect(tester.widget<SumiFuda>(button).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '休みだった店');
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(KeshiFuda, ja.retreatConfirm));
      await tester.pumpAndSettle();

      final shop = repository.retreatShops.single;
      expect(shop.name, '休みだった店');
      expect(shop.latitude, isNull);
    });
  });

  group('CheckinScreen', () {
    const nearAndFar = ShopSearchResult(
      here: GeoPoint(35.0, 139.0),
      candidates: [
        ShopCandidate(osmId: 'node/near', name: '近い店', distanceMeters: 56),
        ShopCandidate(osmId: 'node/far', name: '遠い店', distanceMeters: 222),
      ],
    );

    testWidgets('100mより遠い店は選べず、近づくよう案内する', (tester) async {
      await pump(tester, const CheckinScreen(), search: nearAndFar);

      expect(find.text('56m'), findsOneWidget);
      expect(find.text('222m・${ja.checkinTooFar}'), findsOneWidget);
      expect(find.text(ja.sourceCreditYahoo), findsOneWidget);

      await tester.tap(find.text('遠い店'));
      await tester.pumpAndSettle();

      expect(repository.checkins, isEmpty);
      expect(find.byType(CheckinScreen), findsOneWidget);
    });

    testWidgets('近い店をタップするとチェックインする', (tester) async {
      await pump(tester, const CheckinScreen(), search: nearAndFar);

      await tester.tap(find.text('近い店'));
      await tester.pumpAndSettle();

      expect(repository.checkins.single.osmId, 'node/near');
    });

    testWidgets('候補が無くても、店名を入力してチェックインできる', (tester) async {
      await pump(
        tester,
        const CheckinScreen(),
        search: const ShopSearchResult(
          here: GeoPoint(35.0, 139.0),
          failure: ShopSearchFailure.searchFailed,
        ),
      );

      expect(find.text(ja.checkinSearchFailed), findsOneWidget);
      final button = find.widgetWithText(SumiFuda, ja.checkinManualButton);
      expect(tester.widget<SumiFuda>(button).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '電波のない店');
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();

      final checkin = repository.checkins.single;
      expect(checkin.name, '電波のない店');
      expect(checkin.latitude, 35.0);
    });

    testWidgets('現在地がわからないときは、手入力の欄を出さず再検索を促す', (tester) async {
      await pump(
        tester,
        const CheckinScreen(),
        search: const ShopSearchResult(failure: ShopSearchFailure.noLocation),
      );

      expect(find.text(ja.checkinNoLocation), findsOneWidget);
      expect(find.text(ja.checkinRetry), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('CheckinBanner', () {
    final checkin = Checkin(
      name: '麺屋テスト',
      checkedInAt: now.subtract(const Duration(minutes: 35)),
    );
    final banner = Scaffold(body: CheckinBanner(checkin: checkin));

    testWidgets('並んでいる店の覚え書きがあれば一緒に出す', (tester) async {
      final shop = Shop(
        id: 'shop',
        name: '麺屋テスト',
        strategyMemo: '開店30分前で1巡目',
        createdAt: now,
      );
      await pump(
        tester,
        Scaffold(
          body: CheckinBanner(
            checkin: Checkin(shopId: 'shop', name: '麺屋テスト', checkedInAt: now),
          ),
        ),
        visits: [
          VisitWithShop(
            shop: shop,
            visit: Visit(
              id: 'v',
              shopId: 'shop',
              result: VisitResult.eaten,
              eatenAt: now,
              isLimited: false,
              memo: '',
              createdAt: now,
            ),
          ),
        ],
      );

      expect(find.text(ja.shopMemoInline('開店30分前で1巡目')), findsOneWidget);
    });

    testWidgets('並んでいる店と経過時間を表示する', (tester) async {
      await pump(tester, banner);

      expect(find.text(ja.checkinBanner('麺屋テスト')), findsOneWidget);
      expect(find.text(ja.checkinWaiting(35)), findsOneWidget);
    });

    testWidgets('取り消しは確認してから行う', (tester) async {
      await pump(tester, banner);

      await tester.tap(find.text(ja.checkinCancelBanner));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.checkinKeep));
      await tester.pumpAndSettle();
      expect(repository.cancelCount, 0);

      await tester.tap(find.text(ja.checkinCancelBanner));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(KeshiFuda, ja.checkinCancel));
      await tester.pumpAndSettle();
      expect(repository.cancelCount, 1);
    });

    testWidgets('撤退は理由を選んで記録できる', (tester) async {
      await pump(tester, banner);

      await tester.tap(find.text(ja.checkinRetreat));
      await tester.pumpAndSettle();
      expect(find.text(ja.retreatTitle), findsOneWidget);

      await tester.tap(find.text(ja.retreatReasonSoldOut));
      await tester.pump();
      await tester.tap(find.text(ja.retreatConfirm));
      await tester.pumpAndSettle();

      expect(repository.retreatMemos, [ja.retreatReasonSoldOut]);
      expect(
        find.text(
          '${ja.retreatSaved}\n${retreatConsolation(ja.retreatReasonSoldOut, 'retreat')}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('撤退をキャンセルすると何も記録しない', (tester) async {
      await pump(tester, banner);

      await tester.tap(find.text(ja.checkinRetreat));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.cancel));
      await tester.pumpAndSettle();

      expect(repository.retreatMemos, isEmpty);
    });
  });
}
