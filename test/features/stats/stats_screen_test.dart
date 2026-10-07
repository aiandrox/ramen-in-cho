import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/stats/stats.dart';
import 'package:ramen_in_cho/features/stats/stats_screen.dart';
import 'package:ramen_in_cho/features/visit_detail/visit_detail_screen.dart';

import '../../support/builders.dart';
import '../../support/l10n.dart';

void main() {
  Future<void> pumpStats(
    WidgetTester tester,
    List<VisitWithShop> visits,
  ) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(visits)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 1)),
        ],
        child: localizedApp(
          home: Scaffold(body: ListView(children: const [StatsSections()])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('記録が無いときは案内を出す', (tester) async {
    await pumpStats(tester, const []);

    expect(find.text(ja.statsEmpty), findsOneWidget);
    expect(find.text(ja.statsBowls), findsNothing);
  });

  testWidgets('記録を読み込めなかったときは、記録が無いとは表示しない', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(
            AsyncError(StateError('db'), StackTrace.empty),
          ),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
        ],
        child: localizedApp(
          home: Scaffold(body: ListView(children: const [StatsSections()])),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(ja.homeLoadFailed), findsOneWidget);
    expect(find.text(ja.statsEmpty), findsNothing);
  });

  testWidgets('今年の杯数・系統の割合・よく行く店・店ランクを表示する', (tester) async {
    final often = buildShop(id: 'often', name: 'よく行く麺屋');
    final rare = buildShop(id: 'rare', name: '名店の印の店', isFamous: true);
    await pumpStats(tester, [
      buildEntry(
        shop: often,
        eatenAt: DateTime(2025, 12, 1, 12),
        style: RamenStyle.shoyu,
      ),
      buildEntry(
        shop: often,
        eatenAt: DateTime(2026, 9, 1, 12),
        style: RamenStyle.shoyu,
      ),
      buildEntry(
        shop: often,
        eatenAt: DateTime(2026, 9, 2, 12),
        style: RamenStyle.miso,
      ),
      // 10 + 初訪問 5 + 限定 20 + 朝ラー 10 + 名店 15 = 60 → Sランク
      buildEntry(shop: rare, eatenAt: DateTime(2026, 9, 3, 9), isLimited: true),
    ]);

    expect(find.text(ja.statsBowlsLine(3, 4)), findsOneWidget);

    expect(find.text(ja.styleShoyu), findsOneWidget);
    expect(find.text(ja.percent(50)), findsOneWidget);
    expect(find.text(ja.percent(25)), findsNWidgets(2));
    expect(find.text(ja.styleMiso), findsOneWidget);
    expect(find.text(ja.styleUnset), findsOneWidget);

    // 2杯以上の店は、よく行く店と店ランクの両方に出る。1杯だけの店は店ランクだけ。
    expect(find.text('よく行く麺屋'), findsNWidgets(2));
    expect(find.text('名店の印の店'), findsOneWidget);
    expect(find.text(ja.shopRankS), findsOneWidget);
    expect(find.text(ja.shopRankC), findsOneWidget);
    expect(find.text(ja.statsBestPoints(60)), findsOneWidget);
    expect(find.text(ja.statsBestPoints(15)), findsOneWidget);

    expect(find.text(ja.statsBests), findsOneWidget);
    expect(find.text(ja.bestHighestPoints), findsOneWidget);
    expect(find.text(ja.bestDetail('名店の印の店', '2026/9/3')), findsOneWidget);
    // 並んだ記録も撤退も無いので、その2つは出さない。
    expect(find.text(ja.bestLongestWait), findsNothing);
    expect(find.text(ja.bestMostRetreats), findsNothing);
  });

  group('行を押すと、その店のページを開く', () {
    final often = buildShop(id: 'often', name: 'よく行く麺屋');
    final first = buildEntry(shop: often, eatenAt: DateTime(2026, 9, 1, 12));
    final limited = buildEntry(
      shop: often,
      eatenAt: DateTime(2026, 9, 2, 12),
      isLimited: true,
    );
    final last = buildEntry(shop: often, eatenAt: DateTime(2026, 9, 3, 12));

    Future<String> openFrom(WidgetTester tester, Finder row) async {
      await pumpStats(tester, [first, limited, last]);
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return tester
          .widget<VisitDetailScreen>(find.byType(VisitDetailScreen))
          .visitId;
    }

    testWidgets('よく行く店はいちばん新しい1杯', (tester) async {
      final row = find.ancestor(
        of: find.text(ja.bowls(3)),
        matching: find.byType(ListTile),
      );
      expect(await openFrom(tester, row), last.visit.id);
    });

    testWidgets('店ランクは最高ポイントの1杯', (tester) async {
      final best = rankedShops(scoreVisits([first, limited, last])).single;
      final row = find.ancestor(
        of: find.text(ja.statsBestPoints(best.bestPoints)),
        matching: find.byType(ListTile),
      );
      expect(await openFrom(tester, row), limited.visit.id);
    });

    testWidgets('自己ベストはその1杯', (tester) async {
      final row = find.ancestor(
        of: find.text(ja.bestHighestPoints),
        matching: find.byType(ListTile),
      );
      expect(await openFrom(tester, row), limited.visit.id);
    });
  });
}
