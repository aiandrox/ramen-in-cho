import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/place_search.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';

void main() {
  String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

  group('placeSearchNames', () {
    test('「駅」を外し、市町村は「市・町・村・区」をつけた名前でも探す', () {
      final names = placeSearchNames('厚木駅');
      expect(names.stations, {'厚木'});
      expect(names.places, {'厚木', '厚木市', '厚木町', '厚木村', '厚木区'});
    });

    test('「厚木市」と打てば、駅は「厚木」でも探す', () {
      final names = placeSearchNames(' 厚木市 ');
      expect(names.stations, {'厚木市', '厚木'});
      expect(names.places, contains('厚木市'));
    });

    test('問い合わせを壊す記号は取り除き、空なら何も探さない', () {
      expect(placeSearchNames('横"浜\\').stations, {'横浜'});
      expect(placeSearchNames('  ').stations, isEmpty);
    });
  });

  test('問い合わせは名前がぴったり合う駅と市町村を探す', () {
    final query = buildPlaceSearchQuery('厚木');
    expect(query, contains('nwr["name"="厚木"]["railway"="station"];'));
    expect(query, contains('node["name"="厚木市"]["place"];'));
    expect(query, contains('[timeout:23]'));
  });

  test('駅には「駅」をつけ、市と駅を候補にし、集落や外国の村は除く', () {
    final places = parsePlaceSearchResponse(
      fixture('overpass_place_atsugi.json'),
      '厚木',
    );

    expect(places.map((p) => p.name), ['厚木駅', '厚木市']);
    expect(places.first.kind, PlaceKind.station);
    expect(places.first.operators, ['小田急電鉄', 'JR東日本']);
    expect(places.last.kind, PlaceKind.city);
  });

  test('同じ名前の駅は場所ごとに分け、現在地が分かれば近い順にする', () {
    final tokyo = const GeoPoint(35.68, 139.76);
    final places = parsePlaceSearchResponse(
      fixture('overpass_place_fuchu.json'),
      '府中',
      near: tokyo,
    );
    final stations = [
      for (final p in places)
        if (p.kind == PlaceKind.station) p,
    ];

    // 台北の府中駅は除き、同じ駅の点（ノードと線）は1つにまとめる。
    expect(stations, hasLength(4));
    expect(stations.every((s) => s.name == '府中駅'), isTrue);
    expect(stations.first.location.longitude, closeTo(139.48, 0.01));
    expect(places.take(4).every((p) => p.kind == PlaceKind.station), isTrue);
    expect(places.map((p) => p.name), contains('府中市'));
  });

  test('サーバーで時間切れになった応答は失敗にする', () {
    expect(
      () => parsePlaceSearchResponse(
        '{"elements": [], "remark": "runtime error: Query timed out"}',
        '厚木',
      ),
      throwsFormatException,
    );
  });
}
