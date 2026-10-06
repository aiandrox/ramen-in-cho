import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/features/notifications/notification_calendar.dart';
import 'package:ramen_in_cho/features/notifications/notification_plan.dart';
import 'package:ramen_in_cho/features/notifications/notification_settings.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/streak/streak.dart';

final _shop = Shop(id: 'shop', name: '麺屋テスト', createdAt: DateTime(2026));

VisitWithShop _visit(
  DateTime eatenAt, {
  String id = 'v',
  DateTime? createdAt,
  int? rating = 3,
  VisitResult result = VisitResult.eaten,
}) => VisitWithShop(
  shop: _shop,
  visit: Visit(
    id: id,
    shopId: _shop.id,
    result: result,
    eatenAt: eatenAt,
    rating: rating,
    isLimited: false,
    memo: '',
    createdAt: createdAt ?? eatenAt,
  ),
);

Wish _wish(DateTime createdAt) =>
    Wish(id: 'w', name: '麺屋ねがい', createdAt: createdAt);

/// [only]だけをオンにした設定。
NotificationSettings _only(NotificationKind only, {bool quietNight = false}) =>
    NotificationSettings(
      disabled: {...NotificationKind.values}..remove(only),
      quietNight: quietNight,
    );

void main() {
  // 2026-10-01 は木曜。
  final thursday = DateTime(2026, 10, 1, 12);

  group('連続記録', () {
    const atRisk = Streak(weeks: 3, thisWeekDone: false);
    const done = Streak(weeks: 3, thisWeekDone: true);

    List<PlannedNotification> plan(
      Streak streak, {
      NotificationSettings? settings,
    }) => planNotifications(
      settings: settings ?? _only(NotificationKind.streak),
      streak: streak,
      now: thursday,
    );

    test('初期値では、今週まだなら今週の日曜18時に知らせる', () {
      expect(plan(atRisk), [StreakNotice(DateTime(2026, 10, 4, 18), weeks: 3)]);
    });

    test('今週すでに食べていれば、来週の同じ曜日と時刻に予約しておく', () {
      expect(plan(done), [StreakNotice(DateTime(2026, 10, 11, 18), weeks: 3)]);
    });

    test('オフにすると何も予約しない（予約済みも取り消される）。オンに戻すと予約し直す', () {
      final off = NotificationSettings.defaults.withEnabled(
        NotificationKind.streak,
        false,
      );
      List<PlannedNotification> streaks(NotificationSettings settings) =>
          plan(atRisk, settings: settings).whereType<StreakNotice>().toList();
      expect(streaks(off), isEmpty);
      expect(
        streaks(off.withEnabled(NotificationKind.streak, true)),
        streaks(NotificationSettings.defaults),
      );
      expect(streaks(NotificationSettings.defaults), hasLength(1));
    });

    test('選んだ曜日と時刻に知らせる。今週の分がもう過ぎていれば予約しない', () {
      final friday = _only(NotificationKind.streak).copyWith(
        streakWeekday: DateTime.friday,
        streakHour: 20,
        streakMinute: 30,
      );
      expect(plan(atRisk, settings: friday), [
        StreakNotice(DateTime(2026, 10, 2, 20, 30), weeks: 3),
      ]);

      final tuesday = _only(NotificationKind.streak)
          .copyWith(streakWeekday: DateTime.tuesday);
      expect(plan(atRisk, settings: tuesday), isEmpty);
      expect(plan(done, settings: tuesday), [
        StreakNotice(DateTime(2026, 10, 6, 18), weeks: 3),
      ]);
    });

    test('連続記録が無ければ予約しない', () {
      expect(plan(Streak.none), isEmpty);
    });

    test('夜は知らせない設定では、22時以降は21時に、8時より前は8時に動かす', () {
      final quiet = _only(NotificationKind.streak, quietNight: true);
      expect(
        plan(atRisk, settings: quiet.copyWith(streakHour: 23)).single.at,
        DateTime(2026, 10, 4, 21),
      );
      expect(
        plan(atRisk, settings: quiet.copyWith(streakHour: 6)).single.at,
        DateTime(2026, 10, 4, 8),
      );
      expect(
        plan(
          atRisk,
          settings: _only(NotificationKind.streak).copyWith(streakHour: 23),
        ).single.at,
        DateTime(2026, 10, 4, 23),
      );
    });
  });

  test('夜の境界: 21:59 と 8:00 はそのまま、22:00 と 7:59 は動かす', () {
    const quiet = NotificationSettings(quietNight: true);
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 10, 4, hour, minute);

    expect(avoidQuietNight(at(21, 59), quiet), at(21, 59));
    expect(avoidQuietNight(at(22), quiet), at(21));
    expect(avoidQuietNight(at(7, 59), quiet), at(8));
    expect(avoidQuietNight(at(8), quiet), at(8));
  });

  group('★の付け忘れ', () {
    final eaten = DateTime(2026, 10, 1, 12);

    test('★の無い食べた記録は、保存してから1時間半後に知らせる', () {
      expect(
        ratingReminderAt(_visit(eaten, rating: null).visit),
        DateTime(2026, 10, 1, 13, 30),
      );
      expect(ratingReminderAt(_visit(eaten).visit), isNull);
      expect(
        ratingReminderAt(
          _visit(eaten, rating: null, result: VisitResult.retreated).visit,
        ),
        isNull,
      );
    });

    test('食べてから12時間を過ぎる記録（過去の写真から記録したなど）には知らせない', () {
      Visit saved(Duration later) =>
          _visit(eaten, rating: null, createdAt: eaten.add(later)).visit;
      expect(
        ratingReminderAt(saved(const Duration(hours: 10, minutes: 30))),
        isNotNull,
      );
      expect(
        ratingReminderAt(saved(const Duration(hours: 10, minutes: 31))),
        isNull,
      );
    });

    test('いちばん新しく保存した1杯だけを予約し、★を付けたら消える', () {
      final now = DateTime(2026, 10, 1, 12, 30);
      List<PlannedNotification> plan(List<VisitWithShop> visits) =>
          planNotifications(
            settings: _only(NotificationKind.rating),
            streak: Streak.none,
            now: now,
            visits: visits,
          );
      final older = _visit(DateTime(2026, 10, 1, 11), id: 'old', rating: null);
      final latest = _visit(eaten, id: 'new', rating: null);

      expect(plan([older, latest]), [
        RatingNotice(
          DateTime(2026, 10, 1, 13, 30),
          visitId: 'new',
          shopName: '麺屋テスト',
        ),
      ]);
      expect(plan([older, _visit(eaten, id: 'new')]), isEmpty);
    });

    test('あとから過去の写真の1杯を記録しても、今日の1杯の知らせは消えない', () {
      final now = DateTime(2026, 10, 1, 12, 30);
      final today = _visit(eaten, id: 'today', rating: null);
      final old = _visit(
        DateTime(2026, 9, 1, 12),
        id: 'old',
        rating: null,
        createdAt: DateTime(2026, 10, 1, 12, 20),
      );
      final plans = planNotifications(
        settings: _only(NotificationKind.rating),
        streak: Streak.none,
        now: now,
        visits: [today, old],
      );
      expect(plans.single, isA<RatingNotice>());
      expect((plans.single as RatingNotice).visitId, 'today');
    });

    test('夜は知らせない設定では、翌朝8時に回す。12時間を過ぎるなら知らせない', () {
      List<PlannedNotification> plan(DateTime eatenAt, DateTime savedAt) =>
          planNotifications(
            settings: _only(NotificationKind.rating, quietNight: true),
            streak: Streak.none,
            now: savedAt,
            visits: [_visit(eatenAt, rating: null, createdAt: savedAt)],
          );
      final evening = DateTime(2026, 10, 1, 21);

      expect(plan(evening, evening).single.at, DateTime(2026, 10, 2, 8));
      expect(plan(DateTime(2026, 10, 1, 19, 59), evening), isEmpty);
    });
  });

  group('年の振り返り', () {
    List<PlannedNotification> plan(
      DateTime now, {
      List<VisitWithShop>? visits,
      Set<int> reviewed = const {},
    }) => planNotifications(
      settings: _only(NotificationKind.seasonal),
      streak: Streak.none,
      now: now,
      visits: visits ?? [_visit(DateTime(2026, 3, 1, 12))],
      reviewedYears: reviewed,
    ).whereType<YearReviewNotice>().toList();

    test('12月26日と30日の夜に、その年の振り返りを勧める', () {
      expect(plan(thursday), [
        YearReviewNotice(DateTime(2026, 12, 26, 20), year: 2026),
        YearReviewNotice(DateTime(2026, 12, 30, 20), year: 2026),
      ]);
      expect(plan(DateTime(2026, 12, 27)), [
        YearReviewNotice(DateTime(2026, 12, 30, 20), year: 2026),
      ]);
    });

    test('振り返りは年末（12月26日から）に開いたときだけ、その年の通知をやめる', () {
      expect(closesYearReview(2026, DateTime(2026, 10, 1)), isFalse);
      expect(closesYearReview(2026, DateTime(2026, 12, 25, 23, 59)), isFalse);
      expect(closesYearReview(2026, DateTime(2026, 12, 26)), isTrue);
      expect(closesYearReview(2025, DateTime(2026, 1, 3)), isTrue);
    });

    test('その年をもう開いていたら、その年に食べていなければ勧めない', () {
      expect(plan(thursday, reviewed: {2026}), isEmpty);
      expect(plan(thursday, visits: [_visit(DateTime(2025, 3, 1))]), isEmpty);
    });

    test('タップすると、その年の振り返りを開く', () {
      expect(
        NotificationRoute.parse(plan(thursday).first.payload),
        const YearReviewRoute(2026),
      );
    });
  });

  group('年始の願掛け', () {
    List<PlannedNotification> plan(
      DateTime now, {
      List<Wish> wishes = const [],
    }) => planNotifications(
      settings: _only(NotificationKind.seasonal),
      streak: Streak.none,
      now: now,
      wishes: wishes,
    ).whereType<NewYearWishNotice>().toList();

    test('1月1日と5日に勧める。120日より先は予約しない', () {
      final december = DateTime(2026, 12, 1);
      expect(plan(december), [
        NewYearWishNotice(DateTime(2027, 1, 1, 11)),
        NewYearWishNotice(DateTime(2027, 1, 5, 20)),
      ]);
      expect(plan(DateTime(2026, 6, 1)), isEmpty);
    });

    test('年が明けてから願を掛けたら、もう勧めない。去年の願は数えない', () {
      final jan2 = DateTime(2027, 1, 2, 9);
      expect(plan(jan2, wishes: [_wish(DateTime(2027, 1, 1, 15))]), isEmpty);
      expect(plan(jan2, wishes: [_wish(DateTime(2026, 12, 31, 23))]), [
        NewYearWishNotice(DateTime(2027, 1, 5, 20)),
      ]);
    });

    test('タップすると、願掛けタブを開く', () {
      expect(
        NotificationRoute.parse(plan(DateTime(2026, 12, 1)).first.payload),
        const WishesRoute(),
      );
    });
  });

  group('今月の一杯', () {
    List<PlannedNotification> plan(DateTime now, List<VisitWithShop> visits) =>
        planNotifications(
          settings: _only(NotificationKind.monthly),
          streak: Streak.none,
          now: now,
          visits: visits,
        );

    test('その月にまだ食べていなければ、20日の19時に知らせる。来月以降の分も予約しておく', () {
      final plans = plan(thursday, [_visit(DateTime(2026, 9, 25, 12))]);
      expect(plans.first, MonthlyNotice(DateTime(2026, 10, 20, 19)));
      expect(plans.map((p) => p.at.month), [10, 11, 12, 1]);
    });

    test('その月にもう食べていれば、その月は知らせない（撤退は数えない）', () {
      expect(
        plan(thursday, [_visit(DateTime(2026, 10, 1, 11))]).first.at,
        DateTime(2026, 11, 20, 19),
      );
      expect(
        plan(thursday, [
          _visit(DateTime(2026, 9, 1)),
          _visit(DateTime(2026, 10, 1, 11), result: VisitResult.retreated),
        ]).first.at,
        DateTime(2026, 10, 20, 19),
      );
    });

    test('まだ一度も食べていなければ知らせない', () {
      expect(plan(thursday, const []), isEmpty);
    });

    test('ateInMonth は月の境目で切り替わる', () {
      final visits = [_visit(DateTime(2026, 10, 31, 23, 59)).visit];
      expect(ateInMonth(visits, 2026, 10), isTrue);
      expect(ateInMonth(visits, 2026, 11), isFalse);
    });
  });

  group('行事の日', () {
    test('毎年同じ日付の行事を、決めた時刻に知らせる', () {
      expect(ramenEventsBetween(DateTime(2026, 1, 1), DateTime(2027, 1, 1)), [
        (RamenEvent.valentine, DateTime(2026, 2, 14, 11, 30)),
        (RamenEvent.whiteDay, DateTime(2026, 3, 14, 11, 30)),
        (RamenEvent.tanabata, DateTime(2026, 7, 7, 18)),
        (RamenEvent.ramenDay, DateTime(2026, 7, 11, 11, 30)),
        (RamenEvent.halloween, DateTime(2026, 10, 31, 18)),
        (RamenEvent.christmas, DateTime(2026, 12, 24, 18)),
        (RamenEvent.newYearsEve, DateTime(2026, 12, 31, 17)),
      ]);
    });

    test('年をまたいで、120日先までを予約する', () {
      final plans = planNotifications(
        settings: _only(NotificationKind.seasonal),
        streak: Streak.none,
        now: DateTime(2026, 12, 25),
      ).whereType<EventNotice>();
      expect(plans, [
        EventNotice(DateTime(2026, 12, 31, 17), event: RamenEvent.newYearsEve),
        EventNotice(DateTime(2027, 2, 14, 11, 30), event: RamenEvent.valentine),
        EventNotice(DateTime(2027, 3, 14, 11, 30), event: RamenEvent.whiteDay),
      ]);
    });
  });

  group('1日の上限', () {
    test('★の付け忘れのほかは1日1件。大事なほうを残す', () {
      final day = DateTime(2026, 12, 24);
      final plans = applyDailyCap([
        EventNotice(
          day.add(const Duration(hours: 18)),
          event: RamenEvent.christmas,
        ),
        StreakNotice(day.add(const Duration(hours: 20)), weeks: 2),
        RatingNotice(
          day.add(const Duration(hours: 13)),
          visitId: 'v',
          shopName: '麺屋',
        ),
        MonthlyNotice(DateTime(2026, 12, 25, 19)),
      ]);
      expect(plans, [
        RatingNotice(
          day.add(const Duration(hours: 13)),
          visitId: 'v',
          shopName: '麺屋',
        ),
        StreakNotice(day.add(const Duration(hours: 20)), weeks: 2),
        MonthlyNotice(DateTime(2026, 12, 25, 19)),
      ]);
    });

    test('優先順: 年の振り返り・年始の願掛け > 連続記録 > 今月の一杯 > 行事の日', () {
      final day = DateTime(2027, 1, 1);
      DateTime at(int hour) => day.add(Duration(hours: hour));
      expect(
        applyDailyCap([
          EventNotice(at(9), event: RamenEvent.valentine),
          MonthlyNotice(at(10)),
          StreakNotice(at(11), weeks: 1),
          NewYearWishNotice(at(12)),
        ]),
        [NewYearWishNotice(at(12))],
      );
      expect(
        applyDailyCap([
          EventNotice(at(9), event: RamenEvent.valentine),
          MonthlyNotice(at(10)),
        ]),
        [MonthlyNotice(at(10))],
      );
    });

    test('季節のお知らせどうしも1日1件。年の振り返り・年始の願掛けを行事の日より残す', () {
      final day = DateTime(2026, 12, 31);
      DateTime at(int hour) => day.add(Duration(hours: hour));
      expect(
        applyDailyCap([
          EventNotice(at(17), event: RamenEvent.newYearsEve),
          YearReviewNotice(at(20), year: 2026),
        ]),
        [YearReviewNotice(at(20), year: 2026)],
      );
      expect(
        applyDailyCap([
          NewYearWishNotice(at(11)),
          EventNotice(at(9), event: RamenEvent.valentine),
        ]),
        [NewYearWishNotice(at(11))],
      );
    });

    test('季節のお知らせを止めると、年の振り返り・年始の願掛け・行事の日をどれも予約しない', () {
      final plans = planNotifications(
        settings: NotificationSettings.defaults.withEnabled(
          NotificationKind.seasonal,
          false,
        ),
        streak: Streak.none,
        now: DateTime(2026, 12, 1),
        visits: [_visit(DateTime(2026, 3, 1, 12))],
      );
      expect(
        plans.where((plan) => plan.kind == NotificationKind.seasonal),
        isEmpty,
      );
      expect(plans, isNotEmpty);
    });

    test('今日すでに届いた通知があれば、今日はもう届けない', () {
      // 2026-10-20（火）10時に連続記録が届いたあと、同じ日の「今月の一杯」（19時）は出さない。
      final plans = planNotifications(
        settings: const NotificationSettings(
          disabled: {NotificationKind.seasonal},
          streakWeekday: DateTime.tuesday,
          streakHour: 10,
        ),
        streak: const Streak(weeks: 2, thisWeekDone: false),
        now: DateTime(2026, 10, 20, 12),
        visits: [_visit(DateTime(2026, 9, 25))],
      );
      expect(plans.first, MonthlyNotice(DateTime(2026, 11, 20, 19)));
    });
  });

  test('通知の行き先の文字列を読み取る。読めないものは無視する', () {
    expect(NotificationRoute.parse('visit:abc'), const VisitRoute('abc'));
    expect(NotificationRoute.parse('review:2026'), const YearReviewRoute(2026));
    expect(NotificationRoute.parse('tab:wishes'), const WishesRoute());
    for (final bad in [null, '', 'visit:', 'review:x', 'tab:map', 'other']) {
      expect(NotificationRoute.parse(bad), isNull);
    }
  });

  test('1年分の予約の ID はすべて別々で、並び中（1）とも重ならない', () {
    final plans = planNotifications(
      settings: NotificationSettings.defaults,
      streak: const Streak(weeks: 1, thisWeekDone: false),
      now: DateTime(2026, 10, 1, 9),
      visits: [_visit(DateTime(2026, 9, 1), id: 'a', rating: null)],
    );
    final ids = [for (final plan in plans) plan.id];
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, isNot(contains(1)));
  });
}
