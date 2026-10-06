import '../records/models.dart';
import 'geo.dart';
import 'overpass.dart';

const maxShopCandidates = 3;

class ShopCandidate {
  const ShopCandidate({
    this.shopId,
    this.osmId,
    required this.name,
    this.location,
    this.distanceMeters,
    this.hoursConditions,
    this.strategyMemo = '',
    this.dataSource,
    this.wishId,
    this.conditionsDraftSource,
    this.locationPinned = false,
  });

  factory ShopCandidate.fromShop(Shop shop, {double? distanceMeters}) {
    final latitude = shop.latitude;
    final longitude = shop.longitude;
    return ShopCandidate(
      shopId: shop.id,
      osmId: shop.osmId,
      name: shop.name,
      location: latitude != null && longitude != null
          ? GeoPoint(latitude, longitude)
          : null,
      distanceMeters: distanceMeters,
      hoursConditions: shop.hoursConditions,
      strategyMemo: shop.strategyMemo,
      dataSource: shop.dataSource,
    );
  }

  /// 記録済みの店のID。初めての店はnull。
  final String? shopId;
  final String? osmId;
  final String name;
  final GeoPoint? location;
  final double? distanceMeters;

  /// 記録済みの店の営業の条件。初めての店はnull（願を掛けたときに条件を入れていれば、その条件）。
  final Set<HoursCondition>? hoursConditions;

  /// 記録済みの店の攻略メモ。
  final String strategyMemo;

  final ShopSource? dataSource;

  /// 願掛け帳に書き留めた店なら、その願。
  final String? wishId;

  /// [hoursConditions]が下書き（手で持つ店の条件か、地図の営業時間から推し量った条件）なら、その出どころ。
  final ConditionsDraftSource? conditionsDraftSource;

  /// 店名で見つからず、地図で指した場所の店か（店を選び直すとき）。
  final bool locationPinned;

  /// 願で入れた条件は、下書きより優先する。
  ShopCandidate withWish(Wish wish) {
    final wished = conditionsDraftSource != null
        ? wishedConditions(wish)
        : null;
    return ShopCandidate(
      shopId: shopId,
      osmId: osmId,
      name: name,
      location: location,
      distanceMeters: distanceMeters,
      hoursConditions: wished ?? hoursConditions ?? wishedConditions(wish),
      strategyMemo: strategyMemo,
      dataSource: dataSource,
      wishId: wish.id,
      conditionsDraftSource: wished == null ? conditionsDraftSource : null,
    );
  }
}

/// 願を掛けたときに入れておいた条件。入れていなければnull。
Set<HoursCondition>? wishedConditions(Wish wish) =>
    wish.hoursConditions.isEmpty ? null : wish.hoursConditions;

/// 2つの候補が同じ店を指すか。IDで比べられないときは、名前と近さで判断する。
bool isSameShop(ShopCandidate a, ShopCandidate b) {
  if (a.shopId != null && b.shopId != null) return a.shopId == b.shopId;
  if (a.osmId != null && b.osmId != null) return a.osmId == b.osmId;
  final aLocation = a.location;
  final bLocation = b.location;
  if (a.name != b.name) {
    // OpenPOI で選んで保存した店（ID なし）と、OpenStreetMap の同じ店の表記ゆれを拾う。
    return aLocation != null &&
        bLocation != null &&
        looksLikeSameShop(a.name, aLocation, b.name, bLocation);
  }
  if (aLocation == null || bLocation == null) return true;
  return distanceMeters(aLocation, bLocation) <= shopSearchRadiusMeters;
}

/// 検索結果と記録済みの店を合わせ、半径内のものを近い順に最大[limit]件返す。
/// 同じ店が両方にあるときは記録済みの方を残す。
/// まだの願（[wishes]）の店は「願」を付けて先頭に出す。候補に無ければ願の店そのものを候補にする。
List<ShopCandidate> rankShopCandidates({
  required GeoPoint here,
  required List<FoundShop> found,
  required List<Shop> knownShops,
  List<Wish> wishes = const [],
  int radiusMeters = shopSearchRadiusMeters,
  int limit = maxShopCandidates,
}) {
  final candidates = <ShopCandidate>[];
  final knownNames = <String>{};
  for (final shop in knownShops) {
    final candidate = ShopCandidate.fromShop(shop);
    final location = candidate.location;
    if (location == null) continue;
    final distance = distanceMeters(here, location);
    if (distance > radiusMeters) continue;
    candidates.add(ShopCandidate.fromShop(shop, distanceMeters: distance));
    knownNames.add(shop.name);
  }
  final known = [...candidates];
  for (final shop in found) {
    if (knownNames.contains(shop.name)) continue;
    final distance = distanceMeters(here, shop.location);
    if (distance > radiusMeters) continue;
    final suggested = shop.suggestedConditions;
    final candidate = ShopCandidate(
      osmId: shop.osmId,
      name: shop.name,
      location: shop.location,
      distanceMeters: distance,
      hoursConditions: suggested,
      dataSource: shop.dataSource,
      conditionsDraftSource: shop.suggestedConditionsSource,
    );
    if (known.any((k) => isSameShop(k, candidate))) continue;
    candidates.add(candidate);
  }
  final wished = <ShopCandidate>[];
  for (final wish in wishes) {
    final latitude = wish.latitude;
    final longitude = wish.longitude;
    final index = candidates.indexWhere(
      (c) =>
          (wish.shopId != null && c.shopId == wish.shopId) ||
          isSameShop(c, _wishCandidate(wish)),
    );
    if (index >= 0) {
      wished.add(candidates.removeAt(index).withWish(wish));
      continue;
    }
    if (latitude == null || longitude == null) continue;
    final distance = distanceMeters(here, GeoPoint(latitude, longitude));
    if (distance > radiusMeters) continue;
    wished.add(
      ShopCandidate(
        shopId: wish.shopId,
        osmId: wish.osmId,
        name: wish.name,
        location: GeoPoint(latitude, longitude),
        distanceMeters: distance,
        hoursConditions: wishedConditions(wish),
        dataSource: wish.dataSource,
        wishId: wish.id,
      ),
    );
  }
  int byDistance(ShopCandidate a, ShopCandidate b) =>
      a.distanceMeters!.compareTo(b.distanceMeters!);
  wished.sort(byDistance);
  candidates.sort(byDistance);
  return [...wished, ...candidates].take(limit).toList();
}

ShopCandidate _wishCandidate(Wish wish) {
  final latitude = wish.latitude;
  final longitude = wish.longitude;
  return ShopCandidate(
    osmId: wish.osmId,
    name: wish.name,
    location: latitude != null && longitude != null
        ? GeoPoint(latitude, longitude)
        : null,
  );
}
