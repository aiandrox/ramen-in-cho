import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'builtin_shops.dart';
import 'curated_shops_store.dart';
import 'geo.dart';
import 'openpoi_client.dart';
import 'overpass.dart';
import 'overpass_client.dart';
import 'ramen_in_cho_api.dart';

final nearbyShopFinderProvider = Provider<NearbyShopFinder>(
  (ref) => NearbyShopFinder(
    overpass: ref.watch(overpassClientProvider),
    openPoi: ref.watch(openPoiClientProvider),
    api: ref.watch(ramenInChoApiProvider),
    curated: () => ref.read(curatedShopsProvider),
  ),
);

/// まずサーバー（手で持つ店・Overpass・OpenPOI・Yahoo! をまとめる）に聞き、届かなければ
/// 端末から Overpass と OpenPOI を同時に探して1つにまとめる。Yahoo! の Client ID はアプリに持たない。
class NearbyShopFinder {
  NearbyShopFinder({
    required this._overpass,
    required this._openPoi,
    this._api,
    List<BuiltinShop> Function()? curated,
  }) : _curated = curated ?? (() => builtinShops);

  final OverpassClient _overpass;
  final OpenPoiClient _openPoi;

  /// 麺印帳のサーバー。使えるときはまずサーバーに聞き、だめなら端末から直接探す。
  final RamenInChoApi? _api;

  /// 手で持つ店（サーバーから取り直した一覧か、同梱分）。
  final List<BuiltinShop> Function() _curated;

  /// どれかが失敗しても、ほかの結果を返す。すべて失敗したときだけ例外にする。
  Future<List<FoundShop>> searchNearby(
    GeoPoint center, {
    int radiusMeters = shopSearchRadiusMeters,
    Duration timeout = OverpassClient.timeout,
  }) async {
    Future<List<FoundShop>?> attempt(
      String label,
      Future<List<FoundShop>> Function() search,
    ) async {
      try {
        return await search();
      } catch (e) {
        debugPrint('$label search failed: $e');
        return null;
      }
    }

    // 手で持つ店（ラーメン二郎の直系店）は、通信できなくても出す。
    final curated = _curated();
    final builtin = builtinShopsNear(center, radiusMeters, shops: curated);
    final api = _api;
    if (api != null) {
      try {
        final shops = await api.searchNearby(
          center,
          radiusMeters: radiusMeters,
          timeout: timeout,
        );
        return mergeFoundShops(shops, builtin);
      } catch (e) {
        debugPrint('Ramen-In-Cho API search failed: $e');
      }
    }
    final [osm, poi] = await Future.wait([
      attempt(
        'Overpass',
        () => _overpass.searchNearby(
          center,
          radiusMeters: radiusMeters,
          timeout: timeout,
        ),
      ),
      attempt(
        'OpenPOI',
        () => _openPoi.searchNearby(
          center,
          radiusMeters: radiusMeters,
          timeout: timeout,
        ),
      ),
    ]);
    if (osm == null && poi == null) {
      if (builtin.isNotEmpty) return builtin;
      throw StateError('店の検索がすべて失敗しました');
    }
    // OpenStreetMap の店を優先し（IDがあるため）、次にアプリに持たせている店、最後に OpenPOI。
    return mergeFoundShops(osm ?? const [], [...builtin, ...?poi]);
  }
}
