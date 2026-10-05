import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/shop_candidate.dart';

const _here = GeoPoint(35.0, 139.0);

/// 緯度0.001度は約111m。
FoundShop _found(String name, double northDegrees, {String? osmId}) =>
    FoundShop(
      osmId: osmId ?? 'node/$name',
      name: name,
      location: GeoPoint(35.0 + northDegrees, 139.0),
    );

Shop _known(
  String name, {
  double? northDegrees,
  String? osmId,
  Set<HoursCondition> hoursConditions = const {},
}) => Shop(
  id: 'shop-$name',
  name: name,
  latitude: northDegrees == null ? null : 35.0 + northDegrees,
  longitude: northDegrees == null ? null : 139.0,
  osmId: osmId,
  hoursConditions: hoursConditions,
  createdAt: DateTime(2026),
);

void main() {
  test('distanceMetersは緯度0.001度を約111mと計算する', () {
    expect(
      distanceMeters(_here, const GeoPoint(35.001, 139.0)),
      closeTo(111.2, 0.5),
    );
    expect(distanceMeters(_here, _here), 0);
  });

  group('rankShopCandidates', () {
    test('近い順に最大3件を返す', () {
      final candidates = rankShopCandidates(
        here: _here,
        found: [
          _found('遠い', 0.0025),
          _found('近い', 0.0005),
          _found('中くらい', 0.001),
          _found('やや遠い', 0.002),
        ],
        knownShops: const [],
      );

      expect(candidates.map((c) => c.name), ['近い', '中くらい', 'やや遠い']);
      expect(candidates.first.distanceMeters, closeTo(55.6, 0.5));
    });

    test('半径300mより遠い店は含めない', () {
      final candidates = rankShopCandidates(
        here: _here,
        found: [_found('圏内', 0.0026), _found('圏外', 0.0028)],
        knownShops: const [],
      );

      expect(candidates.map((c) => c.name), ['圏内']);
    });

    test('記録済みの店は、通信できず検索結果が空でも候補になる', () {
      final candidates = rankShopCandidates(
        here: _here,
        found: const [],
        knownShops: [
          _known(
            '手入力の店',
            northDegrees: 0.001,
            hoursConditions: {
              HoursCondition.weekdaysOnly,
              HoursCondition.fewDays,
            },
          ),
          _known('位置のない店'),
          _known('遠くの店', northDegrees: 0.01),
        ],
      );

      expect(candidates.map((c) => c.name), ['手入力の店']);
      expect(candidates.single.shopId, 'shop-手入力の店');
      expect(candidates.single.hoursConditions, {
        HoursCondition.weekdaysOnly,
        HoursCondition.fewDays,
      });
    });

    test('OpenPOIで選んだ店と表記の少し違うOSMの店は、記録済みの方だけを出す', () {
      final candidates = rankShopCandidates(
        here: _here,
        found: [
          _found('壱角家 西新宿店', 0.0005, osmId: 'node/1'),
          _found('らぁ麺 はやし田', 0.001, osmId: 'node/2'),
        ],
        knownShops: [
          _known('壱角家', northDegrees: 0.0004),
          _known('らぁ麺　はやし田', northDegrees: 0.001),
        ],
      );

      expect(candidates.map((c) => c.shopId), ['shop-壱角家', 'shop-らぁ麺　はやし田']);
    });

    test('地図の営業時間から推し量った条件を、初めての店の下書きにする。願の条件があれば願を優先する', () {
      final candidates = rankShopCandidates(
        here: _here,
        found: [
          const FoundShop(
            osmId: 'node/lunch',
            name: '昼の店',
            location: GeoPoint(35.0001, 139.0),
            openingHours: 'Mo-Fr 11:00-15:00',
          ),
          const FoundShop(
            osmId: 'node/wish',
            name: '願の店',
            location: GeoPoint(35.0002, 139.0),
            openingHours: 'Mo-Fr 11:00-15:00',
          ),
          const FoundShop(
            osmId: 'node/normal',
            name: 'ふつうの店',
            location: GeoPoint(35.0003, 139.0),
            openingHours: 'Mo-Su 11:00-22:00',
          ),
        ],
        knownShops: const [],
        wishes: [
          Wish(
            id: 'w',
            osmId: 'node/wish',
            name: '願の店',
            createdAt: DateTime(2026),
            hoursConditions: const {HoursCondition.irregular},
          ),
        ],
      );
      ShopCandidate named(String name) =>
          candidates.firstWhere((c) => c.name == name);

      expect(named('昼の店').hoursConditions, {
        HoursCondition.lunchOnly,
        HoursCondition.weekdaysOnly,
      });
      expect(
        named('昼の店').conditionsDraftSource,
        ConditionsDraftSource.openingHours,
      );
      expect(named('願の店').hoursConditions, {HoursCondition.irregular});
      expect(named('願の店').conditionsDraftSource, isNull);
      expect(named('ふつうの店').hoursConditions, isNull);
      expect(named('ふつうの店').conditionsDraftSource, isNull);
    });

    test('まだの願の店は「願」を付けて先頭に出し、候補に無ければ願の店を足す', () {
      final candidates = rankShopCandidates(
        here: _here,
        found: [
          _found('近い店', 0.0001),
          _found('願の店', 0.002, osmId: 'node/wish'),
        ],
        knownShops: const [],
        wishes: [
          Wish(
            id: 'w1',
            osmId: 'node/wish',
            name: '願の店',
            latitude: 35.002,
            longitude: 139.0,
            createdAt: DateTime(2026),
          ),
          Wish(
            id: 'w2',
            name: '検索に無い店',
            latitude: 35.0015,
            longitude: 139.0,
            createdAt: DateTime(2026),
          ),
          Wish(
            id: 'far',
            name: '遠い店',
            latitude: 35.1,
            longitude: 139.0,
            createdAt: DateTime(2026),
          ),
        ],
      );

      expect(candidates.map((c) => c.name), ['検索に無い店', '願の店', '近い店']);
      expect(candidates.map((c) => c.wishId), ['w2', 'w1', null]);
    });

    test('同じ店が検索結果と記録済みの両方にあるときは記録済みの方を残す', () {
      final candidates = rankShopCandidates(
        here: _here,
        found: [
          _found('OSMの店', 0.001, osmId: 'node/1'),
          _found('手入力の店', 0.002),
          _found('初めての店', 0.0015),
        ],
        knownShops: [
          _known('OSMの店', northDegrees: 0.001, osmId: 'node/1'),
          _known('手入力の店', northDegrees: 0.002),
        ],
      );

      expect(candidates.map((c) => c.name), ['OSMの店', '初めての店', '手入力の店']);
      expect(candidates.map((c) => c.shopId), [
        'shop-OSMの店',
        null,
        'shop-手入力の店',
      ]);
    });
  });

  group('isSameShop', () {
    const here = GeoPoint(35.0, 139.0);
    const far = GeoPoint(35.01, 139.0);

    test('記録済みの店どうしはIDで比べる', () {
      expect(
        isSameShop(
          const ShopCandidate(shopId: 'a', name: '麺屋'),
          const ShopCandidate(shopId: 'a', name: '別の名前'),
        ),
        isTrue,
      );
      expect(
        isSameShop(
          const ShopCandidate(shopId: 'a', name: '麺屋'),
          const ShopCandidate(shopId: 'b', name: '麺屋'),
        ),
        isFalse,
      );
    });

    test('OSMの店どうしはOSMのIDで比べる', () {
      expect(
        isSameShop(
          const ShopCandidate(osmId: 'node/1', name: '一風堂'),
          const ShopCandidate(osmId: 'node/1', name: '一風堂'),
        ),
        isTrue,
      );
      expect(
        isSameShop(
          const ShopCandidate(osmId: 'node/1', name: '一風堂'),
          const ShopCandidate(osmId: 'node/2', name: '一風堂'),
        ),
        isFalse,
      );
    });

    test('IDで比べられないときは、同じ名前で近ければ同じ店', () {
      const manual = ShopCandidate(name: '麺屋', location: here);

      expect(
        isSameShop(
          manual,
          const ShopCandidate(osmId: 'node/1', name: '麺屋', location: here),
        ),
        isTrue,
      );
      expect(
        isSameShop(
          manual,
          const ShopCandidate(osmId: 'node/1', name: '麺屋', location: far),
        ),
        isFalse,
      );
      expect(isSameShop(manual, const ShopCandidate(name: '麺屋')), isTrue);
      expect(
        isSameShop(manual, const ShopCandidate(name: '別の店', location: here)),
        isFalse,
      );
    });
  });
}
