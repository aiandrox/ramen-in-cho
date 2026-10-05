import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        name: '麺屋藤ろう',
        note: '煮干し',
        createdAt: DateTime(2026, 9, 28),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishRepositoryProvider.overrideWithValue(repository),
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
    expect(find.text('麺屋藤ろう'), findsOneWidget);

    await tester.tap(find.text(ja.wishFulfilledTab(1)));
    await tester.pumpAndSettle();
    expect(find.text('はやし田'), findsOneWidget);
    expect(find.text(ja.wishFulfilledLine('2026/10/3', 32)), findsOneWidget);

    await tester.tap(find.byType(ShioriFab));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '豚山');
    await tester.pump();
    await tester.tap(find.text(ja.wishAddButton).last);
    await tester.pumpAndSettle();

    expect(repository.added.single.name, '豚山');
    expect(find.text(ja.wishAdded('豚山')), findsOneWidget);
  });

  testWidgets('願を左にすべらせると、確かめてから消し、すぐ一覧から外す', (tester) async {
    final repository = FakeWishRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishRepositoryProvider.overrideWithValue(repository),
          wishesProvider.overrideWithValue(
            AsyncData([
              Wish(id: 'b', name: '麺屋藤ろう', createdAt: DateTime(2026, 9, 28)),
            ]),
          ),
          visitsProvider.overrideWithValue(const AsyncData([])),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 3, 18)),
        ],
        child: localizedApp(home: const WishListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('麺屋藤ろう'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text(ja.wishDeleteConfirm('麺屋藤ろう')), findsOneWidget);
    await tester.tap(find.widgetWithText(KeshiFuda, ja.delete));
    await tester.pumpAndSettle();

    expect(repository.deleted, ['b']);
    expect(find.text('麺屋藤ろう'), findsNothing);
  });
}
