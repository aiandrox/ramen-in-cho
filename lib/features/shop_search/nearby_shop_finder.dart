import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'builtin_shops.dart';
import 'curated_shops_store.dart';
import 'geo.dart';
import 'openpoi_client.dart';
import 'overpass.dart';
import 'overpass_client.dart';
import 'ramen_in_cho_api.dart';
import 'yahoo_local.dart';
import 'yahoo_local_client.dart';

final nearbyShopFinderProvider = Provider<NearbyShopFinder>(
  (ref) => NearbyShopFinder(
    overpass: ref.watch(overpassClientProvider),
    openPoi: ref.watch(openPoiClientProvider),
    // Client ID が無いときは Yahoo! を使わない（「見つからなかった」と「探せなかった」を取り違えないため）。
    yahoo: isYahooEnabled ? ref.watch(yahooLocalClientProvider) : null,
    api: ref.watch(ramenInChoApiProvider),
    curated: () => ref.read(curatedShopsProvider),
  ),
);

/// Overpass・Yahoo!・OpenPOI を同時に探し、結果を1つにまとめる。
/// OpenStreetMap に載っていない個人店を、Yahoo!（ラーメン店の業種で絞れる）と
/// OpenPOI（食品営業許可のデータを含む）で補う。Yahoo! は Client ID があるときだけ使う。
class NearbyShopFinder {
  NearbyShopFinder({
    required this._overpass,
    required this._openPoi,
    this._yahoo,
    this._api,
    List<BuiltinShop> Function()? curated,
  }) : _curated = curated ?? (() => builtinShops);

  final OverpassClient _overpass;
  final OpenPoiClient _openPoi;
  final YahooLocalClient? _yahoo;

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
        return withCuratedConditions(mergeFoundShops(shops, builtin), curated);
      } catch (e) {
        debugPrint('Ramen-In-Cho API search failed: $e');
      }
    }
    final yahoo = _yahoo;
    final [osm, poi, yahooShops] = await Future.wait([
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
      if (yahoo == null)
        Future<List<FoundShop>?>.value()
      else
        attempt(
          'Yahoo',
          () => yahoo.searchNearby(
            center,
            radiusMeters: radiusMeters,
            timeout: timeout,
          ),
        ),
    ]);
    if (osm == null && poi == null && yahooShops == null) {
      if (builtin.isNotEmpty) return builtin;
      throw StateError('店の検索がすべて失敗しました');
    }
    // OpenStreetMap の店を優先し（IDがあるため）、次にアプリに持たせている店、Yahoo!、最後に OpenPOI。
    return withCuratedConditions(
      mergeFoundShops(osm ?? const [], [...builtin, ...?yahooShops, ...?poi]),
      curated,
    );
  }
}
