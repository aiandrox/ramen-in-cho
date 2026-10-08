import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/quests/quest_history_screen.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/scoring/rank_history_screen.dart';
import 'package:ramen_in_cho/features/scoring/rank_progress.dart';
import 'package:ramen_in_cho/features/shugyo/shugyo_screen.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

import '../../support/builders.dart';
import '../../support/l10n.dart';

void main() {
  Future<void> pumpShugyo(
    WidgetTester tester,
    List<VisitWithShop> visits,
  ) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(visits)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
        ],
        child: localizedApp(home: const ShugyoScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  final shop = buildShop(id: 'shop', name: '麺屋テスト');
  final visits = [
    for (var d = 1; d <= 6; d++)
      buildEntry(shop: shop, eatenAt: DateTime(2026, 9, d, 12)),
  ];

  testWidgets('初めは型と秘伝を出し、切り替えで記録・統計だけを出す', (tester) async {
    await pumpShugyo(tester, visits);

    expect(find.text('着丼の道'), findsOneWidget);
    expect(find.text(ja.shugyorokuOpen), findsNothing);
    expect(find.text(ja.statsBowls), findsNothing);

    await tester.tap(find.text(ja.shugyoSectionRecords));
    await tester.pumpAndSettle();
    expect(find.text('着丼の道'), findsNothing);
    expect(find.text(ja.shugyorokuOpen), findsOneWidget);
    expect(find.text(ja.statsBowls), findsNothing);
    // 毎日ラーメン健康生活は、7日続けるまで姿を見せない。
    expect(find.text(ja.healthyLifeTitle), findsNothing);

    await tester.tap(find.text(ja.shugyoSectionStats));
    await tester.pumpAndSettle();
    expect(find.text(ja.shugyorokuOpen), findsNothing);
    expect(find.text(ja.statsBowls), findsOneWidget);
  });

  testWidgets('7日続けて食べたら、記録に毎日ラーメン健康生活を出す', (tester) async {
    await pumpShugyo(tester, [
      for (var d = 1; d <= 7; d++)
        buildEntry(shop: shop, eatenAt: DateTime(2026, 9, d, 12)),
    ]);
    expect(find.text(ja.healthyLifeTitle), findsNothing);
    await tester.tap(find.text(ja.shugyoSectionRecords));
    await tester.pumpAndSettle();
    expect(find.text(ja.healthyLifeTitle), findsOneWidget);
  });

  testWidgets('段位を押すと昇段の記録、型のカードを押すとこれまでの段が開く', (tester) async {
    await pumpShugyo(tester, visits);

    await tester.tap(find.text('着丼の道'));
    await tester.pumpAndSettle();
    expect(find.byType(QuestHistoryScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RankProgress));
    await tester.pumpAndSettle();
    expect(find.byType(RankHistoryScreen), findsOneWidget);
  });
}
