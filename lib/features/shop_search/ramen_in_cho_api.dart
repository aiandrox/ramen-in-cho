import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../records/models.dart';
import 'builtin_shops.dart';
import 'found_shop.dart';
import 'geo.dart';
import 'overpass_client.dart';

/// 麺印帳のサーバー（Cloudflare Pages、issue #172）。`--dart-define=RAMEN_IN_CHO_API=` で空にすると使わない。
const ramenInChoApiBase = String.fromEnvironment(
  'RAMEN_IN_CHO_API',
  defaultValue: 'https://ramen-in-cho.aiandrox.com/api/v1',
);

final ramenInChoApiProvider = Provider<RamenInChoApi?>((ref) {
  if (ramenInChoApiBase.isEmpty) return null;
  final client = http.Client();
  ref.onDispose(client.close);
  return RamenInChoApi(
    client,
    base: Uri.parse(ramenInChoApiBase),
    appCheckToken: _firebaseAppCheckToken,
  );
});

Future<String?> _firebaseAppCheckToken() async {
  try {
    return await FirebaseAppCheck.instance.getToken();
  } catch (e) {
    debugPrint('App Check getToken failed: $e');
    return null;
  }
}

/// サーバーの応答（手で持つ店の一覧）。[shops]がnullなら、前に取った一覧から変わっていない（304）。
class CuratedShopsResponse {
  const CuratedShopsResponse({this.shops, this.etag});

  final List<BuiltinShop>? shops;
  final String? etag;
}

class RamenInChoApi {
  RamenInChoApi(this._client, {required this._base, this._appCheckToken});

  /// 落ちているときに、端末から直接の検索へ早めに切り替えるため短くする。
  static const timeout = Duration(seconds: 6);
  static const _appCheckTimeout = Duration(seconds: 3);

  final http.Client _client;
  final Uri _base;

  /// アプリからの問い合わせだと示す Firebase App Check のトークン。取れなければ付けずに問い合わせる。
  final Future<String?> Function()? _appCheckToken;

  Uri _uri(String path, [Map<String, String>? query]) =>
      _base.replace(path: '${_base.path}$path', queryParameters: query);

  Future<http.Response> _get(
    Uri uri, {
    Map<String, String> headers = const {},
    Duration timeout = RamenInChoApi.timeout,
  }) async {
    // トークンを待つ時間も含めて [timeout] に収め、端末から直接の検索へ早めに切り替える。
    Future<http.Response> send() async {
      final appCheckToken = await _appCheckToken?.call().timeout(
        _appCheckTimeout,
        onTimeout: () => null,
      );
      return _client.get(
        uri,
        headers: {
          'User-Agent': shopSearchUserAgent,
          'X-Firebase-AppCheck': ?appCheckToken,
          ...headers,
        },
      );
    }

    final response = await send().timeout(timeout);
    if (response.statusCode != 200 && response.statusCode != 304) {
      throw http.ClientException(
        'Ramen-In-Cho API: HTTP ${response.statusCode}',
        uri,
      );
    }
    return response;
  }

  /// 手で持つ店の一覧。[etag]が変わっていなければ一覧は返さない。
  Future<CuratedShopsResponse> curatedShops({String? etag}) async {
    final response = await _get(
      _uri('/curated-shops'),
      headers: {'If-None-Match': ?etag},
    );
    final newEtag = response.headers['etag'] ?? etag;
    if (response.statusCode == 304) return CuratedShopsResponse(etag: newEtag);
    return CuratedShopsResponse(
      shops: parseCuratedShops(utf8.decode(response.bodyBytes)),
      etag: newEtag,
    );
  }

  /// 近くの店（サーバーが手で持つ店・Overpass・OpenPOI・Yahoo! をまとめて返す）。
  Future<List<FoundShop>> searchNearby(
    GeoPoint center, {
    int radiusMeters = shopSearchRadiusMeters,
    Duration timeout = RamenInChoApi.timeout,
  }) async {
    final response = await _get(
      _uri('/shops/nearby', {
        'lat': '${center.latitude}',
        'lon': '${center.longitude}',
        'radius': '$radiusMeters',
      }),
      timeout: timeout,
    );
    return parseApiShops(utf8.decode(response.bodyBytes));
  }

  /// 店名で探す（空白の言い換えもサーバーで行う）。
  Future<List<FoundShop>> searchByName(
    String name, {
    GeoPoint? near,
    Duration timeout = RamenInChoApi.timeout,
  }) async {
    final response = await _get(
      _uri('/shops/search', {
        'q': name.trim(),
        if (near != null) 'lat': '${near.latitude}',
        if (near != null) 'lon': '${near.longitude}',
      }),
      timeout: timeout,
    );
    return parseApiShops(utf8.decode(response.bodyBytes));
  }

  /// 住所を位置にする（サーバーが Yahoo! ジオコーダに問い合わせる）。見つからなければnull。
  Future<GeoPoint?> geocode(String address) async {
    final response = await _get(_uri('/geocode', {'q': address.trim()}));
    return parseGeocode(utf8.decode(response.bodyBytes));
  }
}

/// 住所の一致がこれより粗い（市区町村・町名まで）位置は、店の位置にするには離れすぎるので使わない。
const geocodeMinLevel = 4;

/// `/geocode` の応答。丁目より細かく合った位置だけを返す。
GeoPoint? parseGeocode(String body) {
  final decoded = jsonDecode(body);
  final result = decoded is Map<String, dynamic> ? decoded['result'] : null;
  if (result is! Map<String, dynamic>) return null;
  if ((result['latitude'], result['longitude'], result['level'])
      case (final num lat, final num lon, final num level)
      when level >= geocodeMinLevel) {
    return GeoPoint(lat.toDouble(), lon.toDouble());
  }
  return null;
}

/// 住所を位置にする。サーバーに届かないときや見つからないときはnull（端末から直接は問い合わせない）。
final addressGeocoderProvider = Provider<Future<GeoPoint?> Function(String)>((
  ref,
) {
  final api = ref.watch(ramenInChoApiProvider);
  return (address) async {
    if (api == null || address.trim().isEmpty) return null;
    try {
      return await api.geocode(address);
    } catch (e) {
      debugPrint('Geocode failed: $e');
      return null;
    }
  };
});

/// `/curated-shops` の応答。形の崩れた店は捨てる。
List<BuiltinShop> parseCuratedShops(String body) {
  final decoded = jsonDecode(body);
  final shops = decoded is Map<String, dynamic> ? decoded['shops'] : null;
  if (shops is! List) {
    throw const FormatException('curated-shops の応答に shops がありません');
  }
  return [
    for (final shop in shops)
      if (shop is Map<String, dynamic>) ?BuiltinShop.fromJson(shop),
  ];
}

/// `/shops/nearby`・`/shops/search` の応答。名前か位置の無い店は捨てる。
List<FoundShop> parseApiShops(String body) {
  final decoded = jsonDecode(body);
  final shops = decoded is Map<String, dynamic> ? decoded['shops'] : null;
  if (shops is! List) {
    throw const FormatException('店の検索の応答に shops がありません');
  }
  String? text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
  List<String> strings(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is String) item,
  ];
  return [
    for (final shop in shops)
      if (shop is Map<String, dynamic>)
        if ((text(shop['name']), shop['latitude'], shop['longitude']) case (
          final String name,
          final num lat,
          final num lon,
        ))
          FoundShop(
            osmId: text(shop['osmId']),
            name: name,
            location: GeoPoint(lat.toDouble(), lon.toDouble()),
            address: text(shop['address']),
            dataSource: switch (shop['dataSource']) {
              final Map<String, dynamic> source => ShopSource(
                licenses: strings(source['licenses']),
                attributions: strings(source['attributions']),
              ),
              _ => null,
            },
          ),
  ];
}
