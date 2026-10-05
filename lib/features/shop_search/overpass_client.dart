import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../home_base/place_search.dart';
import 'geo.dart';
import 'overpass.dart';

const shopSearchUserAgent =
    'ramen-in-cho (https://github.com/aiandrox/ramen-in-cho)';

final overpassClientProvider = Provider<OverpassClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return OverpassClient(client);
});

class OverpassClient {
  OverpassClient(this._client, {Uri? endpoint})
    : _endpoint =
          endpoint ?? Uri.parse('https://overpass-api.de/api/interpreter');

  static const timeout = Duration(seconds: 10);

  final http.Client _client;
  final Uri _endpoint;

  /// 通信の失敗・タイムアウト・想定外の応答は例外にする。呼び出し側で手入力に切り替える。
  Future<List<FoundShop>> searchNearby(
    GeoPoint center, {
    int radiusMeters = shopSearchRadiusMeters,
    Duration timeout = OverpassClient.timeout,
  }) async {
    final response = await _client
        .post(
          _endpoint,
          headers: const {'User-Agent': shopSearchUserAgent},
          body: {
            'data': buildOverpassQuery(
              center,
              radiusMeters: radiusMeters,
              // サーバーが制限時間いっぱいまで探しても、返事を受け取る時間を残す。
              timeoutSeconds: timeout.inSeconds - 2,
            ),
          },
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Overpass API: HTTP ${response.statusCode}',
        _endpoint,
      );
    }
    return parseOverpassResponse(response.body);
  }

  static const placeSearchTimeout = Duration(seconds: 25);

  /// 拠点にする駅や市町村を名前で探す。[near]は並べ替えに使うだけで、サーバーには送らない。
  /// 通信の失敗・タイムアウト・想定外の応答は例外にする。
  Future<List<PlaceCandidate>> searchPlaces(
    String name, {
    GeoPoint? near,
    Duration timeout = placeSearchTimeout,
  }) async {
    final response = await _client
        .post(
          _endpoint,
          headers: const {'User-Agent': shopSearchUserAgent},
          body: {
            'data': buildPlaceSearchQuery(
              name,
              timeoutSeconds: timeout.inSeconds - 2,
            ),
          },
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Overpass API: HTTP ${response.statusCode}',
        _endpoint,
      );
    }
    return parsePlaceSearchResponse(
      utf8.decode(response.bodyBytes),
      name,
      near: near,
    );
  }
}
