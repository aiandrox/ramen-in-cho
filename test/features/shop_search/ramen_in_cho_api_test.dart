import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/shop_search/builtin_shops.dart';
import 'package:ramen_in_cho/features/shop_search/curated_shops_store.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/nearby_shop_finder.dart';
import 'package:ramen_in_cho/features/shop_search/openpoi_client.dart';
import 'package:ramen_in_cho/features/shop_search/overpass_client.dart';
import 'package:ramen_in_cho/features/shop_search/ramen_in_cho_api.dart';

import '../../support/fakes.dart';

final _base = Uri.parse('https://api.test/api/v1');

const _mitaJson = {
  'id': 'jiro-mita',
  'name': 'ラーメン二郎 三田本店',
  'address': '東京都港区三田2-16-4',
  'latitude': 35.648045,
  'longitude': 139.741516,
  'chain': 'jiro',
  'status': 'open',
};

http.Response _json(
  Object body, {
  int status = 200,
  Map<String, String>? headers,
}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
);

void main() {
  group('住所を位置にする', () {
    test('丁目より細かく合った位置だけを使う', () async {
      Uri? asked;
      final api = RamenInChoApi(
        MockClient((request) async {
          asked = request.url;
          return _json({
            'result': {
              'latitude': 35.68956,
              'longitude': 139.69172,
              'address': '東京都新宿区西新宿2丁目8-1',
              'level': 6,
              'attribution': 'Web Services by Yahoo! JAPAN',
            },
          });
        }),
        base: _base,
      );

      final point = await api.geocode(' 東京都新宿区西新宿2-8-1 ');

      expect(asked!.path, '/api/v1/geocode');
      expect(asked!.queryParameters['q'], '東京都新宿区西新宿2-8-1');
      expect((point!.latitude, point.longitude), (35.68956, 139.69172));
    });

    test('町名までしか合わない・見つからないときは位置にしない', () {
      expect(
        parseGeocode(
          jsonEncode({
            'result': {'latitude': 35.69, 'longitude': 139.7, 'level': 3},
          }),
        ),
        isNull,
      );
      expect(parseGeocode(jsonEncode({'result': null})), isNull);
    });
  });

  test('検索の応答から店を読む。名前か位置の無い店は捨てる', () {
    final shops = parseApiShops(
      jsonEncode({
        'shops': [
          {
            'osmId': 'node/1',
            'name': '海神',
            'latitude': 35.69,
            'longitude': 139.7,
          },
          {
            'name': 'はやし田',
            'latitude': 35.691,
            'longitude': 139.701,
            'dataSource': {
              'licenses': ['CC BY 4.0'],
              'attributions': ['Overture'],
            },
          },
          {'name': '', 'latitude': 1, 'longitude': 2},
          {'name': '位置なし'},
        ],
      }),
    );

    expect(shops.map((s) => s.name), ['海神', 'はやし田']);
    expect(shops.first.osmId, 'node/1');
    expect(shops.last.dataSource!.licenses, ['CC BY 4.0']);
  });

  test('App Check のトークンが取れれば添え、取れなければ添えずに問い合わせる', () async {
    final sent = <String?>[];
    final client = MockClient((request) async {
      sent.add(request.headers['X-Firebase-AppCheck']);
      return _json({'shops': <Object>[]});
    });
    for (final token in ['token', null]) {
      await RamenInChoApi(
        client,
        base: _base,
        appCheckToken: () async => token,
      ).searchByName('麺屋武蔵');
    }
    await RamenInChoApi(client, base: _base).searchByName('麺屋武蔵');
    expect(sent, ['token', null, null]);
  });

  test('手で持つ店の一覧から、閉店した店を外す', () {
    final shops = parseCuratedShops(
      jsonEncode({
        'shops': [
          _mitaJson,
          {..._mitaJson, 'name': '閉店した店', 'status': 'closed'},
        ],
      }),
    );

    expect(shops.map((s) => s.name), ['ラーメン二郎 三田本店']);
  });

  group('CuratedShopsStore', () {
    late Directory documents;
    late List<http.Request> requests;
    late http.Response Function(http.Request) answer;

    setUp(() {
      documents = createTempDirectory();
      requests = [];
      answer = (_) => _json(
        {
          'shops': [_mitaJson],
        },
        headers: {'etag': '"v1"'},
      );
    });

    CuratedShopsStore store() => CuratedShopsStore(
      documents,
      api: RamenInChoApi(
        MockClient((request) async {
          requests.add(request);
          return answer(request);
        }),
        base: _base,
      ),
    );

    test('初めては取りに行って保存し、1日たつまでは取り直さない', () async {
      final now = DateTime(2026, 10, 3, 12);
      final fresh = await store().refreshIfStale(null, now);
      expect(fresh!.shops.single.name, 'ラーメン二郎 三田本店');
      expect(requests.single.url.path, '/api/v1/curated-shops');

      final saved = await store().load();
      expect(saved!.etag, '"v1"');
      expect(saved.shops.single.name, 'ラーメン二郎 三田本店');

      expect(
        await store().refreshIfStale(saved, now.add(const Duration(hours: 23))),
        isNull,
      );
      expect(requests, hasLength(1));
    });

    test('1日たったら ETag を付けて聞き、変わっていなければ前の一覧のまま', () async {
      final now = DateTime(2026, 10, 3, 12);
      final saved = (await store().refreshIfStale(null, now))!;
      answer = (_) => http.Response('', 304, headers: {'etag': '"v1"'});

      final again = await store().refreshIfStale(
        saved,
        now.add(const Duration(days: 1)),
      );

      expect(requests.last.headers['If-None-Match'], '"v1"');
      expect(again!.shops.single.name, 'ラーメン二郎 三田本店');
      expect(
        (await store().load())!.fetchedAt,
        now.add(const Duration(days: 1)).toUtc(),
      );
    });

    test('前の版で保存したファイル（店の条件を捨てていた）は読まず、ETag を付けずに取り直す', () async {
      File(p.join(documents.path, CuratedShopsStore.fileName))
          .writeAsStringSync(
            jsonEncode({
              'fetchedAt': DateTime(2026, 10, 3).toUtc().toIso8601String(),
              'etag': '"v1"',
              'shops': [
                {
                  'name': 'ラーメン二郎 三田本店',
                  'address': '東京都港区三田2-16-4',
                  'latitude': 35.648045,
                  'longitude': 139.741516,
                  'status': 'open',
                },
              ],
            }),
          );
      final saved = await store().load();
      expect(saved, isNull);

      await store().refreshIfStale(saved, DateTime(2026, 10, 3, 1));
      expect(requests.single.headers['If-None-Match'], isNull);
      expect((await store().load())!.etag, '"v1"');
    });

    test('取れなければnull（同梱分か保存分のまま）', () async {
      answer = (_) => http.Response('', 503);
      expect(await store().refreshIfStale(null, DateTime(2026)), isNull);
      expect(await store().load(), isNull);
    });
  });

  group('NearbyShopFinder とサーバー', () {
    final failing = MockClient((_) async => http.Response('', 503));
    const mita = GeoPoint(35.6482, 139.7414);

    NearbyShopFinder finder(http.Client api) => NearbyShopFinder(
      overpass: OverpassClient(failing),
      openPoi: OpenPoiClient(failing),
      api: RamenInChoApi(api, base: _base),
      curated: () => builtinShops,
    );

    test('サーバーが答えれば、その結果に手で持つ店を足して返す', () async {
      final shops = await finder(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/shops/nearby');
          expect(request.url.queryParameters['radius'], '300');
          return _json({
            'shops': [
              {
                'osmId': 'node/9',
                'name': '近くの店',
                'latitude': 35.6483,
                'longitude': 139.7415,
              },
            ],
          });
        }),
      ).searchNearby(mita);

      expect(shops.map((s) => s.name), ['近くの店', 'ラーメン二郎 三田本店']);
    });

    test('サーバーが落ちていたら、端末から直接探す（ここでは直接も失敗し、手で持つ店だけ）', () async {
      final shops = await finder(failing).searchNearby(mita);

      expect(shops.map((s) => s.name), ['ラーメン二郎 三田本店']);
    });
  });
}
