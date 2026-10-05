import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/shop_search/builtin_shops.dart';
import 'package:ramen_in_cho/features/shop_search/found_shop.dart';
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
          (
            shop['name'],
            shop['address'],
            shop['latitude'],
            shop['longitude'],
            (shop['hoursConditions'] as List).join(','),
          ),
    ];
    expect([
      for (final shop in builtinShops)
        (
          shop.name,
          shop.address,
          shop.location.latitude,
          shop.location.longitude,
          shop.hoursConditions.map((c) => c.name).join(','),
        ),
    ], open);
  });

  test('正本の店の条件は知っている条件だけで、昼のみと夜のみを同時に持たず、出どころと調べた日がある', () {
    final file = jsonDecode(
      File('data/curated_shops.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final names = HoursCondition.values.map((c) => c.name).toSet();
    for (final shop in (file['shops'] as List).cast<Map<String, dynamic>>()) {
      final conditions = (shop['hoursConditions'] as List).cast<String>();
      expect(names, containsAll(conditions), reason: shop['name'] as String);
      expect(
        conditions.contains('lunchOnly') && conditions.contains('nightOnly'),
        isFalse,
        reason: shop['name'] as String,
      );
      if (shop['conditionsVerified'] != true) {
        expect(conditions, isEmpty, reason: shop['name'] as String);
      }
      final source = shop['conditionsSource'] as Map<String, dynamic>;
      expect(source['url'], startsWith('https://'));
      expect(DateTime.tryParse(source['checkedAt'] as String), isNotNull);
    }
  });

  test('サーバーの1件から店の条件を読み、知らない条件は読み飛ばす。条件の無い古い形でも読める', () {
    final shop = BuiltinShop.fromJson({
      'name': 'ラーメン二郎 仙川店',
      'address': '東京都調布市仙川町1-10-17',
      'latitude': 35.661385,
      'longitude': 139.583847,
      'status': 'open',
      'hoursConditions': ['nightOnly', 'someday', 3],
    })!;
    expect(shop.hoursConditions, {HoursCondition.nightOnly});
    expect(BuiltinShop.fromJson(shop.toJson())!.hoursConditions, {
      HoursCondition.nightOnly,
    });
    final old = BuiltinShop.fromJson({
      'name': 'ラーメン二郎 三田本店',
      'address': '東京都港区三田2-16-4',
      'latitude': 35.648045,
      'longitude': 139.741516,
      'status': 'open',
    })!;
    expect(old.hoursConditions, isEmpty);
    expect(old.toFoundShop().suggestedConditions, isNull);
  });

  test('手で持つ店の条件は、地図の営業時間からの推し量りより優先する', () {
    const shop = BuiltinShop(
      name: 'ラーメン二郎 仙川店',
      address: '東京都調布市仙川町1-10-17',
      location: GeoPoint(35.661385, 139.583847),
      hoursConditions: {HoursCondition.nightOnly},
    );
    final found = shop.toFoundShop();
    expect(found.suggestedConditions, {HoursCondition.nightOnly});
    expect(found.suggestedConditionsSource, ConditionsDraftSource.curatedShops);

    const osm = FoundShop(
      osmId: 'node/1',
      name: 'ラーメン二郎',
      location: GeoPoint(35.6614, 139.5839),
      openingHours: 'Mo-Sa 11:00-14:00',
    );
    expect(osm.suggestedConditionsSource, ConditionsDraftSource.openingHours);
    final [merged, other] = withCuratedConditions(
      [
        osm,
        const FoundShop(name: 'ほかの店', location: GeoPoint(35.6614, 139.5839)),
      ],
      [shop],
    );
    expect(merged.osmId, 'node/1');
    expect(merged.suggestedConditions, {HoursCondition.nightOnly});
    expect(
      merged.suggestedConditionsSource,
      ConditionsDraftSource.curatedShops,
    );
    expect(other.suggestedConditions, isNull);
  });
}
