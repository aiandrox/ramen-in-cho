import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/rank_history.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';

import '../../support/builders.dart';

void main() {
  DateTime day(int d) => DateTime(2026, 9, d, 12);

  test('記録が無ければ入門だけで、日付は無い', () {
    final history = rankHistory(const []);

    expect(history, hasLength(1));
    expect(history.single.rank, AdventurerRank.apprentice);
    expect(history.single.visit, isNull);
    expect(history.single.reachedAt, isNull);
  });

  test('入門は最初の記録の日。1杯目（20点以上）で五級、累計が65点を越えた1杯で四級に上がる', () {
    final a = buildShop(id: 'a');
    // 10分待ちの初訪問 20 点 → 五級（20）。限定 30 点ずつで 50 → 80 点 → 四級（65）。
    final first = buildEntry(shop: a, eatenAt: day(1), waitMinutes: 10);
    final second = buildEntry(shop: a, eatenAt: day(2), isLimited: true);
    final third = buildEntry(shop: a, eatenAt: day(3), isLimited: true);
    final scored = scoreVisits([third, first, second]);

    final before = rankHistory(scored.take(2).toList());
    expect(totalPoints(scored.take(2).toList()), 50);
    expect(before.map((e) => e.rank), [
      AdventurerRank.apprentice,
      AdventurerRank.kyu5,
    ]);

    final history = rankHistory(scored);
    expect(history.map((e) => e.rank), [
      AdventurerRank.apprentice,
      AdventurerRank.kyu5,
      AdventurerRank.kyu4,
    ]);
    expect(history[0].visit!.visit.id, first.visit.id);
    expect(history[0].reachedAt, day(1));
    expect(history[1].visit!.visit.id, first.visit.id);
    expect(history[2].visit!.visit.id, third.visit.id);
    expect(history[2].visit!.shop.name, 'a');
    expect(history[2].reachedAt, day(3));
  });

  test('1杯で上がるのは1つだけ。累計が先に届いていても、食べた1杯ごとに1つずつ上がる', () {
    final rare = buildShop(id: 'rare', isFamous: true);
    // 10 + 待ち 50 + 限定 20 + 初訪問 10 + 名店 15 = 105 → 四級（65）を越えるが、上がるのは五級だけ。
    final big = buildEntry(
      shop: rare,
      eatenAt: day(1),
      isLimited: true,
      waitMinutes: 100,
    );
    // 撤退では上がらない。
    final retreat = buildEntry(
      shop: buildShop(id: 'closed'),
      eatenAt: day(2),
      result: VisitResult.retreated,
    );
    final second = buildEntry(shop: rare, eatenAt: day(3));
    final third = buildEntry(shop: rare, eatenAt: day(4));
    final history = rankHistory(scoreVisits([big, retreat, second, third]));

    expect(history.map((e) => e.rank), [
      AdventurerRank.apprentice,
      AdventurerRank.kyu5,
      AdventurerRank.kyu4,
      AdventurerRank.kyu3,
    ]);
    expect(history[1].visit!.visit.id, big.visit.id);
    expect(history[2].visit!.visit.id, second.visit.id);
    expect(history[3].visit!.visit.id, third.visit.id);
    expect(currentRank(scoreVisits([big, retreat])), AdventurerRank.kyu5);
  });

  test('撤退の記録（0点）では昇段しない', () {
    final retreat = buildEntry(
      shop: buildShop(id: 'a'),
      eatenAt: day(1),
      result: VisitResult.retreated,
    );
    final history = rankHistory(scoreVisits([retreat]));

    expect(history.map((e) => e.rank), [AdventurerRank.apprentice]);
    expect(history.single.visit!.visit.id, retreat.visit.id);
  });
}
