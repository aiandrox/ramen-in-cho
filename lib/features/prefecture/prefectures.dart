import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../records/models.dart';

/// 同梱した都道府県の境界（国土数値情報の行政区域を簡略化したもの。`tool/prefectures/build.sh` で作る）。
const prefecturesAsset = 'assets/prefectures.json';

/// 境界の外（簡略化で削った小島や埋立地）でも、海岸からこの距離までなら最寄りの都道府県とみなす。
const nearestPrefectureKilometers = 5.0;

/// 位置から都道府県を引く。通信せず、同梱した境界だけで決める。
class PrefectureIndex {
  PrefectureIndex._(this._prefectures);

  static final empty = PrefectureIndex._(const []);

  /// [prefecturesAsset] の中身から作る。
  factory PrefectureIndex.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return PrefectureIndex._([
      for (final entry in json['prefectures'] as List)
        _Prefecture.fromJson(entry as Map<String, dynamic>),
    ]);
  }

  final List<_Prefecture> _prefectures;
  final _cache = <(double, double), String?>{};

  /// 都道府県の名前の一覧（北から順）。
  List<String> get names => [for (final p in _prefectures) p.name];

  /// [latitude]・[longitude]のある都道府県（「東京都」など）。日本の外や沖の海ならnull。
  String? prefectureAt(double latitude, double longitude) => _cache.putIfAbsent(
    (latitude, longitude),
    () => _lookup(latitude, longitude),
  );

  /// 店の都道府県。位置のわからない店はnull。
  String? prefectureOf(Shop shop) {
    final latitude = shop.latitude;
    final longitude = shop.longitude;
    if (latitude == null || longitude == null) return null;
    return prefectureAt(latitude, longitude);
  }

  String? _lookup(double latitude, double longitude) {
    final x = longitude * 1000;
    final y = latitude * 1000;
    for (final prefecture in _prefectures) {
      if (prefecture.contains(x, y)) return prefecture.name;
    }
    // 1度あたりの距離（km）で、経度は緯度に応じて縮める。
    final kmPerUnitY = 111.32 / 1000;
    final kmPerUnitX = kmPerUnitY * math.cos(latitude * math.pi / 180);
    final marginX = nearestPrefectureKilometers / kmPerUnitX;
    final marginY = nearestPrefectureKilometers / kmPerUnitY;
    String? nearest;
    var best = nearestPrefectureKilometers;
    for (final prefecture in _prefectures) {
      if (!prefecture.isNear(x, y, marginX, marginY)) continue;
      final distance = prefecture.distanceKm(x, y, kmPerUnitX, kmPerUnitY);
      if (distance <= best) {
        best = distance;
        nearest = prefecture.name;
      }
    }
    return nearest;
  }
}

/// 同梱した境界。アプリの起動時に読み込んで上書きする（テストなどで読み込まなければ、どの店も都道府県なし）。
final prefectureIndexProvider = Provider<PrefectureIndex>(
  (ref) => PrefectureIndex.empty,
);

class _Prefecture {
  _Prefecture(this.name, this.rings)
    : minX = rings.map((r) => r.minX).reduce(math.min),
      maxX = rings.map((r) => r.maxX).reduce(math.max),
      minY = rings.map((r) => r.minY).reduce(math.min),
      maxY = rings.map((r) => r.maxY).reduce(math.max);

  factory _Prefecture.fromJson(Map<String, dynamic> json) => _Prefecture(
    json['name'] as String,
    [for (final ring in json['rings'] as List) _Ring.decode(ring as List)],
  );

  final String name;
  final List<_Ring> rings;
  final int minX;
  final int maxX;
  final int minY;
  final int maxY;

  /// 輪をすべて重ねて数える（穴の輪も同じ扱いで、内側の数が奇数なら中）。
  bool contains(double x, double y) {
    if (x < minX || x > maxX || y < minY || y > maxY) return false;
    var inside = false;
    for (final ring in rings) {
      if (ring.crosses(x, y)) inside = !inside;
    }
    return inside;
  }

  bool isNear(double x, double y, double marginX, double marginY) =>
      x >= minX - marginX &&
      x <= maxX + marginX &&
      y >= minY - marginY &&
      y <= maxY + marginY;

  double distanceKm(double x, double y, double kmPerUnitX, double kmPerUnitY) {
    var best = double.infinity;
    for (final ring in rings) {
      best = math.min(best, ring.distanceKm(x, y, kmPerUnitX, kmPerUnitY));
    }
    return best;
  }
}

/// 1つの輪。座標は 1/1000 度単位の整数。
class _Ring {
  _Ring(this.xs, this.ys)
    : minX = xs.reduce(math.min),
      maxX = xs.reduce(math.max),
      minY = ys.reduce(math.min),
      maxY = ys.reduce(math.max);

  /// 1つ前の点との差で持った座標を戻す。
  factory _Ring.decode(List<dynamic> deltas) {
    final count = deltas.length ~/ 2;
    final xs = Int32List(count);
    final ys = Int32List(count);
    var x = 0;
    var y = 0;
    for (var i = 0; i < count; i++) {
      x += deltas[i * 2] as int;
      y += deltas[i * 2 + 1] as int;
      xs[i] = x;
      ys[i] = y;
    }
    return _Ring(xs, ys);
  }

  final Int32List xs;
  final Int32List ys;
  final int minX;
  final int maxX;
  final int minY;
  final int maxY;

  /// (x, y) から右へ伸ばした線が、この輪の辺と奇数回交わるか。
  bool crosses(double x, double y) {
    if (x < minX || x > maxX || y < minY || y > maxY) return false;
    var inside = false;
    for (var i = 0, j = xs.length - 1; i < xs.length; j = i++) {
      final yi = ys[i];
      final yj = ys[j];
      if ((yi > y) != (yj > y) &&
          x < (xs[j] - xs[i]) * (y - yi) / (yj - yi) + xs[i]) {
        inside = !inside;
      }
    }
    return inside;
  }

  double distanceKm(double x, double y, double kmPerUnitX, double kmPerUnitY) {
    var best = double.infinity;
    for (var i = 0, j = xs.length - 1; i < xs.length; j = i++) {
      final ax = (xs[j] - x) * kmPerUnitX;
      final ay = (ys[j] - y) * kmPerUnitY;
      final bx = (xs[i] - x) * kmPerUnitX;
      final by = (ys[i] - y) * kmPerUnitY;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : ((-ax * dx - ay * dy) / lengthSquared).clamp(0.0, 1.0);
      final px = ax + t * dx;
      final py = ay + t * dy;
      best = math.min(best, math.sqrt(px * px + py * py));
    }
    return best;
  }
}
