import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';

import '../../support/builders.dart';

PointsBreakdown _points({
  int? waitMinutes,
  bool isLimited = false,
  bool hasTicket = false,
  bool isFirstVisit = false,
  bool isRetrySuccess = false,
  Set<HoursCondition> hoursConditions = const {},
  VisitResult result = VisitResult.eaten,
}) => calculatePoints(
  visit: buildVisit(
    result: result,
    waitMinutes: waitMinutes,
    isLimited: isLimited,
    hasTicket: hasTicket,
  ),
  hoursConditions: hoursConditions,
  isFirstVisit: isFirstVisit,
  isRetrySuccess: isRetrySuccess,
);

void main() {
  group('calculatePoints', () {
    test('何もボーナスが無い記録は10点', () {
      final points = _points();

      expect(points.base, 10);
      expect(points.subtotal, 10);
      expect(points.total, 10);
    });

    test('待ち時間は10分ごとに+5。端数は切り捨てる', () {
      expect(_points(waitMinutes: 0).waitBonus, 0);
      expect(_points(waitMinutes: 9).waitBonus, 0);
      expect(_points(waitMinutes: 10).waitBonus, 5);
      expect(_points(waitMinutes: 19).waitBonus, 5);
      expect(_points(waitMinutes: 20).waitBonus, 10);
      expect(_points(waitMinutes: 59).waitBonus, 25);
      expect(_points(waitMinutes: 60).waitBonus, 30);
    });

    test('チェックインしていなければ待ち時間ボーナスは0', () {
      expect(_points().waitBonus, 0);
    });

    test('食べた時刻がチェックインより前なら待ち時間ボーナスは0', () {
      expect(_points(waitMinutes: -30).waitBonus, 0);
    });

    test('限定+20、初訪問+10、再挑戦成功+15。整理券は点にしない', () {
      expect(_points(isLimited: true).total, 30);
      expect(_points(hasTicket: true).total, 10);
      expect(_points(isFirstVisit: true).total, 20);
      expect(_points(isRetrySuccess: true).total, 25);
    });

    test('すべてのボーナスを合計する', () {
      final points = _points(
        waitMinutes: 45,
        isLimited: true,
        isFirstVisit: true,
        isRetrySuccess: true,
      );

      // 10 + 20 + 20 + 10 + 15
      expect(points.subtotal, 75);
      expect(points.total, 75);
    });

    test('攻略しにくさの倍率は、条件ごとの上乗せを足して合計にかける', () {
      PointsBreakdown withConditions(Set<HoursCondition> conditions) =>
          calculatePoints(
            visit: buildVisit(isLimited: true),
            hoursConditions: conditions,
            isFirstVisit: false,
            isRetrySuccess: false,
          );

      // 10 + 20 = 30
      expect(withConditions(const {}).total, 30);
      expect(withConditions({HoursCondition.lunchOnly}).total, 39);
      expect(withConditions({HoursCondition.nightOnly}).total, 36);
      expect(withConditions({HoursCondition.weekdaysOnly}).total, 45);
      expect(withConditions({HoursCondition.weekendsOnly}).total, 36);
      expect(withConditions({HoursCondition.fewDays}).total, 45);
      expect(withConditions({HoursCondition.irregular}).total, 45);
      expect(withConditions({HoursCondition.badAccess}).total, 45);
      // ×(1 + 0.5 + 0.5) = ×2
      expect(
        withConditions({HoursCondition.weekdaysOnly, HoursCondition.badAccess})
            .total,
        60,
      );
    });

    test('倍率は×2.5で止まる', () {
      expect(
        hoursMultiplier({
          HoursCondition.fewDays,
          HoursCondition.irregular,
          HoursCondition.badAccess,
        }),
        2.5,
      );
      expect(hoursMultiplier(HoursCondition.values.toSet()), 2.5);
      // 1 + 0.3 + 0.5 + 0.5 = 2.3
      expect(
        hoursMultiplier({
          HoursCondition.lunchOnly,
          HoursCondition.fewDays,
          HoursCondition.badAccess,
        }),
        2.3,
      );
    });

    test('すべての条件に倍率の上乗せがある', () {
      for (final condition in HoursCondition.values) {
        expect(hoursConditionWeights[condition], greaterThan(0));
      }
    });

    test('倍率をかけたあとの小数は切り捨てる', () {
      // (10 + 5) × 1.3 = 19.5
      expect(
        _points(
          waitMinutes: 10,
          hoursConditions: {HoursCondition.lunchOnly},
        ).total,
        19,
      );
      // (10 + 15) × 1.5 = 37.5
      expect(
        _points(
          isRetrySuccess: true,
          hoursConditions: {HoursCondition.irregular},
        ).total,
        37,
      );
    });

    test('朝ラー（5〜9時台）と深夜（0〜4時台）は+10。自動でつく', () {
      PointsBreakdown at(int hour, int minute) => calculatePoints(
        visit: buildVisit(eatenAt: DateTime(2026, 9, 30, hour, minute)),
        hoursConditions: const {},
        isFirstVisit: false,
        isRetrySuccess: false,
      );

      expect(at(0, 0).lateNightBonus, 10);
      expect(at(4, 59).lateNightBonus, 10);
      expect(at(4, 59).earlyBonus, 0);
      expect(at(5, 0).earlyBonus, 10);
      expect(at(5, 0).lateNightBonus, 0);
      expect(at(9, 59).earlyBonus, 10);
      expect(at(10, 0).earlyBonus, 0);
      expect(at(23, 59).lateNightBonus, 0);
      expect(at(9, 59).total, 20);
    });

    test('遠征は+20。倍率もかかる', () {
      final points = calculatePoints(
        visit: buildVisit(),
        hoursConditions: const {HoursCondition.lunchOnly},
        isFirstVisit: false,
        isRetrySuccess: false,
        isExpedition: true,
      );

      expect(points.expeditionBonus, 20);
      // (10 + 20) × 1.3 = 39
      expect(points.total, 39);
    });

    test('撤退の記録は0点', () {
      final points = _points(
        result: VisitResult.retreated,
        waitMinutes: 60,
        isLimited: true,
        hasTicket: true,
        hoursConditions: {HoursCondition.weekdaysOnly, HoursCondition.fewDays},
      );

      expect(points.total, 0);
      expect(points.subtotal, 0);
    });
  });

  group('scoreVisits', () {
    final shopA = buildShop(id: 'a');
    final shopB = buildShop(id: 'b');
    DateTime day(int d) => DateTime(2026, 9, d, 12);

    test('店ごとに最初の「食べた」記録だけが初訪問になる', () {
      final scored = scoreVisits([
        buildEntry(shop: shopA, eatenAt: day(1)),
        buildEntry(shop: shopB, eatenAt: day(2)),
        buildEntry(shop: shopA, eatenAt: day(3)),
      ]);

      expect(scored.map((s) => s.isFirstVisit), [true, true, false]);
      expect(scored.map((s) => s.points.total), [20, 20, 10]);
    });

    test('渡した順番に関係なく、食べた時刻の古い順に採点する', () {
      final scored = scoreVisits([
        buildEntry(shop: shopA, eatenAt: day(3)),
        buildEntry(shop: shopA, eatenAt: day(1)),
      ]);

      expect(scored.map((s) => s.visit.eatenAt), [day(1), day(3)]);
      expect(scored.map((s) => s.isFirstVisit), [true, false]);
    });

    test('撤退の次に同じ店で食べると再挑戦成功。初訪問と両方つく', () {
      final scored = scoreVisits([
        buildEntry(shop: shopA, eatenAt: day(1), result: VisitResult.retreated),
        buildEntry(shop: shopA, eatenAt: day(2)),
        buildEntry(shop: shopA, eatenAt: day(3)),
      ]);

      expect(scored.map((s) => s.isRetrySuccess), [false, true, false]);
      expect(scored.map((s) => s.isFirstVisit), [false, true, false]);
      // 撤退 0 / 10 + 10 + 15 / 10
      expect(scored.map((s) => s.points.total), [0, 35, 10]);
    });

    test('撤退のあとに別の店で食べても再挑戦成功にならない', () {
      final scored = scoreVisits([
        buildEntry(shop: shopA, eatenAt: day(1), result: VisitResult.retreated),
        buildEntry(shop: shopB, eatenAt: day(2)),
        buildEntry(shop: shopA, eatenAt: day(3)),
      ]);

      expect(scored.map((s) => s.isRetrySuccess), [false, false, true]);
    });

    test('撤退が続いたあとに食べても再挑戦成功は1回だけ', () {
      final scored = scoreVisits([
        buildEntry(shop: shopA, eatenAt: day(1), result: VisitResult.retreated),
        buildEntry(shop: shopA, eatenAt: day(2), result: VisitResult.retreated),
        buildEntry(shop: shopA, eatenAt: day(3)),
        buildEntry(shop: shopA, eatenAt: day(4)),
      ]);

      expect(scored.map((s) => s.isRetrySuccess), [false, false, true, false]);
    });

    test('店の営業時間の倍率を使い、累計ポイントを合計する', () {
      final rare = buildShop(
        id: 'rare',
        hoursConditions: {HoursCondition.weekdaysOnly, HoursCondition.fewDays},
      );
      final scored = scoreVisits([
        buildEntry(shop: rare, eatenAt: day(1), waitMinutes: 30),
        buildEntry(shop: shopA, eatenAt: day(2)),
      ]);

      // (10 + 15 + 10) × 2 = 70、10 + 10 = 20
      expect(scored.map((s) => s.points.total), [70, 20]);
      expect(totalPoints(scored), 90);
    });

    group('遠征（利用者が決めた拠点から80km以上）', () {
      // 緯度0.72度は約80.1km、0.71度は約79.0km。
      final home = buildShop(id: 'home', latitude: 35.0, longitude: 139.0);
      final far = buildShop(id: 'far', latitude: 35.72, longitude: 139.0);
      final notFar = buildShop(id: 'notFar', latitude: 35.71, longitude: 139.0);
      final setAt = DateTime(2026, 1, 3, 12);
      final base = buildHomeBase(setAt: setAt);

      int bonusAt(
        DateTime eatenAt, {
        Shop? shop,
        List<HomeBaseSetting>? homeBases,
      }) => scoreVisits([
        buildEntry(shop: shop ?? far, eatenAt: eatenAt),
      ], homeBases: homeBases ?? [base]).single.points.expeditionBonus;

      test('拠点を決めていなければ、遠くの店でも遠征にならない', () {
        final scored = scoreVisits([
          for (var d = 1; d <= 6; d++) buildEntry(shop: home, eatenAt: day(d)),
          buildEntry(shop: far, eatenAt: day(7)),
        ]);

        expect(scored.every((s) => s.points.expeditionBonus == 0), isTrue);
        expect(scored.every((s) => s.homeBase == null), isTrue);
      });

      test('拠点を決めた日時ちょうどの1杯から遠征になり、その前の1杯はならない', () {
        expect(bonusAt(setAt.subtract(const Duration(minutes: 1))), 0);
        expect(bonusAt(setAt), 20);
        expect(bonusAt(setAt.add(const Duration(days: 1))), 20);
      });

      test('80km未満は遠征にならない', () {
        expect(bonusAt(day(10), shop: notFar), 0);
      });

      test('拠点を変えると、変えた日から後の1杯だけが新しい拠点で決まる', () {
        final moved = buildHomeBase(
          latitude: 35.72,
          setAt: DateTime(2026, 2, 1),
        );
        final bases = [base, moved];

        expect(bonusAt(DateTime(2026, 1, 31, 23), homeBases: bases), 20);
        expect(bonusAt(DateTime(2026, 2, 1), homeBases: bases), 0);
        expect(bonusAt(DateTime(2026, 2, 2), shop: home, homeBases: bases), 20);
      });

      test('遠征の点にも攻略しにくさの倍率がかかる', () {
        final rareFar = buildShop(
          id: 'rareFar',
          latitude: 35.72,
          longitude: 139.0,
          hoursConditions: {HoursCondition.fewDays},
        );
        final scored = scoreVisits(
          [buildEntry(shop: rareFar, eatenAt: day(10))],
          homeBases: [base],
        ).single;

        // (10 + 初訪問10 + 遠征20) × 1.5 = 60
        expect(scored.points.total, 60);
        expect(scored.isExpedition, isTrue);
      });
    });

    test('記録が無ければ累計は0', () {
      expect(totalPoints(scoreVisits(const [])), 0);
    });
  });
}
