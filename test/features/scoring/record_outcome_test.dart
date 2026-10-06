import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';
import 'package:ramen_in_cho/features/scoring/record_outcome.dart';

import '../../support/builders.dart';

void main() {
  final shop = buildShop(id: 'shop');
  DateTime day(int d) => DateTime(2026, 9, d, 12);

  test('保存した記録のポイントと、累計の変化を返す', () {
    final first = buildEntry(shop: shop, eatenAt: day(1));
    // 10 + 60分待ち 30 + 限定 20 = 60
    final second = buildEntry(
      shop: shop,
      eatenAt: day(2),
      isLimited: true,
      waitMinutes: 60,
    );

    final outcome = computeRecordOutcome([second, first], second.visit.id)!;

    expect(outcome.scored.points.total, 60);
    expect(outcome.totalBefore, 15);
    expect(outcome.totalAfter, 75);
    // 65点の四級を越える。
    expect(outcome.isRankUp, isTrue);
  });

  test('1杯で上がるのは1つだけ。必要点に届かなければ上がらない', () {
    final rare = buildShop(id: 'rare', isFamous: true);
    // 10 + 初訪問 5 + 限定 20 + 待ち 50 + 名店 15 = 100。四級を越えるが、上がるのは五級だけ。
    final big = buildEntry(
      shop: rare,
      eatenAt: day(1),
      isLimited: true,
      waitMinutes: 100,
    );
    final bigOnly = computeRecordOutcome([big], big.visit.id)!;
    expect(bigOnly.rankBefore, AdventurerRank.apprentice);
    expect(bigOnly.rankAfter, AdventurerRank.kyu5);
    expect(bigOnly.isRankUp, isTrue);

    // 次の1杯で、四級に1つだけ上がる。
    final next = buildEntry(shop: shop, eatenAt: day(2));
    final up = computeRecordOutcome([big, next], next.visit.id)!;
    expect(up.totalAfter, 115);
    expect(up.rankBefore, AdventurerRank.kyu5);
    expect(up.rankAfter, AdventurerRank.kyu4);
    expect(up.isRankUp, isTrue);

    // 20 点（五級）→ 30 点では、四級（65）に届かない。
    final first = buildEntry(shop: shop, eatenAt: day(1), waitMinutes: 10);
    final again = buildEntry(shop: shop, eatenAt: day(2));
    final notYet = computeRecordOutcome([first, again], again.visit.id)!;
    expect(notYet.totalAfter, 30);
    expect(notYet.isRankUp, isFalse);
  });

  test('過去の日時の記録を足したときは、ほかの記録のボーナスの変化も含めた差になる', () {
    // 連続記録がつかないよう、週を2つ以上あける。
    final later = buildEntry(shop: shop, eatenAt: day(20));
    final earlier = buildEntry(shop: shop, eatenAt: day(1));

    final outcome = computeRecordOutcome([later, earlier], earlier.visit.id)!;

    // 初訪問ボーナスが later から earlier に移るので、増えるのは10点だけ。
    expect(outcome.scored.points.total, 15);
    expect(outcome.totalBefore, 15);
    expect(outcome.totalAfter, 25);
  });

  test('撤退の記録は0点で、累計は変わらない', () {
    final retreat = buildEntry(
      shop: shop,
      eatenAt: day(1),
      result: VisitResult.retreated,
    );

    final outcome = computeRecordOutcome([retreat], retreat.visit.id)!;

    expect(outcome.scored.points.total, 0);
    expect(outcome.totalBefore, 0);
    expect(outcome.totalAfter, 0);
  });

  test('この記録で新しく達成したクエストを返す', () {
    final first = buildEntry(shop: shop, eatenAt: day(1));
    final second = buildEntry(shop: shop, eatenAt: day(2), waitMinutes: 40);

    final firstOutcome = computeRecordOutcome([first], first.visit.id)!;
    final secondOutcome = computeRecordOutcome([
      first,
      second,
    ], second.visit.id)!;

    expect(firstOutcome.questLevelUps.map((l) => l.quest.id), ['first_bowl']);
    expect(secondOutcome.questLevelUps.map((l) => l.quest.id), ['queue']);
  });

  test('撤退の記録ではクエストを達成しない', () {
    final retreat = buildEntry(
      shop: shop,
      eatenAt: day(1),
      result: VisitResult.retreated,
      waitMinutes: 90,
    );

    final outcome = computeRecordOutcome([retreat], retreat.visit.id)!;

    expect(outcome.questLevelUps, isEmpty);
  });

  test('記録が見つからなければnull', () {
    expect(computeRecordOutcome(const [], 'missing'), isNull);
  });
}
