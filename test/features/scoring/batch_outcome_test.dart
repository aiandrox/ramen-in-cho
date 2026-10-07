import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/batch_outcome.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';

import '../../support/builders.dart';

void main() {
  final shop = buildShop(id: 'shop');
  DateTime day(int d) => DateTime(2026, 9, d, 12);

  test('まとめた杯だけを食べた順に並べ、点の合計と累計の変化を返す', () {
    final before = buildEntry(shop: shop, eatenAt: day(1));
    final a = buildEntry(shop: shop, eatenAt: day(10), isLimited: true);
    final b = buildEntry(
      shop: buildShop(id: 'other'),
      eatenAt: day(20),
    );

    final outcome = computeBatchOutcome(
      [b, before, a],
      [b.visit.id, a.visit.id],
    )!;

    expect(outcome.scored.map((e) => e.visit.id), [a.visit.id, b.visit.id]);
    expect(
      outcome.points,
      outcome.scored[0].points.total + outcome.scored[1].points.total,
    );
    expect(outcome.totalBefore, 15);
    expect(outcome.totalAfter, outcome.totalBefore + outcome.points);
  });

  test('まとめた記録が無ければnull', () {
    final entry = buildEntry(shop: shop, eatenAt: day(1));
    expect(computeBatchOutcome([entry], ['missing']), isNull);
  });

  test('段位は1杯で1つずつ上がるので、上がった数は杯数を越えない', () {
    final rare = buildShop(id: 'rare', isFamous: true);
    // どれも100点ほどで、累計は先の段位に届くが、上がるのは1杯に1つずつ。
    final bowls = [
      for (final d in [1, 10, 20])
        buildEntry(
          shop: rare,
          eatenAt: day(d),
          isLimited: true,
          waitMinutes: 100,
        ),
    ];

    final outcome = computeBatchOutcome(bowls, [
      for (final e in bowls) e.visit.id,
    ])!;

    expect(outcome.rankBefore, AdventurerRank.apprentice);
    expect(outcome.rankAfter, AdventurerRank.kyu3);
    expect(outcome.rankSteps, 3);
    expect(outcome.isRankUp, isTrue);
  });

  test('段位が変わらなければ0', () {
    final first = buildEntry(shop: shop, eatenAt: day(1));
    final again = buildEntry(shop: shop, eatenAt: day(20));

    final outcome = computeBatchOutcome([first, again], [again.visit.id])!;

    expect(outcome.rankSteps, 0);
    expect(outcome.isRankUp, isFalse);
  });

  test('撤退だけなら0点で、段位も上がらない', () {
    final retreat = buildEntry(
      shop: shop,
      eatenAt: day(1),
      result: VisitResult.retreated,
    );
    final retreat2 = buildEntry(
      shop: shop,
      eatenAt: day(2),
      result: VisitResult.retreated,
    );

    final outcome = computeBatchOutcome(
      [retreat, retreat2],
      [retreat.visit.id, retreat2.visit.id],
    )!;

    expect(outcome.points, 0);
    expect(outcome.rankSteps, 0);
  });

  test('叶った願と、新しく会得した型と秘伝をまとめて返す', () {
    final a = buildEntry(shop: shop, eatenAt: day(1));
    final b = buildEntry(
      shop: buildShop(id: 'wished'),
      eatenAt: day(20),
    );
    final wish = Wish(
      id: 'wish',
      name: '架空軒',
      createdAt: day(1),
      fulfilledVisitId: b.visit.id,
    );

    final outcome = computeBatchOutcome(
      [a, b],
      [a.visit.id, b.visit.id],
      wishes: [wish],
    )!;

    expect(outcome.wishFulfillments.map((e) => e.visit.id), [b.visit.id]);
    expect(outcome.wishFulfillments.single.fulfilledWish?.id, 'wish');
    // 1杯目の秘伝（はじめての着丼）などが入る。
    expect(outcome.questLevelUps, isNotEmpty);
  });

  test('前からある記録で会得していた型と秘伝は入れない', () {
    final first = buildEntry(shop: shop, eatenAt: day(1));
    final second = buildEntry(shop: shop, eatenAt: day(20));

    final withFirst = computeBatchOutcome([first, second], [second.visit.id])!;
    final fromZero = computeBatchOutcome(
      [first, second],
      [first.visit.id, second.visit.id],
    )!;

    expect(
      withFirst.questLevelUps.length,
      lessThan(fromZero.questLevelUps.length),
    );
  });
}
