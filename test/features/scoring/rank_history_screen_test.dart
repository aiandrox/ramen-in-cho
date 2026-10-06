import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';
import 'package:ramen_in_cho/features/records/date_format.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/scoring/rank_history_screen.dart';
import 'package:ramen_in_cho/features/scoring/rank_progress.dart';
import 'package:ramen_in_cho/features/visit_detail/visit_detail_screen.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';
import 'package:ramen_in_cho/features/words/words.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  DateTime day(int d) => DateTime(2026, 9, d, 12);

  Future<void> pumpHistory(
    WidgetTester tester,
    List<VisitWithShop> visits, {
    Widget home = const RankHistoryScreen(),
  }) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(visits)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          recordRepositoryProvider.overrideWithValue(FakeRecordRepository()),
          documentsDirectoryProvider.overrideWithValue(createTempDirectory()),
        ],
        child: localizedApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder seal(String label) => find.byWidgetPredicate(
    (widget) => widget is RankSeal && widget.label == label,
  );

  testWidgets('上がった段位は日付と店、次の段位は残りの点、その先は伏せる', (tester) async {
    final rare = buildShop(id: 'rare', name: '名店', isFamous: true);
    // 10 + 待ち 50 + 限定 20 + 初訪問 10 + 名店 15 = 105。四級を越えるが、1杯で上がるのは五級だけ。
    final big = buildEntry(
      shop: rare,
      eatenAt: day(5),
      isLimited: true,
      waitMinutes: 100,
    );
    await pumpHistory(tester, [big]);

    expect(seal(ja.rankApprentice), findsOneWidget);
    expect(seal(ja.rankKyu('五')), findsOneWidget);
    final achieved = ja.rankHistoryAchievedAt(formatDate(day(5)), '名店');
    expect(find.text(achieved), findsNWidgets(2));

    // 四級の必要点にはもう届いているので、次の1杯で上がる。名前は見える。
    expect(seal(ja.rankKyu('四')), findsOneWidget);
    expect(find.text(ja.rankHistoryReady), findsOneWidget);
    expect(find.text(masterWords(AdventurerRank.kyu5)), findsOneWidget);
    expect(find.text(masterWords(AdventurerRank.kyu4)), findsNothing);

    // 三級より先は名前も点も出さない。
    expect(seal(ja.rankKyu('三')), findsNothing);
    expect(seal(ja.rankGrandmaster), findsNothing);
    expect(seal(ja.rankHistoryHidden), findsNWidgets(14));

    await tester.tap(find.text(achieved).at(1));
    await tester.pumpAndSettle();
    expect(find.byType(VisitDetailScreen), findsOneWidget);
  });

  testWidgets('記録が無ければ入門だけが上がった段位で、次は五級', (tester) async {
    await pumpHistory(tester, const []);

    expect(seal(ja.rankApprentice), findsOneWidget);
    expect(find.text(ja.rankHistoryNoRecord), findsOneWidget);
    expect(seal(ja.rankKyu('五')), findsOneWidget);
    expect(find.text(ja.rankHistoryRemaining(15)), findsOneWidget);
    expect(seal(ja.rankHistoryHidden), findsNWidgets(15));
  });

  testWidgets('段位の表示をタップすると昇段の記録を開く', (tester) async {
    await pumpHistory(
      tester,
      const [],
      home: const Scaffold(
        body: RankProgress(totalPoints: 0, rank: AdventurerRank.apprentice),
      ),
    );

    await tester.tap(find.byType(RankProgress));
    await tester.pumpAndSettle();
    expect(find.byType(RankHistoryScreen), findsOneWidget);
    expect(find.text(ja.rankHistoryTitle), findsOneWidget);
  });
}
