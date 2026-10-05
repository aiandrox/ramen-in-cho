import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/inkan/inkan.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';

import '../../support/builders.dart';

void main() {
  group('kanjiNumber', () {
    test('1〜99を漢数字にする', () {
      expect(kanjiNumber(1), '一');
      expect(kanjiNumber(9), '九');
      expect(kanjiNumber(10), '十');
      expect(kanjiNumber(11), '十一');
      expect(kanjiNumber(20), '二十');
      expect(kanjiNumber(31), '三十一');
      expect(kanjiNumber(99), '九十九');
    });

    test('範囲外はそのまま数字で返す', () {
      expect(kanjiNumber(100), '100');
      expect(kanjiNumber(-1), '-1');
    });
  });

  test('proseNumber は1〜99と切りのよい百・千を漢数字に、それ以外は数字にする', () {
    expect(proseNumber(1), '一');
    expect(proseNumber(99), '九十九');
    expect(proseNumber(100), '百');
    expect(proseNumber(300), '三百');
    expect(proseNumber(1000), '千');
    expect(proseNumber(101), '101');
    expect(proseNumber(137), '137');
    expect(proseNumber(0), '0');
  });

  group('inkanShapeFor', () {
    ScoredVisit scoredWith({
      VisitResult result = VisitResult.eaten,
      int? waitMinutes,
      bool isLimited = false,
      bool isFirstVisit = false,
    }) {
      final entry = buildEntry(
        result: result,
        waitMinutes: waitMinutes,
        isLimited: isLimited,
      );
      return ScoredVisit(
        visit: entry.visit,
        shop: entry.shop,
        points: calculatePoints(
          visit: entry.visit,
          hoursConditions: const {},
          isFirstVisit: isFirstVisit,
          isRetrySuccess: false,
        ),
        isFirstVisit: isFirstVisit,
        isRetrySuccess: false,
      );
    }

    test('1杯の修行点の境界で印の格が上がる', () {
      // 10点
      expect(inkanShapeFor(scoredWith()), InkanShape.circle);
      // 10 + 15(30分) = 25点
      expect(
        inkanShapeFor(scoredWith(waitMinutes: 30)),
        InkanShape.doubleCircle,
      );
      // 10 + 10(29分) = 20点
      expect(inkanShapeFor(scoredWith(waitMinutes: 29)), InkanShape.circle);
      // 10 + 20 + 10 = 40点
      expect(
        inkanShapeFor(scoredWith(isLimited: true, isFirstVisit: true)),
        InkanShape.square,
      );
      // 10 + 30(60分) + 20 = 60点
      expect(
        inkanShapeFor(scoredWith(waitMinutes: 60, isLimited: true)),
        InkanShape.filled,
      );
    });

    test('撤退は灰色の印', () {
      expect(
        inkanShapeFor(scoredWith(result: VisitResult.retreated)),
        InkanShape.retreat,
      );
    });
  });

  group('japaneseEra', () {
    test('2019年5月1日から令和、それより前は平成', () {
      expect(japaneseEra(DateTime(2026, 10, 1)), (Era.reiwa, 8));
      expect(japaneseEra(DateTime(2019, 5, 1)), (Era.reiwa, 1));
      expect(japaneseEra(DateTime(2019, 4, 30, 23, 59)), (Era.heisei, 31));
      expect(japaneseEra(DateTime(2016, 3, 1)), (Era.heisei, 28));
      expect(japaneseEra(DateTime(2000, 1, 1)), (Era.heisei, 12));
    });
  });

  test('印の傾きは記録ごとに決まり、±8度に収まる', () {
    expect(inkanAngle('a'), inkanAngle('a'));
    for (final id in ['a', 'visit-1', '0f8e1c2a-uuid', '']) {
      expect(inkanAngle(id).abs(), lessThanOrEqualTo(8 * 3.1416 / 180));
    }
  });
}
