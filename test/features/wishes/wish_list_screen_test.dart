import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home/app_tab.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_list_screen.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  testWidgets('まだの願と叶った願を分けて見せ、＋で店名から願を掛けられる', (tester) async {
    final repository = FakeWishRepository();
    final shop = buildShop(id: 'shop', name: 'はやし田');
    final eaten = buildEntry(shop: shop, eatenAt: DateTime(2026, 10, 3, 12));
    final wishes = [
      Wish(
        id: 'a',
        shopId: 'shop',
        name: 'はやし田',
        trigger: '同僚に聞いた',
        createdAt: DateTime(2026, 9, 1),
        fulfilledVisitId: eaten.visit.id,
      ),
      Wish(
        id: 'b',
        name: '麺屋ふじみち',
        note: '煮干し',
        createdAt: DateTime(2026, 9, 28),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishRepositoryProvider.overrideWithValue(repository),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(AsyncData(wishes)),
          visitsProvider.overrideWithValue(AsyncData([eaten])),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 3, 18)),
        ],
        child: localizedApp(home: const WishListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ja.wishPendingTab(1)), findsOneWidget);
    expect(find.text(ja.wishFulfilledTab(1)), findsOneWidget);
    expect(find.text('麺屋ふじみち'), findsOneWidget);

    await tester.tap(find.text(ja.wishFulfilledTab(1)));
    await tester.pumpAndSettle();
    expect(find.text('はやし田'), findsOneWidget);
    expect(find.text(ja.wishFulfilledLine('2026/10/3', 32)), findsOneWidget);

    final emaBefore = tester.getRect(find.byType(EmaFab));
    await tester.tap(find.byType(EmaFab));
    await tester.pumpAndSettle();
    // 窓でキーボードが出ても、後ろの絵馬は持ち上がらない。
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(EmaFab)), emaBefore);
    await tester.enterText(find.byType(TextField).first, '豚山');
    await tester.pump();
    await tester.tap(find.text(ja.wishAddButton).last);
    await tester.pumpAndSettle();

    expect(repository.added.single.name, '豚山');
    expect(find.text(ja.wishAdded('豚山')), findsOneWidget);
  });

  group('掛けたばかりの願のしおり', () {
    Future<void> pumpList(WidgetTester tester, String id) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
            wishesProvider.overrideWithValue(
              AsyncData([
                Wish(
                  id: id,
                  name: '麺屋ふじみち',
                  createdAt: DateTime(2026, 10, 3, 17, 59),
                ),
              ]),
            ),
            visitsProvider.overrideWithValue(const AsyncData([])),
            clockProvider.overrideWithValue(() => DateTime(2026, 10, 3, 18)),
            appTabProvider.overrideWith(_WishesTab.new),
          ],
          child: localizedApp(home: const WishListScreen()),
        ),
      );
    }

    Finder sealTransforms() => find.ancestor(
      of: find.text(ja.wishSealChar),
      matching: find.byType(Transform),
    );

    testWidgets('一度だけ揺れて落ち着く', (tester) async {
      await pumpList(tester, 'swing');
      await tester.pump(const Duration(milliseconds: 200));
      final swinging = sealTransforms().evaluate().length;
      await tester.pumpAndSettle();
      expect(sealTransforms().evaluate().length, lessThan(swinging));

      // 一覧を作り直しても、同じ願はもう揺らさない。
      await pumpList(tester, 'swing');
      await tester.pump(const Duration(milliseconds: 200));
      expect(sealTransforms().evaluate().length, lessThan(swinging));
    });

    testWidgets('動きを減らす設定では揺らさない', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpList(tester, 'still');
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('願を左にすべらせると、確かめてから消し、すぐ一覧から外す', (tester) async {
    final repository = FakeWishRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishRepositoryProvider.overrideWithValue(repository),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(
            AsyncData([
              Wish(id: 'b', name: '麺屋ふじみち', createdAt: DateTime(2026, 9, 28)),
            ]),
          ),
          visitsProvider.overrideWithValue(const AsyncData([])),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 3, 18)),
        ],
        child: localizedApp(home: const WishListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('麺屋ふじみち'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text(ja.wishDeleteConfirm('麺屋ふじみち')), findsOneWidget);
    await tester.tap(find.widgetWithText(KeshiFuda, ja.delete));
    await tester.pumpAndSettle();

    expect(repository.deleted, ['b']);
    expect(find.text('麺屋ふじみち'), findsNothing);
  });
  testWidgets('願の「…」の「願を消す」でも、確かめてから消す。やめれば残す', (tester) async {
    final repository = FakeWishRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishRepositoryProvider.overrideWithValue(repository),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(
            AsyncData([
              Wish(id: 'b', name: '麺屋ふじみち', createdAt: DateTime(2026, 9, 28)),
            ]),
          ),
          visitsProvider.overrideWithValue(const AsyncData([])),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 3, 18)),
        ],
        child: localizedApp(home: const WishListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(ja.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.wishDeleteAction));
    await tester.pumpAndSettle();
    expect(find.text(ja.wishDeleteConfirm('麺屋ふじみち')), findsOneWidget);
    await tester.tap(find.text(ja.cancel));
    await tester.pumpAndSettle();
    expect(repository.deleted, isEmpty);
    expect(find.text('麺屋ふじみち'), findsOneWidget);

    await tester.tap(find.byTooltip(ja.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.wishDeleteAction));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KeshiFuda, ja.delete));
    await tester.pumpAndSettle();

    expect(repository.deleted, ['b']);
    expect(find.text('麺屋ふじみち'), findsNothing);
  });
}

class _WishesTab extends AppTabNotifier {
  @override
  AppTab build() => AppTab.wishes;
}
