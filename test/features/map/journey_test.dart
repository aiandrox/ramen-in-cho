import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/map/journey.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';

import '../../support/builders.dart';

void main() {
  // 緯度0.01度は約1.1km。
  final home = buildShop(id: 'home', latitude: 35.0, longitude: 139.0);
  final near = buildShop(id: 'near', latitude: 35.01, longitude: 139.0);
  final far = buildShop(id: 'far', latitude: 35.8, longitude: 139.0);
  final unknown = buildShop(id: 'unknown');
  DateTime day(int month, int d) => DateTime(2026, month, d, 12);

  List<ScoredVisit> scored(List<VisitWithShop> entries) => scoreVisits(entries);

  final homeBase = [buildHomeBase(setAt: DateTime(2025, 1, 1))];
  List<ScoredVisit> withBase(List<VisitWithShop> entries) =>
      scoreVisits(entries, homeBases: homeBase);

  test('食べた店を順に並べ、位置のわからない店と撤退と、続けて同じ店は除く', () {
    final stops = journeyStops(
      scored([
        buildEntry(shop: home, eatenAt: day(1, 1)),
        buildEntry(shop: home, eatenAt: day(1, 2)),
        buildEntry(shop: unknown, eatenAt: day(1, 3)),
        buildEntry(
          shop: near,
          result: VisitResult.retreated,
          eatenAt: day(1, 4),
        ),
        buildEntry(shop: near, eatenAt: day(1, 5)),
        buildEntry(shop: home, eatenAt: day(1, 6)),
      ]),
    );

    expect(stops.map((s) => s.shop.id), ['home', 'near', 'home']);
    expect(journeyKilometers(stops), closeTo(2.22, 0.02));
  });

  test('年で絞り込める', () {
    final stops = journeyStops(
      scored([
        buildEntry(shop: home, eatenAt: DateTime(2025, 12, 31, 12)),
        buildEntry(shop: near, eatenAt: day(1, 1)),
      ]),
      year: 2026,
    );

    expect(stops.map((s) => s.shop.id), ['near']);
  });

  test('拠点から80km以上離れた店で食べた日を、遠征としてまとめる', () {
    final list = expeditions(
      withBase([
        buildEntry(shop: home, eatenAt: day(1, 1)),
        buildEntry(shop: far, eatenAt: day(2, 1)),
        buildEntry(shop: near, eatenAt: day(2, 2)),
      ]),
    );

    expect(list.single.day, DateTime(2026, 2, 1));
    expect(list.single.stops.single.shop.id, 'far');
  });

  test('拠点から80km未満の店は、遠征にしない', () {
    // 緯度0.72度は約80.1km、0.71度は約79.0km。
    final justFar = buildShop(id: 'justFar', latitude: 35.72, longitude: 139.0);
    final notFar = buildShop(id: 'notFar', latitude: 35.71, longitude: 139.0);
    final list = expeditions(
      withBase([
        buildEntry(shop: notFar, eatenAt: day(2, 1)),
        buildEntry(shop: justFar, eatenAt: day(2, 2)),
      ]),
    );

    expect(list.single.stops.single.shop.id, 'justFar');
  });

  test('拠点を決めていなければ、同じ地域で何杯食べても遠征は無い', () {
    final list = expeditions(
      scored([
        for (var d = 1; d <= 6; d++) buildEntry(shop: home, eatenAt: day(1, d)),
        buildEntry(shop: far, eatenAt: day(2, 1)),
      ]),
    );

    expect(list, isEmpty);
  });

  test('同じ遠くの店へ別の日に行けば別の遠征にする', () {
    final farB = buildShop(id: 'farB', latitude: 35.81, longitude: 139.0);
    final list = expeditions(
      withBase([
        buildEntry(shop: far, eatenAt: day(3, 1)),
        buildEntry(shop: farB, eatenAt: day(3, 1)),
        buildEntry(shop: far, eatenAt: day(3, 2)),
        buildEntry(shop: far, eatenAt: day(4, 10)),
      ]),
    );

    expect(list.map((e) => e.day), [
      DateTime(2026, 4, 10),
      DateTime(2026, 3, 2),
      DateTime(2026, 3, 1),
    ]);
    expect(list.last.stops.map((s) => s.shop.id), ['far', 'farB']);
  });

  test('遠征を年で絞り込める', () {
    final list = expeditions(
      withBase([
        buildEntry(shop: far, eatenAt: DateTime(2025, 6, 1, 12)),
        buildEntry(shop: far, eatenAt: day(1, 2)),
      ]),
      year: 2026,
    );

    expect(list.single.day, DateTime(2026, 1, 2));
  });

  test('遠征はその1杯の時点の拠点で決め、拠点を変えても前の遠征は変わらない', () {
    final list = expeditions(
      scoreVisits(
        [
          buildEntry(shop: far, eatenAt: DateTime(2024, 12, 31, 12)),
          buildEntry(shop: far, eatenAt: DateTime(2025, 2, 1, 12)),
          buildEntry(shop: far, eatenAt: day(3, 1)),
          buildEntry(shop: home, eatenAt: day(6, 1)),
        ],
        homeBases: [
          buildHomeBase(setAt: DateTime(2025, 1, 1)),
          buildHomeBase(latitude: 35.8, setAt: DateTime(2026, 1, 1)),
        ],
      ),
    );

    expect(list.map((e) => (e.day, e.stops.single.shop.id)), [
      (DateTime(2026, 6, 1), 'home'),
      (DateTime(2025, 2, 1), 'far'),
    ]);
  });

  test('位置のわからない店と撤退は、遠征にしない', () {
    final list = expeditions(
      withBase([
        buildEntry(shop: unknown, eatenAt: day(1, 1)),
        buildEntry(
          shop: far,
          result: VisitResult.retreated,
          eatenAt: day(1, 2),
        ),
      ]),
    );

    expect(list, isEmpty);
  });

  test('記録が無ければ遠征も無い', () {
    expect(expeditions(const []), isEmpty);
  });

  group('旅路の再生', () {
    test('1区間の長さは距離で決め、1.2〜2.8秒に収める', () {
      expect(journeyStepDuration(0), const Duration(milliseconds: 1200));
      expect(journeyStepDuration(1000), const Duration(milliseconds: 2000));
      expect(journeyStepDuration(1999), const Duration(milliseconds: 2799));
      expect(journeyStepDuration(2000), const Duration(milliseconds: 2800));
      expect(journeyStepDuration(90000), const Duration(milliseconds: 2800));
    });

    List<JourneyStop> stopsOf(List<Shop> shops) => journeyStops(
      scored([
        for (var i = 0; i < shops.length; i++)
          buildEntry(shop: shops[i], eatenAt: day(1, i + 1)),
      ]),
    );

    test('1杯目の店で止まり、1区間ずつ進んでは着いた店で止まる', () {
      final plan = JourneyReplayPlan(stopsOf([home, near, far]));
      final step1 = journeyStepDuration(1112).inMilliseconds;
      final total = plan.duration.inMilliseconds;
      const pause = journeyStopPauseMs;
      expect(pause, 800);
      expect(total, pause + step1 + pause + 2800 + pause);
      double at(int ms) => ms / total;

      expect(plan.reachAt(0), 0);
      expect(plan.reachAt(at(pause)), 0);
      expect(plan.reachAt(at(pause + step1 ~/ 2)), closeTo(0.5, 0.01));
      expect(plan.reachAt(at(pause + step1)), 1);
      expect(plan.reachAt(at(pause + step1 + 600)), 1);
      expect(plan.reachAt(1), 2);
      expect(JourneyReplayPlan(stopsOf([home])).reachAt(1), 0);
    });

    test('ピンは線が着いた直後、止まっている間に刺さり、次の区間より前に刺さりきる', () {
      final plan = JourneyReplayPlan(stopsOf([home, near, far]));
      final step1 = journeyStepDuration(1112).inMilliseconds;
      final total = plan.duration.inMilliseconds;
      const pause = journeyStopPauseMs;
      double at(int ms) => ms / total;

      expect(plan.pinAt(0, 0), 1);
      expect(plan.pinAt(at(pause + step1 - 1), 1), 0);
      expect(
        plan.pinAt(at(pause + step1 + journeyPinDropMs ~/ 2), 1),
        closeTo(0.5, 0.01),
      );
      // 刺さりきってから、次の区間へ進む。
      expect(journeyPinDropMs, lessThan(pause));
      expect(plan.pinAt(at(pause + step1 + pause), 1), 1);
      expect(plan.reachAt(at(pause + step1 + pause)), 1);
      expect(plan.pinAt(at(pause + step1 + pause + 2800 - 1), 2), 0);
      expect(plan.pinAt(1, 2), 1);
    });

    test('近い区間は線の先を追い、遠い区間は半分で次の店へ移る', () {
      final plan = JourneyReplayPlan(stopsOf([home, near, far]));
      final step1 = journeyStepDuration(1112).inMilliseconds;
      final total = plan.duration.inMilliseconds;
      double at(int ms) => ms / total;
      const pause = journeyStopPauseMs;

      expect(plan.cameraAt(0).latitude, 35.0);
      expect(
        plan.cameraAt(at(pause + step1 ~/ 2)).latitude,
        closeTo(35.005, 0.0002),
      );
      final farStart = pause + step1 + pause;
      expect(plan.cameraAt(at(farStart + 700)).latitude, 35.01);
      expect(plan.cameraAt(at(farStart + 2000)).latitude, 35.8);
      expect(plan.cameraAt(1).latitude, 35.8);
    });

    test('途中の区間は、着いた割合のところまで線を引く', () {
      final stops = journeyStops(
        scored([
          buildEntry(shop: home, eatenAt: day(1, 1)),
          buildEntry(shop: near, eatenAt: day(1, 2)),
        ]),
      );

      expect(journeyLineTo(stops, 0), hasLength(1));
      final half = journeyLineTo(stops, 0.5);
      expect(half, hasLength(2));
      expect(half.last.latitude, closeTo(35.005, 1e-9));
      expect(journeyLineTo(stops, 1), hasLength(2));
    });
  });
}
