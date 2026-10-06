import '../records/models.dart';
import '../shop_search/found_shop.dart';
import '../shop_search/geo.dart';
import 'shop_pins.dart';

/// 地図に出す店（行った店・願を掛けた店・まだ行っていない店）。
sealed class MapPlace {
  const MapPlace();

  String get name;
  GeoPoint get location;

  /// 並べ替えで同じ距離の店の順を決める、変わらない鍵。
  String get key;
  bool get isFamous => false;
}

class VisitedPlace extends MapPlace {
  const VisitedPlace(this.pin);

  final ShopPin pin;

  @override
  String get name => pin.shop.name;
  @override
  GeoPoint get location => GeoPoint(pin.latitude, pin.longitude);
  @override
  String get key => 'shop:${pin.shop.id}';
  @override
  bool get isFamous => pin.shop.isFamous;
}

class WishedPlace extends MapPlace {
  const WishedPlace(this.wish);

  /// 位置のわかる願だけを入れる。
  final Wish wish;

  @override
  String get name => wish.name;
  @override
  GeoPoint get location => GeoPoint(wish.latitude!, wish.longitude!);
  @override
  String get key => 'wish:${wish.id}';
}

class UnvisitedPlace extends MapPlace {
  const UnvisitedPlace(this.shop);

  final FoundShop shop;

  @override
  String get name => shop.name;
  @override
  GeoPoint get location => shop.location;
  @override
  String get key =>
      'found:${shop.osmId ?? '${shop.name}@${shop.location.latitude},${shop.location.longitude}'}';
}

enum MapListFilter { all, visited, unvisited, wished }

bool matchesMapListFilter(MapPlace place, MapListFilter filter) =>
    switch (filter) {
      MapListFilter.all => true,
      MapListFilter.visited => place is VisitedPlace,
      MapListFilter.unvisited => place is UnvisitedPlace,
      MapListFilter.wished => place is WishedPlace,
    };

/// 一覧に出す店。[center] から近い順（同じ距離なら変わらない順）。
List<MapPlace> mapPlaceList(
  List<MapPlace> places, {
  required GeoPoint center,
  MapListFilter filter = MapListFilter.all,
}) {
  final distances = {
    for (final place in places)
      place.key: distanceMeters(center, place.location),
  };
  return [
    for (final place in places)
      if (matchesMapListFilter(place, filter)) place,
  ]..sort((a, b) {
    final byDistance = distances[a.key]!.compareTo(distances[b.key]!);
    return byDistance != 0 ? byDistance : a.key.compareTo(b.key);
  });
}
