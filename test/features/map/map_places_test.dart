import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/map/map_places.dart';
import 'package:ramen_in_cho/features/map/shop_pins.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/shop_search/found_shop.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';

import '../../support/builders.dart';

void main() {
  const shinjuku = GeoPoint(35.6905, 139.7004);

  final visited = VisitedPlace(
    ShopPin(
      shop: buildShop(id: 'v', name: '行った店', isFamous: true),
      latitude: 35.6925,
      longitude: 139.7004,
      eatenCount: 1,
      retreatCount: 0,
      lastVisitAt: DateTime(2026, 10, 1),
      lastVisitId: 'visit',
    ),
  );
  final wished = WishedPlace(
    Wish(
      id: 'w',
      name: '願の店',
      latitude: 35.6955,
      longitude: 139.7004,
      createdAt: DateTime(2026, 10, 1),
    ),
  );
  const unvisitedNear = UnvisitedPlace(
    FoundShop(
      osmId: 'node/1',
      name: '近い店',
      location: GeoPoint(35.6908, 139.7004),
    ),
  );
  const unvisitedFar = UnvisitedPlace(
    FoundShop(name: '遠い店', location: GeoPoint(35.4437, 139.6380)),
  );
  final places = <MapPlace>[unvisitedFar, wished, visited, unvisitedNear];

  test('地図の真ん中から近い順に並べる', () {
    expect(
      [for (final p in mapPlaceList(places, center: shinjuku)) p.name],
      ['近い店', '行った店', '願の店', '遠い店'],
    );
  });

  test('行った店・まだ・願で絞り込める', () {
    List<String> names(MapListFilter filter) => [
      for (final p in mapPlaceList(places, center: shinjuku, filter: filter))
        p.name,
    ];
    expect(names(MapListFilter.visited), ['行った店']);
    expect(names(MapListFilter.unvisited), ['近い店', '遠い店']);
    expect(names(MapListFilter.wished), ['願の店']);
    expect(names(MapListFilter.all), hasLength(4));
  });

  test('同じ距離の店は、いつも同じ順に並べる', () {
    const a = UnvisitedPlace(
      FoundShop(osmId: 'node/b', name: 'B', location: shinjuku),
    );
    const b = UnvisitedPlace(
      FoundShop(osmId: 'node/a', name: 'A', location: shinjuku),
    );
    expect(
      [
        for (final p in mapPlaceList([a, b], center: shinjuku)) p.name,
      ],
      ['A', 'B'],
    );
    expect(
      [
        for (final p in mapPlaceList([b, a], center: shinjuku)) p.name,
      ],
      ['A', 'B'],
    );
  });

  test('名店の印は行った店だけに出す', () {
    expect(visited.isFamous, isTrue);
    expect(unvisitedNear.isFamous, isFalse);
  });
}
