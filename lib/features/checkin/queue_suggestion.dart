import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../records/clock.dart';
import '../records/models.dart';
import '../records/record_repository.dart';
import '../shop_search/geo.dart';
import '../shop_search/location_service.dart';
import '../shop_search/shop_candidate.dart';
import '../wishes/wish_repository.dart';
import '../wishes/wishes.dart';
import 'checkin_rules.dart';

/// 食べたばかりの店で「並んだ？」と聞かないよう、この時間内に記録した店は除く。
const _recentlyVisited = Duration(hours: 3);

/// 今いる場所から100m以内にある、記録したことのある店か願を掛けた店のうち、いちばん近いもの。
/// 検索のサーバーには問い合わせない（端末にある店だけで判断する）。
ShopCandidate? queueSuggestion({
  required GeoPoint here,
  required List<Shop> shops,
  required List<Wish> wishes,
  required List<VisitWithShop> visits,
  required DateTime now,
}) {
  final recentShopIds = {
    for (final entry in visits)
      if (now.difference(entry.visit.createdAt) < _recentlyVisited &&
          !entry.visit.createdAt.isAfter(now))
        entry.visit.shopId,
  };
  final candidates = <ShopCandidate>[];
  for (final shop in shops) {
    if (recentShopIds.contains(shop.id)) continue;
    final location = ShopCandidate.fromShop(shop).location;
    if (location == null) continue;
    final distance = distanceMeters(here, location);
    if (!canCheckIn(distance)) continue;
    final wish = wishes.where((w) => wishMatchesShop(w, shop)).firstOrNull;
    final candidate = ShopCandidate.fromShop(shop, distanceMeters: distance);
    candidates.add(wish == null ? candidate : candidate.withWish(wish));
  }
  final recentShops = [
    for (final shop in shops)
      if (recentShopIds.contains(shop.id)) shop,
  ];
  for (final wish in wishes) {
    final location = wishLocation(wish);
    if (location == null) continue;
    // 撤退したばかりの願の店などで聞かないよう、記録したばかりの店に当たる願も除く。
    if (recentShops.any((shop) => wishMatchesShop(wish, shop))) continue;
    if (wish.shopId != null && shops.any((s) => s.id == wish.shopId)) continue;
    if (candidates.any((c) => c.wishId == wish.id)) continue;
    final distance = distanceMeters(here, location);
    if (!canCheckIn(distance)) continue;
    candidates.add(
      ShopCandidate(
        osmId: wish.osmId,
        name: wish.name,
        location: location,
        distanceMeters: distance,
        dataSource: wish.dataSource,
        wishId: wish.id,
      ),
    );
  }
  candidates.sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
  return candidates.firstOrNull;
}

/// アプリを開いたときに「並んだ？」と聞く店。位置情報の許可をまだもらっていなければ聞かない
/// （許可を求める画面をいきなり出さないため）。並んでいる最中は聞かない。
final queueSuggestionProvider = FutureProvider.autoDispose<ShopCandidate?>((
  ref,
) async {
  final location = ref.read(locationServiceProvider);
  // 記録や願が変わったら（食べた・願が叶った など）聞き直す。
  final visitsFuture = ref.watch(visitsProvider.future);
  ref.watch(wishesProvider);
  try {
    if (!await location.isReady()) return null;
    final here = await location.currentPosition(requestPermission: false);
    if (here == null) return null;
    final repository = ref.read(recordRepositoryProvider);
    if (await repository.activeCheckin() != null) return null;
    return queueSuggestion(
      here: here,
      shops: await repository.allShops(),
      wishes: await ref.read(wishRepositoryProvider).pendingWishes(),
      visits: await visitsFuture,
      now: ref.read(clockProvider)(),
    );
  } catch (e) {
    debugPrint('Queue suggestion failed: $e');
    return null;
  }
});
