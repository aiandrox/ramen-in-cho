import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/journal/shugyoroku.dart';
import 'package:ramen_in_cho/features/journal/shugyoroku_screen.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

import '../../support/builders.dart';
import '../../support/l10n.dart';

void main() {
  final shop = buildShop(id: 'shop', name: 'はやし田');

  List<VisitWithShop> entries() => [
    buildEntry(shop: shop, eatenAt: DateTime(2025, 12, 30, 12)),
    buildEntry(shop: shop, eatenAt: DateTime(2026, 3, 5, 12)),
    buildEntry(
      shop: shop,
      eatenAt: DateTime(2026, 1, 10, 12),
      result: VisitResult.retreated,
    ),
    buildEntry(shop: shop, eatenAt: DateTime(2026, 1, 20, 12)),
  ];

  test('記録のある年を新しい順に返す', () {
    expect(shugyorokuYears(scoreVisits(entries())), [2026, 2025]);
  });

  test('その年の道中記を、古い順に月ごとの章にまとめる。撤退も物語に入れる', () {
    final months = shugyoroku(scoreVisits(entries()), 2026);

    expect(months.map((m) => m.month), [1, 3]);
    expect(months.first.entries.map((e) => e.scored.visit.eatenAt.day), [
      10,
      20,
    ]);
    expect(months.first.entries.first.journal.join(), contains('撤退'));
    // 前の年の記録も数えるので、2026年1月20日の1杯は「2度目」。
    expect(months.first.entries.last.journal.first, contains('二'));
  });

  testWidgets('修行録は年を選べ、月の章と1杯ごとの道中記を出す', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(entries())),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
        ],
        child: localizedApp(home: const ShugyorokuScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ja.shugyorokuChapter(2026, 1)), findsOneWidget);
    expect(find.text(ja.shugyorokuChapter(2026, 3)), findsOneWidget);
    expect(find.text(ja.shugyorokuEntryTitle(1, 20, 'はやし田')), findsOneWidget);

    await tester.tap(find.text(ja.journeyYear(2025)));
    await tester.pumpAndSettle();
    expect(find.text(ja.shugyorokuChapter(2025, 12)), findsOneWidget);
    expect(find.text(ja.shugyorokuChapter(2026, 1)), findsNothing);
  });

  testWidgets('記録が無ければ、最初の一杯から始まると案内する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(const AsyncData([])),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
        ],
        child: localizedApp(home: const ShugyorokuScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ja.shugyorokuEmpty), findsOneWidget);
  });
}
