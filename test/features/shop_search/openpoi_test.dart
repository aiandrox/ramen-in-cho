import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/openpoi.dart';
import 'package:ramen_in_cho/features/shop_search/openpoi_client.dart';

void main() {
  group('parseOpenPoiResponse', () {
    final sample = File('test/fixtures/openpoi_shinjuku.json')
        .readAsStringSync();

    test('保存した応答から名前と位置のある店を取り出す', () {
      final shops = parseOpenPoiResponse(sample);

      final hayashida = shops.firstWhere((s) => s.name == 'らぁ麺　はやし田');
      expect(hayashida.osmId, isNull);
      expect(hayashida.location.latitude, closeTo(35.690633647, 1e-9));
      expect(hayashida.dataSource!.licenses, [
        'CC BY 4.0',
        'CDLA-Permissive-2.0',
      ]);
      expect(
        hayashida.dataSource!.attributions,
        contains('東京都新宿区食品等営業許可・届出一覧'),
      );
    });

    test('位置が町丁目までしかわからない施設は捨てる', () {
      final shops = parseOpenPoiResponse(sample);

      // 23件のうち「♯新宿地下ラーメン」だけが level 3。
      expect(shops, hasLength(22));
      expect(shops.map((s) => s.name), isNot(contains('♯新宿地下ラーメン')));
    });

    test('座標の無い施設は捨てる', () {
      const body =
          '{"results":[{"name":"位置なし","lat":"","lng":""},'
          '{"name":"","lat":35.0,"lng":139.0},'
          '{"name":"麺屋","lat":35.0,"lng":139.0,"level":""}]}';

      expect(parseOpenPoiResponse(body).single.name, '麺屋');
    });

    test('「麺屋」で拾ったパスタの店は除く', () {
      const body =
          '{"results":[{"name":"洋麺屋五右衛門 新宿東口店","lat":35.0,"lng":139.0},'
          '{"name":"麺屋海神","lat":35.0,"lng":139.0}]}';

      expect(parseOpenPoiResponse(body).single.name, '麺屋海神');
    });

    test('想定外の応答は失敗として扱う', () {
      expect(() => parseOpenPoiResponse('[]'), throwsFormatException);
      expect(() => parseOpenPoiResponse('{}'), throwsFormatException);
    });
  });

  test('buildOpenPoiUri は経度・緯度の順で中心を渡す', () {
    final uri = buildOpenPoiUri(
      const GeoPoint(35.69, 139.70),
      '中華そば',
      radiusMeters: 1000,
    );

    expect(uri.host, 'api.openpoiapi.com');
    expect(uri.queryParameters['center'], '139.7,35.69');
    expect(uri.queryParameters['radius'], '1000');
    expect(uri.queryParameters['q'], '中華そば');
  });

  group('OpenPoiClient', () {
    http.Response respond(List<Map<String, Object>> results) =>
        http.Response.bytes(utf8.encode(jsonEncode({'results': results})), 200);

    test('語ごとに探し、同じ店をまとめる', () async {
      final keywords = <String>[];
      final client = OpenPoiClient(
        MockClient((request) async {
          final keyword = request.url.queryParameters['q']!;
          keywords.add(keyword);
          return respond([
            if (keyword == 'ラーメン') {'name': 'はれのひ', 'lat': 35.0, 'lng': 139.0},
            if (keyword == '麺屋') ...[
              {'name': '麺屋ふじみち', 'lat': 35.001, 'lng': 139.0},
              {'name': 'はれのひ', 'lat': 35.0, 'lng': 139.0},
            ],
          ]);
        }),
      );

      final shops = await client.searchNearby(const GeoPoint(35.0, 139.0));

      expect(keywords, unorderedEquals(openPoiKeywords));
      expect(shops.map((s) => s.name), ['はれのひ', '麺屋ふじみち']);
    });

    test('一部の語が失敗しても、ほかの語の結果を返す', () async {
      final client = OpenPoiClient(
        MockClient((request) async {
          if (request.url.queryParameters['q'] != '麺屋') {
            return http.Response('', 503);
          }
          return respond([
            {'name': '麺屋ふじみち', 'lat': 35.0, 'lng': 139.0},
          ]);
        }),
      );

      final shops = await client.searchNearby(const GeoPoint(35.0, 139.0));

      expect(shops.single.name, '麺屋ふじみち');
    });

    test('すべての語が失敗したら失敗にする', () {
      final client = OpenPoiClient(
        MockClient((_) async => http.Response('', 503)),
      );

      expect(
        client.searchNearby(const GeoPoint(35.0, 139.0)),
        throwsA(isA<http.ClientException>()),
      );
    });
  });

  group('店名で探す', () {
    test('全国から探し、近い順の基準があれば中心を渡す', () {
      final nationwide = buildOpenPoiNameUri(' ふじみち ');
      expect(nationwide.queryParameters['q'], 'ふじみち');
      expect(nationwide.queryParameters.containsKey('center'), isFalse);

      final near = buildOpenPoiNameUri(
        'ふじみち',
        near: const GeoPoint(35.69, 139.70),
      );
      expect(near.queryParameters['center'], '139.7,35.69');
    });

    test('同じ店をまとめ、住所が無ければ都道府県と市区町村を添える', () async {
      final client = OpenPoiClient(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'suggestions': [
                  {
                    'name': '麺屋ふじみち',
                    'prefecture': '東京都',
                    'city': '新宿区',
                    'address': '',
                    'lat': 35.69,
                    'lng': 139.71,
                  },
                  {
                    'name': '麺屋 ふじみち',
                    'address': '東京都新宿区西新宿',
                    'lat': 35.6901,
                    'lng': 139.71,
                  },
                  {
                    'name': 'ふじみち',
                    'address': '埼玉県加須市',
                    'lat': 36.1,
                    'lng': 139.6,
                  },
                ],
              }),
            ),
            200,
          ),
        ),
      );

      final shops = await client.searchByName('ふじみち');

      expect(shops.map((s) => s.name), ['麺屋ふじみち', 'ふじみち']);
      expect(shops.first.address, '東京都新宿区');
      expect(shops.last.address, '埼玉県加須市');
    });
  });

  test('まわりの施設でいちばん多い市区町村を、その場所の地名にする', () {
    expect(
      parseOpenPoiArea(
        '{"results":[{"city":"新宿区"},{"city":""},{"city":"新宿区"},'
        '{"city":"渋谷区"}]}',
      ),
      '新宿区',
    );
    expect(parseOpenPoiArea('{"results":[]}'), isNull);
    expect(
      buildOpenPoiAreaUri(const GeoPoint(35.69, 139.71)).queryParameters,
      containsPair('center', '139.71,35.69'),
    );
  });

  test('店名で探した結果は、飲食店でない施設を除き、ラーメン屋らしい店を先に並べる', () {
    final shops = parseOpenPoiNameResults(
      jsonEncode({
        'suggestions': [
          {'name': '藤の家', 'category': 'restaurant', 'lat': 35.0, 'lng': 139.0},
          {
            'name': '藤森工業',
            'category': 'retail_other',
            'lat': 35.0,
            'lng': 139.0,
          },
          {'name': '藤井施術院', 'category': 'medical', 'lat': 35.0, 'lng': 139.0},
          {
            'name': '麺屋ふじみち',
            'category': 'restaurant',
            'lat': 35.1,
            'lng': 139.0,
          },
          {'name': '藤ストアー', 'category': 'unknown', 'lat': 35.2, 'lng': 139.0},
        ],
      }),
    );

    expect(shops.map((s) => s.name), ['麺屋ふじみち', '藤の家', '藤ストアー']);
  });

  test('店名で探すときは、すべての語に合う店だけを返す窓口を使う', () {
    final uri = buildOpenPoiNameUri('麺屋 ふじみち');
    expect(uri.path, '/v1/suggest');
    expect(uri.queryParameters['q'], '麺屋 ふじみち');
  });
}
