import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';

import '../../support/builders.dart';

void main() {
  group('AdventurerRank', () {
    test('必要な修行点', () {
      expect(
        {for (final r in AdventurerRank.values) r: r.requiredPoints},
        {
          AdventurerRank.apprentice: 0,
          AdventurerRank.kyu5: 15,
          AdventurerRank.kyu4: 65,
          AdventurerRank.kyu3: 115,
          AdventurerRank.kyu2: 185,
          AdventurerRank.kyu1: 260,
          AdventurerRank.dan1: 360,
          AdventurerRank.dan2: 485,
          AdventurerRank.dan3: 635,
          AdventurerRank.dan4: 810,
          AdventurerRank.dan5: 1010,
          AdventurerRank.dan6: 1260,
          AdventurerRank.dan7: 1560,
          AdventurerRank.dan8: 1910,
          AdventurerRank.dan9: 2310,
          AdventurerRank.master: 2810,
          AdventurerRank.grandmaster: 3510,
        },
      );
    });

    test('段位は17段階（入門・五級〜一級・初段〜九段・師範代・免許皆伝）で、必要ポイントは小さい順', () {
      final points = [
        for (final rank in AdventurerRank.values) rank.requiredPoints,
      ];
      expect(points, hasLength(17));
      expect(AdventurerRank.values.where((r) => r.isKyu), hasLength(5));
      expect(points, [...points]..sort());
    });

    test('次のランクと必要ポイントがわかる。最高ランクの次は無い', () {
      expect(AdventurerRank.apprentice.next, AdventurerRank.kyu5);
      expect(AdventurerRank.apprentice.next!.requiredPoints, 15);
      expect(AdventurerRank.kyu1.next, AdventurerRank.dan1);
      expect(AdventurerRank.dan9.next, AdventurerRank.master);
      expect(AdventurerRank.grandmaster.next, isNull);
    });
  });

  group('shopRankFor', () {
    test('最高ポイントの境界でランクが決まる', () {
      expect(shopRankFor(0), ShopRank.c);
      expect(shopRankFor(24), ShopRank.c);
      expect(shopRankFor(25), ShopRank.b);
      expect(shopRankFor(39), ShopRank.b);
      expect(shopRankFor(40), ShopRank.a);
      expect(shopRankFor(54), ShopRank.a);
      expect(shopRankFor(55), ShopRank.s);
      expect(shopRankFor(500), ShopRank.s);
    });
  });

  group('shopRanks', () {
    DateTime day(int d) => DateTime(2026, 9, d, 12);

    test('店ごとに、合計ではなく最高ポイントで決まる', () {
      final often = buildShop(id: 'often');
      final hard = buildShop(id: 'hard', isFamous: true);
      final ranks = shopRanks(
        scoreVisits([
          // 15, 10, 10, 10（合計45でも最高は15）
          for (var d = 1; d <= 4; d++) buildEntry(shop: often, eatenAt: day(d)),
          // 10 + 初訪問 5 + 限定 20 + 待ち 10 + 名店 15 = 60
          buildEntry(
            shop: hard,
            eatenAt: day(5),
            isLimited: true,
            waitMinutes: 20,
          ),
        ]),
      );

      expect(ranks, {'often': ShopRank.c, 'hard': ShopRank.s});
    });

    test('撤退しかしていない店にはランクをつけない', () {
      final ranks = shopRanks(
        scoreVisits([
          buildEntry(
            shop: buildShop(id: 'closed'),
            eatenAt: day(1),
            result: VisitResult.retreated,
          ),
        ]),
      );

      expect(ranks, isEmpty);
    });
  });
}
