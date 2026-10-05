import 'dart:math' as math;

import '../records/models.dart';
import '../scoring/points.dart';
import '../scoring/ranks.dart';

/// 印の形。1杯の修行点が高いほど格の高い形になる。撤退は灰色の印。
enum InkanShape { circle, doubleCircle, square, filled, retreat }

InkanShape inkanShapeFor(ScoredVisit scored) {
  if (scored.visit.result == VisitResult.retreated) return InkanShape.retreat;
  return switch (shopRankFor(scored.points.total)) {
    ShopRank.c => InkanShape.circle,
    ShopRank.b => InkanShape.doubleCircle,
    ShopRank.a => InkanShape.square,
    ShopRank.s => InkanShape.filled,
  };
}

const _kanjiDigits = ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

/// 1〜99を漢数字にする（十・二十一 など）。範囲外はアラビア数字のまま。
String kanjiNumber(int value) {
  if (value < 0 || value >= 100) return '$value';
  if (value < 10) return _kanjiDigits[value];
  final tens = value ~/ 10;
  final ones = value % 10;
  return '${tens == 1 ? '' : _kanjiDigits[tens]}十'
      '${ones == 0 ? '' : _kanjiDigits[ones]}';
}

/// 文の中の数。1〜99と、切りのよい百・千は漢数字、それ以外（137 など）は読みやすいようアラビア数字。
String proseNumber(int value) {
  if (value >= 1 && value < 100) return kanjiNumber(value);
  if (value > 0 && value < 1000 && value % 100 == 0) {
    return '${value == 100 ? '' : _kanjiDigits[value ~/ 100]}百';
  }
  if (value == 1000) return '千';
  return '$value';
}

enum Era { heisei, reiwa }

/// 和暦の元号と年（元年が1）。令和より前は平成とする（記録は2000年以降のため）。
(Era, int) japaneseEra(DateTime date) => date.isBefore(DateTime(2019, 5, 1))
    ? (Era.heisei, date.year - 1988)
    : (Era.reiwa, date.year - 2018);

/// 印の傾き（ラジアン）。押すたびに少しずつ違うよう、記録のIDから決める。
double inkanAngle(String visitId) {
  final hash = visitId.codeUnits.fold<int>(
    0,
    (sum, unit) => (sum * 31 + unit) & 0x7fffffff,
  );
  return ((hash % 17) - 8) * math.pi / 180;
}
