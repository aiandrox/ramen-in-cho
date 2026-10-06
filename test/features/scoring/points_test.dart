import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';

import '../../support/builders.dart';

PointsBreakdown _points({
  int? waitMinutes,
  bool isLimited = false,
  bool hasTicket = false,
  bool isFirstVisit = false,
  bool isRetrySuccess = false,
  bool isFamous = false,
  VisitResult result = VisitResult.eaten,
}) => calculatePoints(
  visit: buildVisit(
    result: result,
    waitMinutes: waitMinutes,
    isLimited: isLimited,
    hasTicket: hasTicket,
  ),
  isFirstVisit: isFirstVisit,
  isRetrySuccess: isRetrySuccess,
  isFamous: isFamous,
);

void main() {
  group('calculatePoints', () {
    test('何もボーナスが無い記録は10点', () {
      final points = _points();

      expect(points.base, 10);
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

    test('限定+20、初訪問+5、再挑戦成功+15、名店+15。整理券は点にしない', () {
      expect(_points(isLimited: true).total, 30);
      expect(_points(hasTicket: true).total, 10);
      expect(_points(isFirstVisit: true).total, 15);
      expect(_points(isRetrySuccess: true).total, 25);
      expect(_points(isFamous: true).famousBonus, 15);
      expect(_points(isFamous: true).total, 25);
    });

    test('すべてのボーナスを足し合わせる（倍率はかけない）', () {
      final points = calculatePoints(
        visit: buildVisit(
          eatenAt: DateTime(2026, 9, 30, 7),
          waitMinutes: 45,
          isLimited: true,
        ),
        isFirstVisit: true,
        isRetrySuccess: true,
        homeBaseMeters: 300000,
        isNewPrefecture: true,
        isNewArea: true,
        countAtShop: 10,
        streakWeeksBefore: 3,
        isFamous: true,
      );

      // 10 + 待ち20 + 限定20 + 初訪問5 + 再挑戦15 + 遠征25 + 朝ラー10
      // + 都道府県10（市区町村は重ねない） + 常連20 + 連続6 + 名店15
      expect(points.newAreaBonus, 0);
      expect(points.total, 156);
    });

    test('朝ラー（5〜9時台）と深夜（0〜4時台）は+10。自動でつく', () {
      PointsBreakdown at(int hour, int minute) => calculatePoints(
        visit: buildVisit(eatenAt: DateTime(2026, 9, 30, hour, minute)),
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

    test('撤退の記録は0点', () {
      final points = calculatePoints(
        visit: buildVisit(
          result: VisitResult.retreated,
          waitMinutes: 60,
          isLimited: true,
        ),
        isFirstVisit: true,
        isRetrySuccess: true,
        homeBaseMeters: 900000,
        isNewPrefecture: true,
        isNewArea: true,
        countAtShop: 10,
        streakWeeksBefore: 5,
        isFamous: true,
      );

      expect(points.total, 0);
    });
  });

  group('利用者の感覚に合わせた点と格', () {
    // 昼どき（朝ラー・深夜がつかない時刻）の1杯。
    final noon = DateTime(2026, 9, 30, 12);
    PointsBreakdown bowl({
      int? waitMinutes,
      bool isFirstVisit = false,
      bool isNewPrefecture = false,
      double? homeBaseMeters,
    }) => calculatePoints(
      visit: buildVisit(eatenAt: noon, waitMinutes: waitMinutes),
      isFirstVisit: isFirstVisit,
      isRetrySuccess: false,
      isNewPrefecture: isNewPrefecture,
      homeBaseMeters: homeBaseMeters,
    );

    for (final (name, points, total, rank) in [
      ('地元の再訪・着丼まで30分', bowl(waitMinutes: 30), 25, ShopRank.b),
      ('地元の再訪・着丼まで60分', bowl(waitMinutes: 60), 40, ShopRank.a),
      ('地元の再訪・着丼まで90分', bowl(waitMinutes: 90), 55, ShopRank.s),
      (
        '遠征80km・初めての都道府県・初めての店・待ちなし',
        bowl(isFirstVisit: true, isNewPrefecture: true, homeBaseMeters: 80000),
        45,
        ShopRank.a,
      ),
      (
        '遠征80km・初めての都道府県・初めての店・着丼まで30分',
        bowl(
          waitMinutes: 30,
          isFirstVisit: true,
          isNewPrefecture: true,
          homeBaseMeters: 80000,
        ),
        60,
        ShopRank.s,
      ),
      ('遠征先の再訪・待ちなし', bowl(homeBaseMeters: 80000), 30, ShopRank.b),
    ]) {
      test('$name は $total 点', () {
        expect(points.total, total);
        expect(shopRankFor(points.total), rank);
      });
    }

    test('格の境は 秀25・妙40・極55', () {
      expect(shopRankFor(24), ShopRank.c);
      expect(shopRankFor(25), ShopRank.b);
      expect(shopRankFor(39), ShopRank.b);
      expect(shopRankFor(40), ShopRank.a);
      expect(shopRankFor(54), ShopRank.a);
      expect(shopRankFor(55), ShopRank.s);
    });
  });

  group('遠征の段階', () {
    test('80km・300km・800kmの境で+20・+25・+30に上がり、足さない', () {
      expect(expeditionBonusFor(null), 0);
      expect(expeditionBonusFor(0), 0);
      expect(expeditionBonusFor(79999.9), 0);
      expect(expeditionBonusFor(80000), 20);
      expect(expeditionBonusFor(299999.9), 20);
      expect(expeditionBonusFor(300000), 25);
      expect(expeditionBonusFor(799999.9), 25);
      expect(expeditionBonusFor(800000), 30);
      expect(expeditionBonusFor(2000000), 30);
    });
  });

  group('常連', () {
    test('その店で5杯目に+10、10杯目からは10杯ごとに+20', () {
      expect(regularBonusFor(1), 0);
      expect(regularBonusFor(4), 0);
      expect(regularBonusFor(5), 10);
      expect(regularBonusFor(6), 0);
      expect(regularBonusFor(9), 0);
      expect(regularBonusFor(10), 20);
      expect(regularBonusFor(15), 0);
      expect(regularBonusFor(20), 20);
      expect(regularBonusFor(30), 20);
      expect(regularBonusFor(31), 0);
    });
  });

  group('連続記録', () {
    test('続いている週1つにつき+2、+10で止まる', () {
      expect(streakBonusFor(0), 0);
      expect(streakBonusFor(1), 2);
      expect(streakBonusFor(4), 8);
      expect(streakBonusFor(5), 10);
      expect(streakBonusFor(6), 10);
      expect(streakBonusFor(52), 10);
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
      expect(scored.map((s) => s.points.total), [15, 15, 10]);
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
      // 撤退 0 / 10 + 5 + 15 / 10
      expect(scored.map((s) => s.points.total), [0, 30, 10]);
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

    test('名店の印の店では食べるたびに+15。撤退にはつかない', () {
      final famous = buildShop(id: 'famous', isFamous: true);
      final scored = scoreVisits([
        buildEntry(shop: famous, eatenAt: day(1), waitMinutes: 30),
        buildEntry(shop: famous, eatenAt: day(2)),
        buildEntry(
          shop: famous,
          eatenAt: day(3),
          result: VisitResult.retreated,
        ),
        buildEntry(shop: shopA, eatenAt: day(4)),
      ]);

      // 10 + 15 + 5 + 15 = 45、10 + 15 = 25、撤退 0、10 + 5 = 15
      expect(scored.map((s) => s.points.famousBonus), [15, 15, 0, 0]);
      expect(scored.map((s) => s.points.total), [45, 25, 0, 15]);
      expect(totalPoints(scored), 85);
    });

    group('常連（その店で何杯目か）', () {
      test('食べた記録だけを数え、5杯目・10杯目・20杯目に上乗せする', () {
        final scored = scoreVisits([
          for (var d = 1; d <= 20; d++) ...[
            buildEntry(shop: shopA, eatenAt: day(d)),
            if (d == 3)
              buildEntry(
                shop: shopA,
                eatenAt: day(d).add(const Duration(hours: 1)),
                result: VisitResult.retreated,
              ),
          ],
        ]).where((s) => s.visit.result == VisitResult.eaten).toList();

        expect(scored.map((s) => s.countAtShop), [
          for (var n = 1; n <= 20; n++) n,
        ]);
        expect(scored[3].points.regularBonus, 0);
        expect(scored[4].points.regularBonus, 10);
        expect(scored[8].points.regularBonus, 0);
        expect(scored[9].points.regularBonus, 20);
        expect(scored[14].points.regularBonus, 0);
        expect(scored[19].points.regularBonus, 20);
      });

      test('ほかの店の杯数とは混ぜない', () {
        final scored = scoreVisits([
          for (var d = 1; d <= 4; d++) buildEntry(shop: shopA, eatenAt: day(d)),
          buildEntry(shop: shopB, eatenAt: day(5)),
        ]);

        expect(scored.last.countAtShop, 1);
        expect(scored.last.points.regularBonus, 0);
      });
    });

    group('連続記録（月曜はじまりの週）', () {
      // 2026年9月7日は月曜日。
      DateTime week(int w, {int day = 0}) =>
          DateTime(2026, 9, 7 + 7 * w + day, 12);

      test('その週の最初の1杯だけに、前から続いている週の数×2をつける', () {
        final scored = scoreVisits([
          buildEntry(shop: shopA, eatenAt: week(0)),
          buildEntry(shop: shopA, eatenAt: week(1)),
          buildEntry(shop: shopA, eatenAt: week(1, day: 6)),
          buildEntry(shop: shopA, eatenAt: week(2, day: 3)),
        ]);

        expect(scored.map((s) => s.streakWeeksBefore), [0, 1, 0, 2]);
        expect(scored.map((s) => s.points.streakBonus), [0, 2, 0, 4]);
      });

      test('6週目からは+10で止まる', () {
        final scored = scoreVisits([
          for (var w = 0; w < 8; w++) buildEntry(shop: shopA, eatenAt: week(w)),
        ]);

        expect(scored.map((s) => s.points.streakBonus), [
          0,
          2,
          4,
          6,
          8,
          10,
          10,
          10,
        ]);
      });

      test('1週あくと数え直す', () {
        final scored = scoreVisits([
          buildEntry(shop: shopA, eatenAt: week(0)),
          buildEntry(shop: shopA, eatenAt: week(1)),
          buildEntry(shop: shopA, eatenAt: week(3)),
          buildEntry(shop: shopA, eatenAt: week(4)),
        ]);

        expect(scored.map((s) => s.points.streakBonus), [0, 2, 0, 2]);
      });

      test('撤退だけの週は続いた週に数えず、撤退した週に食べた最初の1杯にはつく', () {
        final scored = scoreVisits([
          buildEntry(shop: shopA, eatenAt: week(0)),
          buildEntry(
            shop: shopB,
            eatenAt: week(1),
            result: VisitResult.retreated,
          ),
          buildEntry(shop: shopA, eatenAt: week(2)),
          buildEntry(
            shop: shopB,
            eatenAt: week(3),
            result: VisitResult.retreated,
          ),
          buildEntry(shop: shopB, eatenAt: week(3, day: 1)),
        ]);

        expect(scored.map((s) => s.points.streakBonus), [0, 0, 0, 0, 2]);
      });

      test('週は月曜0時で切り替わる', () {
        final scored = scoreVisits([
          buildEntry(shop: shopA, eatenAt: DateTime(2026, 9, 13, 23, 59)),
          buildEntry(shop: shopA, eatenAt: DateTime(2026, 9, 14)),
        ]);

        expect(scored.map((s) => s.points.streakBonus), [0, 2]);
      });
    });

    group('初めての都道府県・市区町村', () {
      final prefectures = {
        'tokyo1': '東京都',
        'tokyo2': '東京都',
        'tokyo3': '東京都',
        'hiroshima2': '広島県',
        'osaka': '大阪府',
        'hiroshima': '広島県',
      };
      String? prefectureOf(Shop shop) => prefectures[shop.id];

      test('その都道府県で最初に食べた1杯だけに+10。撤退や位置のわからない店にはつかない', () {
        final tokyo1 = buildShop(id: 'tokyo1');
        final tokyo2 = buildShop(id: 'tokyo2');
        final osaka = buildShop(id: 'osaka');
        final scored = scoreVisits([
          buildEntry(
            shop: osaka,
            eatenAt: day(1),
            result: VisitResult.retreated,
          ),
          buildEntry(shop: tokyo1, eatenAt: day(2)),
          buildEntry(shop: tokyo2, eatenAt: day(3)),
          buildEntry(shop: osaka, eatenAt: day(4)),
          buildEntry(
            shop: buildShop(id: 'unknown'),
            eatenAt: day(5),
          ),
        ], prefectureOf: prefectureOf);

        expect(scored.map((s) => s.prefecture), [
          '大阪府',
          '東京都',
          '東京都',
          '大阪府',
          null,
        ]);
        expect(scored.map((s) => s.points.newPrefectureBonus), [
          0,
          10,
          0,
          10,
          0,
        ]);
      });

      test('同じ日時の記録は、作った順、それも同じなら記録のIDの順で初めてを決める', () {
        final at = day(1);
        final scored = scoreVisits([
          VisitWithShop(
            shop: buildShop(id: 'tokyo2'),
            visit: buildVisit(id: 'b', shopId: 'tokyo2', eatenAt: at),
          ),
          VisitWithShop(
            shop: buildShop(id: 'tokyo1'),
            visit: buildVisit(id: 'a', shopId: 'tokyo1', eatenAt: at),
          ),
        ], prefectureOf: prefectureOf);

        expect(scored.map((s) => s.visit.id), ['a', 'b']);
        expect(scored.map((s) => s.points.newPrefectureBonus), [10, 0]);
      });

      test('初めての都道府県の1杯には市区町村を重ねず、その都道府県の2つ目の市区町村から+5', () {
        final scored = scoreVisits([
          buildEntry(
            shop: buildShop(id: 'tokyo1', area: '新宿区'),
            eatenAt: day(1),
          ),
          buildEntry(
            shop: buildShop(id: 'tokyo2', area: '渋谷区'),
            eatenAt: day(2),
          ),
          buildEntry(
            shop: buildShop(id: 'tokyo3', area: '新宿区'),
            eatenAt: day(3),
          ),
        ], prefectureOf: prefectureOf);

        expect(scored.map((s) => s.points.newPrefectureBonus), [10, 0, 0]);
        expect(scored.map((s) => s.points.newAreaBonus), [0, 5, 0]);
      });

      test('市区町村は、同じ名前でも都道府県が違えば別の土地として+5', () {
        final scored = scoreVisits([
          buildEntry(
            shop: buildShop(id: 'tokyo1', area: '新宿区'),
            eatenAt: day(1),
          ),
          buildEntry(
            shop: buildShop(id: 'tokyo2', area: '府中市'),
            eatenAt: day(2),
          ),
          buildEntry(
            shop: buildShop(id: 'hiroshima', area: '三原市'),
            eatenAt: day(3),
          ),
          buildEntry(
            shop: buildShop(id: 'hiroshima2', area: '府中市'),
            eatenAt: day(4),
          ),
        ], prefectureOf: prefectureOf);

        expect(scored.map((s) => s.points.newAreaBonus), [0, 5, 0, 5]);
      });

      test('市区町村がまだわからない（調べても分からなかった）店にはつかない', () {
        final scored = scoreVisits([
          buildEntry(
            shop: buildShop(id: 'tokyo1'),
            eatenAt: day(1),
          ),
          buildEntry(
            shop: buildShop(id: 'tokyo2', area: ''),
            eatenAt: day(2),
          ),
        ], prefectureOf: prefectureOf);

        expect(scored.map((s) => s.points.newAreaBonus), [0, 0]);
      });

      test('都道府県を引かなければ、どの1杯にもつかない', () {
        final scored = scoreVisits([
          buildEntry(
            shop: buildShop(id: 'tokyo1'),
            eatenAt: day(1),
          ),
        ]);

        expect(scored.single.prefecture, isNull);
        expect(scored.single.points.newPrefectureBonus, 0);
      });
    });

    group('遠征（利用者が決めた拠点から80km・300km・800km以上）', () {
      // 緯度1度は約111.2km。0.72度は約80.1km、0.71度は約79.0km。
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

      test('299km と 300km、799km と 800km で段が変わる', () {
        Shop north(double degrees) => buildShop(
          id: 'n$degrees',
          latitude: 35.0 + degrees,
          longitude: 139.0,
        );

        expect(bonusAt(day(10), shop: north(2.689)), 20); // 約299.0km
        expect(bonusAt(day(10), shop: north(2.699)), 25); // 約300.1km
        expect(bonusAt(day(10), shop: north(7.186)), 25); // 約799.1km
        expect(bonusAt(day(10), shop: north(7.195)), 30); // 約800.1km
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

      test('遠征の1杯は isExpedition になり、初訪問と足し合わせる', () {
        final scored = scoreVisits(
          [buildEntry(shop: far, eatenAt: day(10))],
          homeBases: [base],
        ).single;

        // 10 + 初訪問5 + 遠征20 = 35
        expect(scored.points.total, 35);
        expect(scored.isExpedition, isTrue);
      });
    });

    test('記録が無ければ累計は0', () {
      expect(totalPoints(scoreVisits(const [])), 0);
    });
  });
}
