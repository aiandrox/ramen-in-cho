import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';

void main() {
  group('parseOverpassResponse', () {
    final sample = File('test/fixtures/overpass_shinjuku.json')
        .readAsStringSync();

    test('保存した応答から名前と位置のある店だけを取り出す', () {
      final shops = parseOverpassResponse(sample);

      // 20件のうち1件は名前が無い。
      expect(shops, hasLength(19));
      final kaijin = shops.firstWhere((s) => s.osmId == 'node/1504865588');
      expect(kaijin.name, '海神');
      expect(kaijin.location.latitude, closeTo(35.6898044, 1e-7));
    });

    test('建物として登録された店は中心の位置を使う', () {
      final shops = parseOverpassResponse(sample);

      final kamo = shops.firstWhere((s) => s.osmId == 'relation/17691793');
      expect(kamo.name, 'らーめん鴨to葱');
      expect(kamo.location.latitude, closeTo(35.6908671, 1e-7));
      expect(kamo.location.longitude, closeTo(139.7003807, 1e-7));
    });

    test('nameが無ければname:jaを使い、同じ要素の重複は1件にする', () {
      const body = '''
{"elements": [
  {"type": "node", "id": 1, "lat": 35.0, "lon": 139.0,
   "tags": {"name:ja": "麺屋テスト", "cuisine": "ramen"}},
  {"type": "node", "id": 1, "lat": 35.0, "lon": 139.0,
   "tags": {"name:ja": "麺屋テスト", "cuisine": "ramen"}},
  {"type": "way", "id": 2, "tags": {"name": "位置なし"}},
  {"type": "node", "id": 3, "lat": 35.0, "lon": 139.0, "tags": {"name": " "}},
  {"type": "node", "id": 4, "lat": 35.0, "lon": 139.0}
]}''';

      final shops = parseOverpassResponse(body);

      expect(shops.map((s) => s.name), ['麺屋テスト']);
      expect(shops.single.osmId, 'node/1');
    });

    test('サーバー側で時間切れになった応答は、0件ではなく失敗にする', () {
      expect(
        () => parseOverpassResponse(
          '{"elements": [], "remark": "runtime error: Query timed out in \\"query\\" at line 1 after 26 seconds."}',
        ),
        throwsFormatException,
      );
    });

    test('候補が0件の応答は空のリストになる', () {
      expect(parseOverpassResponse('{"elements": []}'), isEmpty);
    });

    test('JSONでない応答やelementsの無い応答は例外にする', () {
      expect(
        () => parseOverpassResponse('<html>rate limited</html>'),
        throwsFormatException,
      );
      expect(
        () => parseOverpassResponse('{"remark": "timeout"}'),
        throwsFormatException,
      );
      expect(() => parseOverpassResponse('[]'), throwsFormatException);
    });
  });

  test('buildOverpassQueryは半径300mとラーメン店の条件を含む', () {
    final query = buildOverpassQuery(const GeoPoint(35.6909, 139.7003));

    expect(query, startsWith('[out:json][timeout:10];'));
    expect(
      buildOverpassQuery(const GeoPoint(35.0, 139.0), radiusMeters: 1000),
      contains('(around:1000,35.0,139.0)'),
    );
    expect(
      query,
      contains('nwr["cuisine"~"ramen"](around:300,35.6909,139.7003);'),
    );
    expect(
      query,
      contains(
        'nwr["amenity"~"^(restaurant|fast_food)\$"]'
        '["name"~"ラーメン|らーめん|拉麺|中華そば|麺|つけ麺"](around:300,35.6909,139.7003);',
      ),
    );
    expect(query, endsWith('out center tags;'));
  });
}
