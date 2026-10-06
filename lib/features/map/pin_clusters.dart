import 'dart:math' as math;

import '../shop_search/geo.dart';

/// ピンの頭（30px）が重なり始める画面上の距離。これより近いピンは1つにまとめる。
const clusterRadiusPixels = 34.0;

/// まとめたピンをタップして寄るときの、いちばん寄った倍率。
const clusterFitMaxZoom = 18.0;

/// 地図の倍率 [zoom] での、Web メルカトルの画面上の位置（タイル256px）。
math.Point<double> mercatorPixel(GeoPoint point, int zoom) {
  final scale = 256.0 * math.pow(2, zoom);
  final x = (point.longitude + 180) / 360 * scale;
  final sinLat = math.sin(
    point.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180,
  );
  final y =
      (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
  return math.Point(x, y);
}

/// 画面上で近いピンをまとめたもの。1つだけなら、まとめずにそのピンを出す。
class PinCluster<T> {
  const PinCluster({required this.members, required this.location});

  final List<T> members;

  /// まとめた印を置く場所（中の店の位置の平均）。
  final GeoPoint location;

  bool get isSingle => members.length == 1;
}

/// [zoom] の倍率で、画面上で [radius] より近いピンをまとめる。
/// 並び順に、まだまとまっていないピンを起点にし、その近くのピンを集める（同じ入力なら同じ結果）。
/// 近くを探すのは周りのます目だけなので、数百件でも軽い。
List<PinCluster<T>> clusterPins<T>(
  List<T> items, {
  required GeoPoint Function(T item) locate,
  required int zoom,
  double radius = clusterRadiusPixels,
}) {
  final pixels = [for (final item in items) mercatorPixel(locate(item), zoom)];
  final grid = <(int, int), List<int>>{};
  (int, int) cellOf(math.Point<double> p) =>
      ((p.x / radius).floor(), (p.y / radius).floor());
  for (var i = 0; i < items.length; i++) {
    (grid[cellOf(pixels[i])] ??= []).add(i);
  }
  final taken = List.filled(items.length, false);
  final clusters = <PinCluster<T>>[];
  for (var i = 0; i < items.length; i++) {
    if (taken[i]) continue;
    taken[i] = true;
    final seed = pixels[i];
    final (cx, cy) = cellOf(seed);
    final memberIndexes = [i];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final j in grid[(cx + dx, cy + dy)] ?? const <int>[]) {
          if (!taken[j] && seed.distanceTo(pixels[j]) < radius) {
            taken[j] = true;
            memberIndexes.add(j);
          }
        }
      }
    }
    memberIndexes.sort();
    final members = [for (final j in memberIndexes) items[j]];
    clusters.add(
      PinCluster(
        members: members,
        location: memberIndexes.length == 1
            ? locate(items[i])
            : _average([for (final j in memberIndexes) locate(items[j])]),
      ),
    );
  }
  return clusters;
}

GeoPoint _average(List<GeoPoint> points) {
  var lat = 0.0;
  var lon = 0.0;
  for (final p in points) {
    lat += p.latitude;
    lon += p.longitude;
  }
  return GeoPoint(lat / points.length, lon / points.length);
}
