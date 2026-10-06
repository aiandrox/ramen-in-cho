import 'dart:math' as math;
import 'dart:ui';

import '../prefecture/regions.dart';

/// 地方の印の外枠。中心から見た向き（右が0、反時計回り）ごとの、半径に対する長さで形を決める。
/// どの形も縦横 0.95 を超えないので、少し外に点を散らしても印の箱からはみ出さない。
double regionFrameRadius(Region region, double angle) {
  final c = math.cos(angle);
  final s = math.sin(angle);
  double superEllipse(double n) =>
      math.pow(math.pow(c.abs(), n) + math.pow(s.abs(), n), -1 / n).toDouble();
  // 向き[center]を中心に、幅[width]の三角の山（0〜1）。
  double peak(double center, double width) {
    var d = (angle - center).abs() % (2 * math.pi);
    if (d > math.pi) d = 2 * math.pi - d;
    return math.max(0, 1 - d / width);
  }

  switch (region) {
    // 北海道: 雪の結晶のような、角を上にした六角。
    case Region.hokkaido:
      const side = math.pi / 3;
      final local = ((angle - math.pi / 2) % side + side) % side - side / 2;
      return 0.93 * math.cos(side / 2) / math.cos(local);
    // 東北: 米粒のような、縦長の楕円。
    case Region.tohoku:
      const a = 0.8;
      const b = 0.94;
      return a * b / math.sqrt(math.pow(b * c, 2) + math.pow(a * s, 2));
    // 関東: 角印（角の丸い四角）。
    case Region.kanto:
      return 0.86 * superEllipse(7);
    // 中部: 上に三つの山を持つ、角の丸い四角。
    case Region.chubu:
      final base = 0.76 * superEllipse(6);
      return base +
          0.17 * peak(math.pi / 2, 0.38) +
          0.08 * peak(math.pi / 2 + 0.62, 0.3) +
          0.08 * peak(math.pi / 2 - 0.62, 0.3);
    // 近畿: 瓦（下は角、上は丸い）。
    case Region.kinki:
      return s >= 0 ? 0.86 : 0.86 * superEllipse(7);
    // 中国: 瀬戸内の波（細かくうねる輪）。
    case Region.chugoku:
      return 0.88 + 0.04 * math.sin(14 * angle);
    // 四国: 四つ割り（上下左右に切れ込みのある輪）。
    case Region.shikoku:
      final notch = [for (var i = 0; i < 4; i++) peak(i * math.pi / 2, 0.16)]
          .reduce(math.max);
      return 0.92 - 0.13 * notch;
    // 九州・沖縄: 南国の花（八枚の花びら）。
    case Region.kyushu:
      return 0.78 + 0.15 * math.pow((math.cos(4 * angle)).abs(), 0.7);
  }
}

const _samples = 240;

/// 外枠を[scale]倍にした形。[center]と[radius]は印の中心と半径（箱の半分）。
Path regionFramePath(
  Region region,
  Offset center,
  double radius, {
  double scale = 1,
}) {
  final path = Path();
  for (var i = 0; i < _samples; i++) {
    final point = regionFramePoint(region, center, radius, i / _samples, scale);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// 外枠の上の点。[turn]は真上から時計回りに一周を1とした位置。
Offset regionFramePoint(
  Region region,
  Offset center,
  double radius,
  double turn,
  double scale,
) {
  final angle = math.pi / 2 - 2 * math.pi * turn;
  final r = regionFrameRadius(region, angle) * radius * scale;
  return center + Offset(math.cos(angle), -math.sin(angle)) * r;
}
