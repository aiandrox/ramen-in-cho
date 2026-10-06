import 'dart:math' as math;
import 'dart:ui';

import '../prefecture/regions.dart';

/// 印の外枠の形。地方ごとの形に、東京だけの形と海外の形を足す（印帳の分類は地方のまま）。
enum SealFrame {
  hokkaido,
  tohoku,
  kanto,
  tokyo,
  koshinetsu,
  hokuriku,
  tokai,
  kinki,
  chugoku,
  shikoku,
  kyushu,
  okinawa,
  overseas;

  factory SealFrame.ofRegion(Region region) =>
      SealFrame.values.byName(region.name);
}

/// 都道府県の印の外枠。東京都だけは関東の角印と分ける。都道府県がわからなければ null。
SealFrame? sealFrameFor(String prefecture) {
  if (prefecture == '東京都') return SealFrame.tokyo;
  final region = regionOf(prefecture);
  return region == null ? null : SealFrame.ofRegion(region);
}

/// 印の外枠。中心から見た向き（右が0、反時計回り）ごとの、半径に対する長さで形を決める。
/// どの形も縦横 0.95 を超えないので、少し外に点を散らしても印の箱からはみ出さない。
double sealFrameRadius(SealFrame frame, double angle) {
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

  switch (frame) {
    // 北海道: 雪の結晶のような、角を上にした六角。
    case SealFrame.hokkaido:
      const side = math.pi / 3;
      final local = ((angle - math.pi / 2) % side + side) % side - side / 2;
      return 0.93 * math.cos(side / 2) / math.cos(local);
    // 東北: 米粒のような、縦長の楕円。
    case SealFrame.tohoku:
      const a = 0.8;
      const b = 0.94;
      return a * b / math.sqrt(math.pow(b * c, 2) + math.pow(a * s, 2));
    // 関東: 角印（角の丸い四角）。
    case SealFrame.kanto:
      return 0.86 * superEllipse(7);
    // 東京: 江戸の家紋の「隅入り角」（四隅を丸くえぐった角印）。
    case SealFrame.tokyo:
      return _cornerNotchedSquare(c, s, half: 0.86, notch: 0.3);
    // 甲信越: 上に三つの山を持つ、角の丸い四角。
    case SealFrame.koshinetsu:
      final base = 0.76 * superEllipse(6);
      return base +
          0.17 * peak(math.pi / 2, 0.38) +
          0.08 * peak(math.pi / 2 + 0.62, 0.3) +
          0.08 * peak(math.pi / 2 - 0.62, 0.3);
    // 北陸: 雪輪（六つの丸い切れ込みのある輪）。
    case SealFrame.hokuriku:
      var dip = 0.0;
      for (var i = 0; i < 6; i++) {
        var d = (angle - math.pi / 2 - i * math.pi / 3).abs() % (2 * math.pi);
        if (d > math.pi) d = 2 * math.pi - d;
        dip = math.max(dip, math.sqrt(math.max(0, 1 - math.pow(d / 0.24, 2))));
      }
      return 0.93 - 0.2 * dip;
    // 東海: 富士の稜線（裾の広い台形の山に、平らな頂）。
    case SealFrame.tokai:
      return _convexRadius(_fuji, c, s);
    // 近畿: 瓦（下は角、上は丸い）。
    case SealFrame.kinki:
      return s >= 0 ? 0.86 : 0.86 * superEllipse(7);
    // 中国: 瀬戸内の波（細かくうねる輪）。
    case SealFrame.chugoku:
      return 0.88 + 0.04 * math.sin(14 * angle);
    // 四国: 四つ割り（上下左右に切れ込みのある輪）。
    case SealFrame.shikoku:
      final notch = [for (var i = 0; i < 4; i++) peak(i * math.pi / 2, 0.16)]
          .reduce(math.max);
      return 0.92 - 0.13 * notch;
    // 九州: 椿（上に一枚を向けた、五枚の丸い花びら）。
    case SealFrame.kyushu:
      final petal = (1 + math.cos(5 * (angle - math.pi / 2))) / 2;
      return 0.7 + 0.24 * math.pow(petal, 0.5);
    // 沖縄: 南国の花（デイゴ。八枚の花びら）。
    case SealFrame.okinawa:
      return 0.78 + 0.15 * math.pow((math.cos(4 * angle)).abs(), 0.7);
    // 海外: 羅針盤（東西南北に長い針、そのあいだに短い針を出した丸）。
    case SealFrame.overseas:
      double needles(double offset, double width) =>
          [for (var i = 0; i < 4; i++) peak(offset + i * math.pi / 2, width)]
              .reduce(math.max);
      return 0.76 + 0.19 * needles(0, 0.26) + 0.08 * needles(math.pi / 4, 0.2);
  }
}

/// 半辺[half]の四角の四隅を、隅を中心とした半径[notch]の円でえぐった形の、向き(c, s)の縁までの長さ。
double _cornerNotchedSquare(
  double c,
  double s, {
  required double half,
  required double notch,
}) {
  final square = half / math.max(c.abs(), s.abs());
  // 向きに近い隅だけを見ればよい。
  final cx = c < 0 ? -half : half;
  final cy = s < 0 ? -half : half;
  final along = c * cx + s * cy;
  final disc = along * along - (cx * cx + cy * cy) + notch * notch;
  if (disc < 0) return square;
  final enter = along - math.sqrt(disc);
  return enter > 0 && enter < square ? enter : square;
}

/// 富士の形の辺（外向きの法線と、中心からの距離）。
final _fuji = () {
  (double, double, double) edge(double x1, double y1, double x2, double y2) {
    final nx = y1 - y2;
    final ny = x2 - x1;
    final length = math.sqrt(nx * nx + ny * ny);
    return (nx / length, ny / length, (nx * x1 + ny * y1) / length);
  }

  // 時計回りの頂点（右が x、上が y）。
  const points = [
    (-0.28, 0.92),
    (0.28, 0.92),
    (0.88, 0.12),
    (0.88, -0.84),
    (-0.88, -0.84),
    (-0.88, 0.12),
  ];
  return [
    for (var i = 0; i < points.length; i++)
      edge(
        points[i].$1,
        points[i].$2,
        points[(i + 1) % points.length].$1,
        points[(i + 1) % points.length].$2,
      ),
  ];
}();

/// 中心を含む凸多角形の、向き(c, s)の縁までの長さ。
double _convexRadius(List<(double, double, double)> edges, double c, double s) {
  var best = double.infinity;
  for (final (nx, ny, d) in edges) {
    final dot = nx * c + ny * s;
    if (dot > 1e-9) best = math.min(best, d / dot);
  }
  return best;
}

const _samples = 240;

/// 外枠を[scale]倍にした形。[center]と[radius]は印の中心と半径（箱の半分）。
Path sealFramePath(
  SealFrame frame,
  Offset center,
  double radius, {
  double scale = 1,
}) {
  final path = Path();
  for (var i = 0; i < _samples; i++) {
    final point = sealFramePoint(frame, center, radius, i / _samples, scale);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// 外枠の上の点。[turn]は真上から時計回りに一周を1とした位置。
Offset sealFramePoint(
  SealFrame frame,
  Offset center,
  double radius,
  double turn,
  double scale,
) {
  final angle = math.pi / 2 - 2 * math.pi * turn;
  final r = sealFrameRadius(frame, angle) * radius * scale;
  return center + Offset(math.cos(angle), -math.sin(angle)) * r;
}
