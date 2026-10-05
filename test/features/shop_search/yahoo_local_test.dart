import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/yahoo_local.dart';
import 'package:ramen_in_cho/features/shop_search/yahoo_local_client.dart';

void main() {
  final sample = File('test/fixtures/yahoo_local_shinjuku.json')
      .readAsStringSync();

  test('保存した応答から、名前と位置のあるラーメン店を取り出す（座標は経度,緯度の順。主な業種がラーメンでない居酒屋は除く）', () {
    final shops = parseYahooLocal(sample);

    expect(shops.map((s) => s.name), ['麺処 さくら 新宿店', '麺屋ふじみち']);
    expect(shops.first.location.latitude, closeTo(35.6908, 1e-6));
    expect(shops.first.location.longitude, closeTo(139.7006, 1e-6));
    expect(shops.first.address, '東京都新宿区西新宿1-1-1');
    expect(shops.last.address, isNull);
    expect(shops.first.osmId, isNull);
    expect(shops.first.dataSource!.attributions, [yahooAttribution]);
  });

  test('見つからないとき（Featureが無い）は空', () {
    expect(parseYahooLocal('{"ResultInfo":{"Count":0}}'), isEmpty);
  });

  test('周辺検索はラーメンの業種で、km の半径（最大20km）と近い順で問い合わせる', () {
    final uri = buildYahooNearbyUri(
      const GeoPoint(35.69, 139.71),
      radiusMeters: 300,
      appId: 'test-id',
    );

    expect(uri.host, 'map.yahooapis.jp');
    expect(uri.queryParameters['gc'], '0106');
    expect(uri.queryParameters['dist'], '0.3');
    expect(uri.queryParameters['sort'], 'dist');
    expect(uri.queryParameters['lat'], '35.69');
    expect(uri.queryParameters['lon'], '139.71');
    expect(
      buildYahooNearbyUri(
        const GeoPoint(35.69, 139.71),
        radiusMeters: 50000,
        appId: 'x',
      ).queryParameters['dist'],
      '20',
    );
  });

  test('Client ID が無ければ問い合わせずに空を返す', () async {
    var requests = 0;
    final client = YahooLocalClient(
      MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      appId: '',
    );

    expect(await client.searchNearby(const GeoPoint(35.0, 139.0)), isEmpty);
    expect(await client.searchByName('豚山'), isEmpty);
    expect(requests, 0);
  });

  test('Client ID があれば問い合わせ、店名検索はラーメンの業種で絞る', () async {
    Uri? asked;
    final client = YahooLocalClient(
      MockClient((request) async {
        asked = request.url;
        return http.Response.bytes(utf8.encode(sample), 200);
      }),
      appId: 'test-id',
    );

    final shops = await client.searchByName('豚山');

    expect(shops, hasLength(2));
    expect(asked!.queryParameters['query'], '豚山');
    expect(asked!.queryParameters['gc'], '0106');
    expect(asked!.queryParameters['appid'], 'test-id');
  });

  test('失敗の知らせに Client ID を入れない', () async {
    final client = YahooLocalClient(
      MockClient((_) async => http.Response('', 403)),
      appId: 'secret-id',
    );

    await expectLater(
      client.searchNearby(const GeoPoint(35.0, 139.0)),
      throwsA(
        isA<http.ClientException>().having(
          (e) => e.toString(),
          'message',
          isNot(contains('secret-id')),
        ),
      ),
    );
  });

  test('通信の失敗でも、知らせに Client ID を入れない', () async {
    final client = YahooLocalClient(
      MockClient(
        (request) async => throw http.ClientException('offline', request.url),
      ),
      appId: 'secret-id',
    );

    await expectLater(
      client.searchByName('豚山'),
      throwsA(
        isA<http.ClientException>().having(
          (e) => e.toString(),
          'message',
          isNot(contains('secret-id')),
        ),
      ),
    );
  });
}
