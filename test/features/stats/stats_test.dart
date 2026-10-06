import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';
import 'package:ramen_in_cho/features/stats/stats.dart';

import '../../support/builders.dart';

void main() {
  final shopA = buildShop(id: 'a', name: 'A店');
  final shopB = buildShop(id: 'b', name: 'B店');
  final shopC = buildShop(id: 'c', name: 'C店', isFamous: true);

  group('杯数', () {
    final scored = scoreVisits([
      buildEntry(shop: shopA, eatenAt: DateTime(2025, 12, 31, 23, 59)),
      buildEntry(shop: shopA, eatenAt: DateTime(2026, 1, 1)),
      buildEntry(shop: shopB, eatenAt: DateTime(2026, 9, 30)),
      buildEntry(
        shop: shopB,
        eatenAt: DateTime(2026, 10, 1),
        result: VisitResult.retreated,
      ),
    ]);

    test('今年の杯数は、その年に食べた記録だけを数える', () {
      expect(bowlsInYear(scored, 2026), 2);
      expect(bowlsInYear(scored, 2025), 1);
      expect(bowlsInYear(scored, 2024), 0);
    });

    test('累計の杯数に撤退は含めない', () {
      expect(totalBowls(scored), 3);
      expect(totalBowls(const []), 0);
    });
  });

  group('styleShares', () {
    test('系統ごとの杯数と割合を、多い順に返す', () {
      final shares = styleShares(
        scoreVisits([
          buildEntry(shop: shopA, style: RamenStyle.miso),
          buildEntry(shop: shopA, style: RamenStyle.shoyu),
          buildEntry(shop: shopA, style: RamenStyle.shoyu),
          buildEntry(shop: shopA),
        ]),
      );

      expect(shares.map((s) => s.style), [
        RamenStyle.shoyu,
        RamenStyle.miso,
        null,
      ]);
      expect(shares.map((s) => s.count), [2, 1, 1]);
      expect(shares.map((s) => s.ratio), [0.5, 0.25, 0.25]);
    });

    test('撤退は数えない。記録が無ければ空', () {
      expect(
        styleShares(
          scoreVisits([
            buildEntry(
              shop: shopA,
              style: RamenStyle.jiro,
              result: VisitResult.retreated,
            ),
          ]),
        ),
        isEmpty,
      );
      expect(styleShares(const []), isEmpty);
    });
  });

  group('frequentShops', () {
    DateTime day(int d) => DateTime(2026, 9, d, 12);

    test('2杯以上の店を食べた回数の多い順に。同数なら最近行った店が先。1杯の店と撤退は数えない', () {
      final shops = frequentShops(
        scoreVisits([
          buildEntry(shop: shopA, eatenAt: day(1)),
          buildEntry(shop: shopB, eatenAt: day(2)),
          buildEntry(shop: shopB, eatenAt: day(3)),
          buildEntry(shop: shopC, eatenAt: day(4)),
          buildEntry(shop: shopC, eatenAt: day(5)),
          buildEntry(shop: shopB, eatenAt: day(6)),
          buildEntry(
            shop: shopA,
            eatenAt: day(7),
            result: VisitResult.retreated,
          ),
        ]),
      );

      expect(shops.map((s) => s.shop.name), ['B店', 'C店']);
      expect(shops.map((s) => s.count), [3, 2]);
    });

    test('上位の件数を絞れる', () {
      final shops = frequentShops(
        scoreVisits([
          for (final shop in [shopA, shopB, shopC]) ...[
            buildEntry(shop: shop, eatenAt: day(1)),
            buildEntry(shop: shop, eatenAt: day(2)),
          ],
        ]),
        limit: 2,
      );

      expect(shops, hasLength(2));
    });
  });

  group('rankedShops', () {
    DateTime day(int d) => DateTime(2026, 9, d, 12);

    test('店ごとの最高ポイントでランクをつけ、高い順に返す', () {
      final shops = rankedShops(
        scoreVisits([
          // A店: 15, 10 → 最高15（C）
          buildEntry(shop: shopA, eatenAt: day(1)),
          buildEntry(shop: shopA, eatenAt: day(2)),
          // B店: 10 + 5 + 20 + 待ち 5 = 40（A）
          buildEntry(
            shop: shopB,
            eatenAt: day(3),
            isLimited: true,
            waitMinutes: 10,
          ),
          // C店: 10 + 初訪問 5 + 限定 20 + 待ち 10 + 名店 15 = 60（S）
          buildEntry(
            shop: shopC,
            eatenAt: day(4),
            isLimited: true,
            waitMinutes: 20,
          ),
        ]),
      );

      expect(shops.map((s) => s.shop.name), ['C店', 'B店', 'A店']);
      expect(shops.map((s) => s.rank), [ShopRank.s, ShopRank.a, ShopRank.c]);
      expect(shops.map((s) => s.bestPoints), [60, 40, 15]);
      expect(shops.map((s) => s.count), [1, 1, 2]);
    });

    test('撤退しかしていない店は含めない', () {
      final shops = rankedShops(
        scoreVisits([
          buildEntry(
            shop: shopA,
            eatenAt: day(1),
            result: VisitResult.retreated,
          ),
        ]),
      );

      expect(shops, isEmpty);
    });
  });

  group('personalBests', () {
    DateTime day(int d) => DateTime(2026, 9, d, 12);

    test('最長の待ち時間・1杯の最高ポイント・撤退の多い店を返す', () {
      final bests = personalBests(
        scoreVisits([
          buildEntry(shop: shopA, eatenAt: day(1), waitMinutes: 45),
          buildEntry(shop: shopB, eatenAt: day(2), waitMinutes: 70),
          // 10 + 初訪問 5 + 限定 20 + 待ち 10 + 名店 15 = 60
          buildEntry(
            shop: shopC,
            eatenAt: day(3),
            isLimited: true,
            waitMinutes: 20,
          ),
          buildEntry(
            shop: shopA,
            eatenAt: day(4),
            result: VisitResult.retreated,
          ),
          buildEntry(
            shop: shopB,
            eatenAt: day(5),
            result: VisitResult.retreated,
          ),
          buildEntry(
            shop: shopB,
            eatenAt: day(6),
            result: VisitResult.retreated,
          ),
        ]),
      );

      expect(bests.longestWait!.value, 70);
      expect(bests.longestWait!.entry.shop.name, 'B店');
      expect(bests.highestPoints!.value, 60);
      expect(bests.highestPoints!.entry.shop.name, 'C店');
      expect(bests.mostRetreats!.value, 2);
      expect(bests.mostRetreats!.entry.shop.name, 'B店');
      expect(bests.mostRetreats!.entry.visit.eatenAt, day(6));
    });

    test('撤退の回数が同じ店どうしでは、先にその回数に達した店を残す', () {
      final bests = personalBests(
        scoreVisits([
          buildEntry(
            shop: shopB,
            eatenAt: day(1),
            result: VisitResult.retreated,
          ),
          buildEntry(
            shop: shopA,
            eatenAt: day(5),
            result: VisitResult.retreated,
          ),
          buildEntry(
            shop: shopA,
            eatenAt: day(10),
            result: VisitResult.retreated,
          ),
          buildEntry(
            shop: shopB,
            eatenAt: day(20),
            result: VisitResult.retreated,
          ),
        ]),
      );

      expect(bests.mostRetreats!.entry.shop.name, 'A店');
      expect(bests.mostRetreats!.entry.visit.eatenAt, day(10));
    });

    test('同じ値なら先に達成した記録を残す', () {
      final bests = personalBests(
        scoreVisits([
          buildEntry(shop: shopA, eatenAt: day(1), waitMinutes: 30),
          buildEntry(shop: shopB, eatenAt: day(2), waitMinutes: 30),
        ]),
      );

      expect(bests.longestWait!.entry.visit.eatenAt, day(1));
    });

    test('並んだ記録や撤退が無ければ、その自己ベストは無い', () {
      final bests = personalBests(scoreVisits([buildEntry(shop: shopA)]));

      expect(bests.longestWait, isNull);
      expect(bests.mostRetreats, isNull);
      expect(bests.highestPoints!.value, 15);
    });

    test('撤退で並んだ時間は最長の待ち時間に数えない', () {
      final bests = personalBests(
        scoreVisits([
          buildEntry(
            shop: shopA,
            waitMinutes: 120,
            result: VisitResult.retreated,
          ),
        ]),
      );

      expect(bests.longestWait, isNull);
      expect(bests.highestPoints, isNull);
    });
  });
}
