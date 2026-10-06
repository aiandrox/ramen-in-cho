import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/quests/quests.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';

import '../../support/builders.dart';

bool _achieved(String id, List<VisitWithShop> entries) =>
    evaluateQuests(scoreVisits(entries))
        .firstWhere((p) => p.quest.id == id)
        .isAchieved;

Shop _shop(String id, {double? latitude}) => buildShop(
  id: id,
  latitude: latitude,
  longitude: latitude == null ? null : 139.0,
);

void main() {
  final shop = _shop('shop');

  test('朝ラーの心得は5時から10時前、丑三つの背徳は0時から4時前', () {
    expect(
      _achieved('dawn', [
        buildEntry(shop: shop, eatenAt: DateTime(2026, 1, 1, 9, 59)),
      ]),
      isTrue,
    );
    expect(
      _achieved('dawn', [
        buildEntry(shop: shop, eatenAt: DateTime(2026, 1, 1, 10)),
      ]),
      isFalse,
    );
    expect(
      _achieved('midnight', [
        buildEntry(shop: shop, eatenAt: DateTime(2026, 1, 1, 3, 59)),
      ]),
      isTrue,
    );
    expect(
      _achieved('midnight', [
        buildEntry(shop: shop, eatenAt: DateTime(2026, 1, 1, 4)),
      ]),
      isFalse,
    );
  });

  test('疾風の着丼は並んでから5分以内。並んでいない記録は数えない', () {
    expect(
      _achieved('swift', [buildEntry(shop: shop, waitMinutes: 5)]),
      isTrue,
    );
    expect(
      _achieved('swift', [buildEntry(shop: shop, waitMinutes: 6)]),
      isFalse,
    );
    expect(_achieved('swift', [buildEntry(shop: shop)]), isFalse);
  });

  test('系統はしごは同じ日に違う系統を2杯', () {
    final day = DateTime(2026, 3, 1, 12);
    expect(
      _achieved('style_ladder', [
        buildEntry(shop: shop, eatenAt: day, style: RamenStyle.shoyu),
        buildEntry(
          shop: shop,
          eatenAt: day.add(const Duration(hours: 6)),
          style: RamenStyle.miso,
        ),
      ]),
      isTrue,
    );
    expect(
      _achieved('style_ladder', [
        buildEntry(shop: shop, eatenAt: day, style: RamenStyle.shoyu),
        buildEntry(
          shop: shop,
          eatenAt: day.add(const Duration(hours: 6)),
          style: RamenStyle.shoyu,
        ),
      ]),
      isFalse,
    );
  });

  test('一途は同じ店で10杯（9杯では届かない）', () {
    List<VisitWithShop> bowls(int n) => [
      for (var i = 0; i < n; i++)
        buildEntry(shop: shop, eatenAt: DateTime(2026, 1, 1 + i)),
    ];
    expect(_achieved('devoted', bowls(9)), isFalse);
    expect(_achieved('devoted', bowls(10)), isTrue);
  });

  test('月の巡礼は同じ月に10軒、限定狩りの月は同じ月に限定3杯', () {
    expect(
      _achieved('pilgrimage', [
        for (var i = 0; i < 10; i++)
          buildEntry(shop: _shop('s$i'), eatenAt: DateTime(2026, 5, 1 + i)),
      ]),
      isTrue,
    );
    expect(
      _achieved('pilgrimage', [
        for (var i = 0; i < 10; i++)
          buildEntry(
            shop: _shop('s$i'),
            eatenAt: DateTime(2026, 5 + i % 2, 1 + i),
          ),
      ]),
      isFalse,
    );
    expect(
      _achieved('limited_month', [
        for (var i = 0; i < 3; i++)
          buildEntry(
            shop: shop,
            eatenAt: DateTime(2026, 6, 1 + i),
            isLimited: true,
          ),
      ]),
      isTrue,
    );
  });

  test('二郎の洗礼・年越しの一杯・夏の涼麺', () {
    expect(
      _achieved('jiro', [buildEntry(shop: shop, style: RamenStyle.jiro)]),
      isTrue,
    );
    expect(
      _achieved('new_year_eve', [
        buildEntry(shop: shop, eatenAt: DateTime(2026, 12, 31, 23)),
      ]),
      isTrue,
    );
    expect(
      _achieved('new_year_eve', [
        buildEntry(shop: shop, eatenAt: DateTime(2027, 1, 1, 0, 5)),
      ]),
      isFalse,
    );
    expect(
      _achieved('summer_cold', [
        buildEntry(
          shop: shop,
          eatenAt: DateTime(2026, 8, 1),
          style: RamenStyle.tsukemen,
        ),
      ]),
      isTrue,
    );
    expect(
      _achieved('summer_cold', [
        buildEntry(
          shop: shop,
          eatenAt: DateTime(2026, 9, 1),
          style: RamenStyle.tsukemen,
        ),
      ]),
      isFalse,
    );
  });

  test('遥かなる遠征は、それまでにいちばん通った店から100km以上の店で食べる', () {
    final home = _shop('home', latitude: 35.0);
    final far = _shop('far', latitude: 36.0);
    final near = _shop('near', latitude: 35.5);
    expect(
      _achieved('far_journey', [
        buildEntry(shop: home, eatenAt: DateTime(2026, 1, 1)),
        buildEntry(shop: far, eatenAt: DateTime(2026, 1, 2)),
      ]),
      isTrue,
    );
    expect(
      _achieved('far_journey', [
        buildEntry(shop: home, eatenAt: DateTime(2026, 1, 1)),
        buildEntry(shop: near, eatenAt: DateTime(2026, 1, 2)),
      ]),
      isFalse,
    );
    // 最初の1杯は比べる店が無いので数えない。
    expect(_achieved('far_journey', [buildEntry(shop: far)]), isFalse);
  });

  test('満点の舌は★5を10杯', () {
    VisitWithShop rated(int i) => VisitWithShop(
      shop: shop,
      visit: Visit(
        id: 'v$i',
        shopId: 'shop',
        result: VisitResult.eaten,
        eatenAt: DateTime(2026, 2, 1 + i),
        rating: 5,
        isLimited: false,
        memo: '',
        createdAt: DateTime(2026, 2, 1 + i),
      ),
    );
    expect(
      _achieved('perfect', [for (var i = 0; i < 9; i++) rated(i)]),
      isFalse,
    );
    expect(
      _achieved('perfect', [for (var i = 0; i < 10; i++) rated(i)]),
      isTrue,
    );
  });
}
