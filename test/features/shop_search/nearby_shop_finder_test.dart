import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/nearby_shop_finder.dart';
import 'package:ramen_in_cho/features/shop_search/openpoi_client.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/overpass_client.dart';
import 'package:ramen_in_cho/features/shop_search/yahoo_local_client.dart';

const _origin = GeoPoint(35.69, 139.70);

/// [northMeters] だけ北にずらした店。緯度 1 度 ≒ 111km。
FoundShop _shop(String name, {double northMeters = 0, String? osmId}) =>
    FoundShop(
      osmId: osmId,
      name: name,
      location: GeoPoint(_origin.latitude + northMeters / 111000, 139.70),
    );

void main() {
  group('mergeFoundShops', () {
    test('OpenStreetMap に無い店を OpenPOI から足す', () {
      final merged = mergeFoundShops(
        [_shop('海神', osmId: 'node/1')],
        [_shop('らぁ麺 はやし田', northMeters: 50)],
      );

      expect(merged.map((s) => s.name), ['海神', 'らぁ麺 はやし田']);
    });

    test('表記の違う同じ店は OpenStreetMap の方を残す', () {
      final merged = mergeFoundShops(
        [_shop('らーめん鴨to葱', osmId: 'relation/1')],
        [_shop('鴨 to 葱', northMeters: 20), _shop('ＲＡＭＥＮ海神')],
      );

      expect(merged, hasLength(2));
      expect(merged.first.osmId, 'relation/1');
      expect(merged.last.name, 'ＲＡＭＥＮ海神');
    });

    test('OpenPOI の中で重なる店は1件にする', () {
      final merged = mergeFoundShops(const [], [
        _shop('つけ麺　五ノ神製作所'),
        _shop('つけ麺 五ノ神製作所', northMeters: 10),
      ]);

      expect(merged, hasLength(1));
    });

    test('同じ名前でも100mより離れていれば別の店（支店）にする', () {
      final merged = mergeFoundShops(
        [_shop('一風堂', osmId: 'node/1')],
        [_shop('一風堂', northMeters: 150)],
      );

      expect(merged, hasLength(2));
    });

    test('名前が1文字だけ重なる店はまとめない', () {
      final merged = mergeFoundShops(
        [_shop('凪', osmId: 'node/1')],
        [_shop('煮干しラーメン凪 別館')],
      );

      expect(merged, hasLength(2));
    });
  });

  test('店名で探す言葉は、全角の空白を半角にそろえ、空白を詰めた言葉も足す', () {
    expect(nameQueryVariants('麺屋　武蔵'), ['麺屋 武蔵', '麺屋武蔵']);
    expect(nameQueryVariants(' 麺屋  武蔵 '), ['麺屋 武蔵', '麺屋武蔵']);
    expect(nameQueryVariants('麺屋武蔵'), ['麺屋武蔵']);
    expect(nameQueryVariants('　'), isEmpty);
  });

  test('normalizeShopName は空白を除き全角英字を半角小文字にそろえる', () {
    expect(normalizeShopName('鴨　to 葱'), '鴨to葱');
    expect(normalizeShopName('ＲＡＭＥＮ'), 'ramen');
  });

  group('NearbyShopFinder', () {
    final overpassOk = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 1,
                'lat': 35.69,
                'lon': 139.70,
                'tags': {'name': '海神'},
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final openPoiOk = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'results': [
              {'name': 'はやし田', 'lat': 35.6901, 'lng': 139.70, 'level': 8},
            ],
          }),
        ),
        200,
      ),
    );
    final failing = MockClient((_) async => http.Response('', 503));

    NearbyShopFinder finder(http.Client overpass, http.Client openPoi) =>
        NearbyShopFinder(
          overpass: OverpassClient(overpass),
          openPoi: OpenPoiClient(openPoi),
        );

    test('両方の結果をまとめる', () async {
      final shops = await finder(overpassOk, openPoiOk).searchNearby(_origin);

      expect(shops.map((s) => s.name), ['海神', 'はやし田']);
    });

    test('片方が失敗しても、もう片方の結果を返す', () async {
      expect(
        (await finder(failing, openPoiOk).searchNearby(_origin)).single.name,
        'はやし田',
      );
      expect(
        (await finder(overpassOk, failing).searchNearby(_origin)).single.name,
        '海神',
      );
    });

    test('両方失敗したときだけ失敗にする', () {
      expect(finder(failing, failing).searchNearby(_origin), throwsStateError);
    });

    test('ラーメン二郎の直系店は、通信できなくても近くにあれば出す', () async {
      // 三田本店のすぐそば。
      const mita = GeoPoint(35.6482, 139.7414);
      final shops = await finder(failing, failing).searchNearby(mita);

      expect(shops.map((s) => s.name), ['ラーメン二郎 三田本店']);
      expect(shops.single.osmId, isNull);
      expect(shops.single.address, '東京都港区三田2-16-4');
    });
  });

  test('Yahoo! の結果も合わせ、OpenStreetMap と同じ店は1つにまとめる', () async {
    final finder = NearbyShopFinder(
      overpass: OverpassClient(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'elements': [
                  {
                    'type': 'node',
                    'id': 1,
                    'lat': 35.6908,
                    'lon': 139.7006,
                    'tags': {'name': '麺処 さくら'},
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
      openPoi: OpenPoiClient(MockClient((_) async => http.Response('', 503))),
      yahoo: YahooLocalClient(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              File('test/fixtures/yahoo_local_shinjuku.json')
                  .readAsStringSync(),
            ),
            200,
          ),
        ),
        appId: 'test-id',
      ),
    );

    final shops = await finder.searchNearby(const GeoPoint(35.6905, 139.7000));

    expect(shops.map((s) => s.name), ['麺処 さくら', '麺屋ふじみち']);
    expect(shops.first.osmId, 'node/1');
  });
}
