import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/map/pin_clusters.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';

void main() {
  const shinjuku = GeoPoint(35.6905, 139.7004);
  const sapporo = GeoPoint(43.0687, 141.3508);
  // 新宿から北へ約110m。倍率14では画面上で約14px、倍率17では約115px離れる。
  const nearShinjuku = GeoPoint(35.6915, 139.7004);

  List<PinCluster<GeoPoint>> cluster(List<GeoPoint> points, int zoom) =>
      clusterPins(points, locate: (p) => p, zoom: zoom);

  test('倍率0では、緯度0・経度0が256pxの地図の真ん中になる', () {
    final p = mercatorPixel(const GeoPoint(0, 0), 0);
    expect(p.x, closeTo(128, 1e-9));
    expect(p.y, closeTo(128, 1e-9));
  });

  test('離れたピンはまとめず、1つずつにする', () {
    final clusters = cluster([shinjuku, sapporo], 14);
    expect(clusters, hasLength(2));
    expect(clusters.every((c) => c.isSingle), isTrue);
    expect(clusters.first.location, shinjuku);
  });

  test('画面上で重なるピンはまとめ、寄ると分かれる', () {
    final far = cluster([shinjuku, nearShinjuku], 14);
    expect(far, hasLength(1));
    expect(far.single.members, [shinjuku, nearShinjuku]);
    expect(far.single.location.latitude, closeTo(35.691, 1e-9));

    final close = cluster([shinjuku, nearShinjuku], 17);
    expect(close, hasLength(2));
  });

  test('まとめる距離の境目: 半径より近ければまとめ、離れていればまとめない', () {
    final a = mercatorPixel(shinjuku, 15);
    // 半径のすぐ内側と外側に来る経度を、画面上の距離から求める。
    final degreesPerPixel = 360 / (256 * 32768);
    GeoPoint east(double pixels) => GeoPoint(
      shinjuku.latitude,
      shinjuku.longitude + pixels * degreesPerPixel,
    );
    expect(mercatorPixel(east(10), 15).x - a.x, closeTo(10, 1e-6));

    expect(
      cluster([shinjuku, east(clusterRadiusPixels - 1)], 15),
      hasLength(1),
    );
    expect(
      cluster([shinjuku, east(clusterRadiusPixels + 1)], 15),
      hasLength(2),
    );
  });

  test('同じ入力なら同じ結果になり、どのピンもちょうど1回だけ入る', () {
    final points = [
      for (var i = 0; i < 300; i++)
        GeoPoint(
          shinjuku.latitude + (i % 20) * 0.0007,
          shinjuku.longitude + (i ~/ 20) * 0.0009,
        ),
    ];
    final first = cluster(points, 15);
    final second = cluster(points, 15);
    expect(
      [for (final c in first) c.members],
      [for (final c in second) c.members],
    );
    expect(first.length, lessThan(points.length));
    final all = [for (final c in first) ...c.members];
    expect(all, hasLength(points.length));
    expect(all.toSet(), points.toSet());
  });
}
