import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/quests/quest_list_screen.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/quests/quest_seal.dart';

import '../../support/builders.dart';
import '../../support/l10n.dart';

void main() {
  Future<void> pumpQuests(
    WidgetTester tester,
    List<VisitWithShop> visits,
  ) async {
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(visits)),
          wishesProvider.overrideWithValue(const AsyncData([])),
        ],
        child: localizedApp(
          home: Scaffold(body: ListView(children: const [QuestSections()])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('常設とスポットに分けて表示する。記録が無ければ秘伝は隠す', (tester) async {
    await pumpQuests(tester, const []);

    expect(find.text(ja.questStanding), findsOneWidget);
    expect(find.text(ja.questSpot), findsOneWidget);
    expect(find.text(ja.questLevelTotal(0)), findsNothing);
    expect(find.text(ja.questSpotSummary(0, 8)), findsNothing);
    expect(find.text('着丼の道'), findsOneWidget);
    expect(find.text('はじめての着丼'), findsNothing);
    expect(find.text(ja.questSpotNone), findsOneWidget);
    expect(find.text(ja.questCount(0, '杯')), findsWidgets);
    final seals = tester.widgetList<QuestSeal>(find.byType(QuestSeal));
    expect(seals.map((seal) => seal.level).toSet(), {0});
    expect(find.text(ja.questLocked), findsNWidgets(seals.length));
  });

  testWidgets('常設はレベルと次の段階まで、スポットは達成と達成日を出す', (tester) async {
    final shop = buildShop(id: 'shop');
    await pumpQuests(tester, [
      for (var d = 1; d <= 10; d++)
        buildEntry(shop: shop, eatenAt: DateTime(2026, 9, d, 12)),
    ]);

    // 着丼の道は10杯で Lv.2（次は30杯）。
    expect(find.text(ja.questCount(10, '杯')), findsOneWidget);
    // 会得した秘伝（はじめての着丼）だけを、独自の印で出す。
    expect(find.text('はじめての着丼'), findsOneWidget);
    expect(find.text('初'), findsOneWidget);
    expect(find.text('60分の試練'), findsNothing);
    expect(find.text(ja.questSpotSummary(1, 8)), findsNothing);
    expect(find.text(daijiNumber(2)), findsOneWidget);

    // 印をタップすると、会得した店を出し、その一杯へ行ける（日付は印の中だけ）。
    await tester.tap(find.text('はじめての着丼'));
    await tester.pumpAndSettle();
    expect(find.text(ja.questSpotAchievedShop('shop')), findsOneWidget);
    expect(find.textContaining('2026/9/1'), findsNothing);
    expect(find.text(ja.questSpotOpenShop), findsOneWidget);
  });

  testWidgets('秘伝の印は横幅いっぱいに同じ幅で並べる', (tester) async {
    final shop = buildShop(id: 'shop');
    await pumpQuests(tester, [
      buildEntry(shop: shop, eatenAt: DateTime(2026, 9, 1, 12)),
    ]);

    // 幅 432 に 4 つ（間は 8）: (432 - 8 * 3) / 4 = 102。
    final seal = find.ancestor(
      of: find.text('はじめての着丼'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(seal).width, closeTo(102, 0.1));
    expect(tester.getTopLeft(seal).dx, 0);
  });

  testWidgets('秘伝の窓は下のタブの上ではなく、画面の下端から出す', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final shop = buildShop(id: 'shop');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(
            AsyncData([
              buildEntry(shop: shop, eatenAt: DateTime(2026, 9, 1, 12)),
            ]),
          ),
          wishesProvider.overrideWithValue(const AsyncData([])),
        ],
        child: localizedApp(
          // タブの中に別の Navigator があっても、窓はタブを覆って出る。
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) =>
                    Scaffold(body: ListView(children: const [QuestSections()])),
              ),
            ),
            bottomNavigationBar: const SizedBox(height: 80),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('はじめての着丼'));
    await tester.pumpAndSettle();
    expect(find.text(ja.questSpotOpenShop), findsOneWidget);
    expect(tester.getBottomLeft(find.byType(BottomSheet)).dy, 2400 / 2.5);
  });
}
