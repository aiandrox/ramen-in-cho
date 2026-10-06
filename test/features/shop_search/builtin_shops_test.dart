import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/shop_search/builtin_shops.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';

void main() {
  test('アプリに持たせている店は名前が重ならず、位置は日本の中にある', () {
    expect(
      builtinShops.map((s) => s.name).toSet(),
      hasLength(builtinShops.length),
    );
    for (final shop in builtinShops) {
      expect(shop.name, startsWith('ラーメン二郎 '));
      expect(
        shop.location.latitude,
        inInclusiveRange(24, 46),
        reason: shop.name,
      );
      expect(
        shop.location.longitude,
        inInclusiveRange(122, 154),
        reason: shop.name,
      );
    }
  });

  test('近くの店だけを返す', () {
    const mita = GeoPoint(35.6482, 139.7414);

    expect(builtinShopsNear(mita, 300).map((s) => s.name), ['ラーメン二郎 三田本店']);
    expect(builtinShopsNear(const GeoPoint(35.0, 139.0), 1000), isEmpty);
  });

  test('名前で探すと、空白や全角半角を区別せず、近い順に5件まで返す', () {
    expect(builtinShopsNamed('二郎三田').map((s) => s.name), ['ラーメン二郎 三田本店']);
    final near = builtinShopsNamed(
      'ラーメン二郎',
      near: const GeoPoint(35.4422, 139.6309),
    );
    expect(near, hasLength(5));
    expect(near.first.name, 'ラーメン二郎 横浜関内店');
    expect(builtinShopsNamed('  '), isEmpty);
  });

  test('「二郎 関内」「二郎　関内」「二郎関内」のどれでも横浜関内店が見つかる', () {
    for (final query in ['二郎 関内', '二郎　関内', '二郎関内', 'ラーメン二郎 関内店']) {
      expect(
        builtinShopsNamed(query).map((s) => s.name),
        contains('ラーメン二郎 横浜関内店'),
        reason: query,
      );
    }
    expect(builtinShopsNamed('関内二郎'), isEmpty);
  });

  test('アプリに同梱した店は、正本（data/curated_shops.json）の営業中の店と同じ', () {
    final file = jsonDecode(
      File('data/curated_shops.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final open = [
      for (final shop in file['shops'] as List)
        if ((shop as Map)['status'] == 'open')
          (shop['name'], shop['address'], shop['latitude'], shop['longitude']),
    ];
    expect([
      for (final shop in builtinShops)
        (
          shop.name,
          shop.address,
          shop.location.latitude,
          shop.location.longitude,
        ),
    ], open);
  });
}
