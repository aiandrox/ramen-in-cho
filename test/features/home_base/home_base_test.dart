import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base.dart';

import '../../support/builders.dart';

void main() {
  final yokohama = buildHomeBase(
    id: 'yokohama',
    setAt: DateTime(2026, 3, 1, 9),
  );
  final sapporo = buildHomeBase(id: 'sapporo', setAt: DateTime(2026, 6, 1, 9));
  final settings = [sapporo, yokohama];

  group('homeBaseAt', () {
    test('まだ決めていなければ拠点は無い', () {
      expect(homeBaseAt(const [], DateTime(2026, 7, 1)), isNull);
    });

    test('初めて決めるより前の記録には拠点が無い', () {
      expect(homeBaseAt(settings, DateTime(2026, 3, 1, 8, 59)), isNull);
    });

    test('決めた日時ちょうどの記録から効く', () {
      expect(homeBaseAt(settings, DateTime(2026, 3, 1, 9))?.id, 'yokohama');
    });

    test('変える前は前の拠点、変えたあとは新しい拠点', () {
      expect(homeBaseAt(settings, DateTime(2026, 6, 1, 8))?.id, 'yokohama');
      expect(homeBaseAt(settings, DateTime(2026, 6, 1, 9))?.id, 'sapporo');
      expect(homeBaseAt(settings, DateTime(2027))?.id, 'sapporo');
    });
  });

  test('今の拠点はいちばん新しく決めたもの、最初の拠点はいちばん古いもの', () {
    expect(latestHomeBase(settings)?.id, 'sapporo');
    expect(firstHomeBase(settings)?.id, 'yokohama');
    expect(latestHomeBase(const []), isNull);
    expect(firstHomeBase(const []), isNull);
  });

  group('同じ日時の拠点', () {
    final a = buildHomeBase(id: 'a', setAt: DateTime(2026, 6, 1));
    final b = buildHomeBase(id: 'b', setAt: DateTime(2026, 6, 1));

    test('IDの大きいほうが効き、並べ方によらない', () {
      for (final settings in [
        [a, b],
        [b, a],
      ]) {
        expect(homeBaseAt(settings, DateTime(2026, 6, 1))?.id, 'b');
        expect(latestHomeBase(settings)?.id, 'b');
        expect(firstHomeBase(settings)?.id, 'a');
        expect(homeBasesNewestFirst(settings).map((s) => s.id), ['b', 'a']);
      }
    });
  });

  test('これまでの拠点は新しい順に並べる', () {
    expect(homeBasesNewestFirst([yokohama, sapporo]).map((s) => s.id), [
      'sapporo',
      'yokohama',
    ]);
  });

  test('日付を直すと、その日の0時から効く', () {
    expect(
      homeBaseDayStart(DateTime(2026, 6, 1, 23, 59)),
      DateTime(2026, 6, 1),
    );
    final moved = sapporo.copyWith(
      setAt: homeBaseDayStart(DateTime(2026, 5, 20, 15)),
    );
    expect(
      homeBaseAt([yokohama, moved], DateTime(2026, 5, 19, 23))?.id,
      'yokohama',
    );
    expect(homeBaseAt([yokohama, moved], DateTime(2026, 5, 20))?.id, 'sapporo');
  });

  group('新しく決める拠点の「いつから」', () {
    final now = DateTime(2026, 10, 8, 20);

    test('拠点がまだ無ければ、ずっと前の日から選べる', () {
      expect(earliestNewHomeBaseDay(const [], now), homeBaseFirstDay);
    });

    test('今の拠点を決めた日の翌日から選べる', () {
      expect(earliestNewHomeBaseDay(settings, now), DateTime(2026, 6, 2));
    });

    test('今の拠点を今日決めたなら、今日だけ選べる', () {
      final today = buildHomeBase(id: 'today', setAt: DateTime(2026, 10, 8, 9));
      expect(earliestNewHomeBaseDay([today], now), DateTime(2026, 10, 8));
    });

    test('今日を選ぶと今この時から、前の日を選ぶとその日の0時から効く', () {
      expect(newHomeBaseSetAt(day: DateTime(2026, 10, 8), now: now), now);
      expect(
        newHomeBaseSetAt(day: DateTime(2026, 9, 1, 15), now: now),
        DateTime(2026, 9, 1),
      );
    });

    test('前の日から決めると、その日からの記録は新しい拠点、その前は前の拠点で決まり、今の拠点は新しい拠点になる', () {
      final day = earliestNewHomeBaseDay(settings, now);
      final added = buildHomeBase(
        id: 'added',
        setAt: newHomeBaseSetAt(day: day, now: now),
      );
      final all = [...settings, added];
      expect(homeBaseAt(all, DateTime(2026, 6, 1, 23))?.id, 'sapporo');
      expect(homeBaseAt(all, DateTime(2026, 6, 2))?.id, 'added');
      expect(homeBaseAt(all, now)?.id, 'added');
      expect(latestHomeBase(all)?.id, 'added');
    });

    test('窓を開いている間に日付が変わり、今の拠点より前になるときは今この時にする', () {
      final today = buildHomeBase(
        id: 'today',
        setAt: DateTime(2026, 10, 7, 10),
      );
      expect(
        newHomeBaseSetAt(
          day: DateTime(2026, 10, 7),
          now: DateTime(2026, 10, 8, 0, 1),
          settings: [today],
        ),
        DateTime(2026, 10, 8, 0, 1),
      );
      expect(newHomeBaseSetAt(day: null, now: now, settings: [today]), now);
    });

    test('今日のうちに2回決めても、後に決めたほうが今の拠点になる', () {
      final first = buildHomeBase(
        id: 'zzz',
        setAt: newHomeBaseSetAt(day: now, now: DateTime(2026, 10, 8, 9)),
      );
      final second = buildHomeBase(
        id: 'aaa',
        setAt: newHomeBaseSetAt(
          day: earliestNewHomeBaseDay([first], now),
          now: now,
        ),
      );
      expect(latestHomeBase([first, second])?.id, 'aaa');
    });
  });
}
