import '../records/models.dart';
import '../shop_search/found_shop.dart';
import '../shop_search/geo.dart';
import '../shop_search/shop_candidate.dart';

/// 願を掛けた店と、記録の店が同じ店か。店は記録が0件になると消えるため、IDのほかに名前と位置でも比べる。
bool wishMatchesShop(Wish wish, Shop shop) =>
    wish.shopId == shop.id ||
    wishMatchesPlace(
      wish,
      osmId: shop.osmId,
      name: shop.name,
      location: ShopCandidate.fromShop(shop).location,
    );

/// 検索で見つけた店（まだ記録の無い店）など、IDの無い店と比べる。
/// 店名だけで書き留めた願は位置がわからないので、表記の少し違う名前（「はやし田」と「らぁ麺 はやし田」）も同じ店とみなす。
bool wishMatchesPlace(
  Wish wish, {
  String? osmId,
  required String name,
  GeoPoint? location,
}) {
  final here = wishLocation(wish);
  if (here == null && wish.osmId == null) {
    return shopNamesLookAlike(wish.name, name);
  }
  return isSameShop(
    ShopCandidate(osmId: wish.osmId, name: wish.name, location: here),
    ShopCandidate(osmId: osmId, name: name, location: location),
  );
}

GeoPoint? wishLocation(Wish wish) {
  final latitude = wish.latitude;
  final longitude = wish.longitude;
  return latitude != null && longitude != null
      ? GeoPoint(latitude, longitude)
      : null;
}

/// 願を掛けた日より前の1杯ではないか（同じ日なら、掛けたあとに食べたとみなす）。
bool wishPrecedes(Wish wish, DateTime eatenAt) =>
    !_dateOnly(wish.createdAt).isAfter(_dateOnly(eatenAt));

/// 願を掛けてから、叶う（その店で食べる）までの日数。願を掛ける前の写真で記録したときは0。
int daysToFulfill(Wish wish, DateTime eatenAt) {
  final days = _dateOnly(eatenAt).difference(_dateOnly(wish.createdAt)).inDays;
  return days < 0 ? 0 : days;
}

// 夏時間のある地域でも1日を24時間として数えるため、UTCの日付で比べる。
DateTime _dateOnly(DateTime at) => DateTime.utc(at.year, at.month, at.day);

/// 店名を打っているときの候補（[query]は[normalizeShopName]したもの）。まだの願の店（位置のわからない店も）を先に出す。
List<ShopCandidate> shopNameMatches(
  String query, {
  required List<Wish> wishes,
  required List<Shop> knownShops,
}) {
  final wished = [
    for (final wish in wishes)
      if (normalizeShopName(wish.name).contains(query))
        ShopCandidate(
          shopId: wish.shopId,
          osmId: wish.osmId,
          name: wish.name,
          location: wishLocation(wish),
          dataSource: wish.dataSource,
          wishId: wish.id,
        ),
  ];
  final known = [
    for (final shop in knownShops)
      if (normalizeShopName(shop.name).contains(query) &&
          !wished.any((w) => w.shopId == shop.id))
        ShopCandidate.fromShop(shop),
  ];
  return [...wished, ...known].take(maxShopCandidates).toList();
}
