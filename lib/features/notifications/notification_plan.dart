import 'package:flutter/foundation.dart';

import '../records/models.dart';
import '../streak/streak.dart';
import 'notification_calendar.dart';
import 'notification_settings.dart';

/// 先に予約しておく通知1件。文言は画面の側（[NotificationKind]ごと）で組み立てる。
@immutable
sealed class PlannedNotification {
  const PlannedNotification(this.at);

  final DateTime at;

  NotificationKind get kind;

  /// 予約の ID。同じ ID で予約し直すと前の予約が置き換わる。並び中の通知（1）とは重ねない。
  int get id;

  /// タップしたときの行き先（[NotificationRoute]）。アプリを開くだけならnull。
  String? get payload => null;

  PlannedNotification moveTo(DateTime at);

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is PlannedNotification &&
      other.at == at &&
      listEquals(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, at, Object.hashAll(_props));
}

/// 日付で決まる通知の ID。種類ごとに桁を分け、同じ種類の別の日と重ならないようにする。
int _dateId(int kindCode, DateTime at) =>
    kindCode * 100000000 + at.year * 10000 + at.month * 100 + at.day;

class StreakNotice extends PlannedNotification {
  const StreakNotice(super.at, {required this.weeks});

  final int weeks;

  @override
  NotificationKind get kind => NotificationKind.streak;

  @override
  int get id => 2;

  @override
  StreakNotice moveTo(DateTime at) => StreakNotice(at, weeks: weeks);

  @override
  List<Object?> get _props => [weeks];
}

class RatingNotice extends PlannedNotification {
  const RatingNotice(super.at, {required this.visitId, required this.shopName});

  final String visitId;
  final String shopName;

  @override
  NotificationKind get kind => NotificationKind.rating;

  /// ★の付け忘れは、いちばん新しい1杯の分だけを予約する。
  @override
  int get id => 10;

  @override
  String get payload => VisitRoute(visitId).payload;

  @override
  RatingNotice moveTo(DateTime at) =>
      RatingNotice(at, visitId: visitId, shopName: shopName);

  @override
  List<Object?> get _props => [visitId, shopName];
}

class YearReviewNotice extends PlannedNotification {
  const YearReviewNotice(super.at, {required this.year});

  final int year;

  @override
  NotificationKind get kind => NotificationKind.yearReview;

  @override
  int get id => _dateId(3, at);

  @override
  String get payload => YearReviewRoute(year).payload;

  @override
  YearReviewNotice moveTo(DateTime at) => YearReviewNotice(at, year: year);

  @override
  List<Object?> get _props => [year];
}

class NewYearWishNotice extends PlannedNotification {
  const NewYearWishNotice(super.at);

  @override
  NotificationKind get kind => NotificationKind.newYearWish;

  @override
  int get id => _dateId(4, at);

  @override
  String get payload => const WishesRoute().payload;

  @override
  NewYearWishNotice moveTo(DateTime at) => NewYearWishNotice(at);

  @override
  List<Object?> get _props => const [];
}

class MonthlyNotice extends PlannedNotification {
  const MonthlyNotice(super.at);

  @override
  NotificationKind get kind => NotificationKind.monthly;

  @override
  int get id => _dateId(5, at);

  @override
  MonthlyNotice moveTo(DateTime at) => MonthlyNotice(at);

  @override
  List<Object?> get _props => const [];
}

class EventNotice extends PlannedNotification {
  const EventNotice(super.at, {required this.event});

  final RamenEvent event;

  @override
  NotificationKind get kind => NotificationKind.event;

  @override
  int get id => _dateId(6, at);

  @override
  EventNotice moveTo(DateTime at) => EventNotice(at, event: event);

  @override
  List<Object?> get _props => [event];
}

/// 通知をタップしたときの行き先。通知には文字列（payload）にして持たせる。
sealed class NotificationRoute {
  const NotificationRoute();

  String get payload;

  static NotificationRoute? parse(String? payload) {
    if (payload == null) return null;
    final separator = payload.indexOf(':');
    if (separator < 0) return null;
    final value = payload.substring(separator + 1);
    return switch (payload.substring(0, separator)) {
      'visit' when value.isNotEmpty => VisitRoute(value),
      'review' => switch (int.tryParse(value)) {
        final year? => YearReviewRoute(year),
        null => null,
      },
      'tab' when value == 'wishes' => const WishesRoute(),
      _ => null,
    };
  }
}

class VisitRoute extends NotificationRoute {
  const VisitRoute(this.visitId);

  final String visitId;

  @override
  String get payload => 'visit:$visitId';

  @override
  bool operator ==(Object other) =>
      other is VisitRoute && other.visitId == visitId;

  @override
  int get hashCode => visitId.hashCode;
}

class YearReviewRoute extends NotificationRoute {
  const YearReviewRoute(this.year);

  final int year;

  @override
  String get payload => 'review:$year';

  @override
  bool operator ==(Object other) =>
      other is YearReviewRoute && other.year == year;

  @override
  int get hashCode => year.hashCode;
}

class WishesRoute extends NotificationRoute {
  const WishesRoute();

  @override
  String get payload => 'tab:wishes';

  @override
  bool operator ==(Object other) => other is WishesRoute;

  @override
  int get hashCode => 0;
}

bool _isNight(DateTime at) => at.hour >= 22 || at.hour < 8;

/// 夜（22時〜8時）を避けるなら、同じ日のうちに動かす（22時以降は21時、8時より前は8時）。
/// 日をまたがせないのは、曜日や日付で決めた通知の意味を変えないため。
DateTime avoidQuietNight(DateTime at, NotificationSettings settings) {
  if (!settings.quietNight) return at;
  if (at.hour >= 22) return DateTime(at.year, at.month, at.day, 21);
  if (at.hour < 8) return DateTime(at.year, at.month, at.day, 8);
  return at;
}

/// 先まで予約しておく日数。アプリを開くたびに予約し直すので、長く開かない人には届かなくなる。
const planningHorizon = Duration(days: 120);

/// 1日に届く通知の数を絞るときの優先順（小さいほど大事）。★の付け忘れは別枠。
int _priority(NotificationKind kind) => switch (kind) {
  NotificationKind.yearReview || NotificationKind.newYearWish => 0,
  NotificationKind.streak => 1,
  NotificationKind.monthly => 2,
  NotificationKind.event => 3,
  NotificationKind.rating || NotificationKind.checkin => -1,
};

/// 1日に届くのは、★の付け忘れ（自分の記録への返事なので別枠）と、ほかの1件まで。
/// ほかの通知が同じ日に重なったら、[_priority]の大事なほう（同じなら早いほう）だけを残す。
List<PlannedNotification> applyDailyCap(List<PlannedNotification> plans) {
  final kept = <PlannedNotification>[];
  final byDay = <DateTime, PlannedNotification>{};
  for (final plan in plans) {
    if (plan.kind == NotificationKind.rating) {
      kept.add(plan);
      continue;
    }
    final day = DateTime(plan.at.year, plan.at.month, plan.at.day);
    final current = byDay[day];
    if (current == null ||
        _priority(plan.kind) < _priority(current.kind) ||
        (_priority(plan.kind) == _priority(current.kind) &&
            plan.at.isBefore(current.at))) {
      byDay[day] = plan;
    }
  }
  return [...kept, ...byDay.values]..sort((a, b) => a.at.compareTo(b.at));
}

/// 今の記録と設定から、予約しておく通知を決める。オフの種類と過ぎた時刻は含めない。
/// [reviewedYears]は、年の振り返りをもう開いた年。
List<PlannedNotification> planNotifications({
  required NotificationSettings settings,
  required Streak streak,
  required DateTime now,
  List<VisitWithShop> visits = const [],
  List<Wish> wishes = const [],
  Set<int> reviewedYears = const {},
}) {
  // 今日すでに届いた（時刻の過ぎた）通知も数えて1日の上限を決めるため、今日の0時から考える。
  final today = DateTime(now.year, now.month, now.day);
  final until = today.add(planningHorizon);
  bool inRange(DateTime at) => !at.isBefore(today) && at.isBefore(until);
  final plans = <PlannedNotification>[];
  void add(NotificationKind kind, Iterable<PlannedNotification> candidates) {
    if (!settings.isEnabled(kind)) return;
    plans.addAll(candidates.where((plan) => inRange(plan.at)));
  }

  add(NotificationKind.rating, [?_ratingNotice(visits, settings)]);

  add(NotificationKind.yearReview, [
    for (var year = today.year; year <= until.year; year++)
      if (!reviewedYears.contains(year) &&
          visits.any(
            (entry) =>
                entry.visit.result == VisitResult.eaten &&
                entry.visit.eatenAt.year == year,
          ))
        for (final at in yearReviewTimes(year))
          YearReviewNotice(at, year: year),
  ]);

  add(NotificationKind.newYearWish, [
    for (var year = today.year; year <= until.year; year++)
      if (!wishes.any(
        (wish) => !wish.createdAt.isBefore(newYearWishWindowStart(year)),
      ))
        for (final at in newYearWishTimes(year)) NewYearWishNotice(at),
  ]);

  final at = streakReminderTime(
    streak,
    now,
    weekday: settings.streakWeekday,
    hour: settings.streakHour,
    minute: settings.streakMinute,
  );
  add(NotificationKind.streak, [
    if (at != null) StreakNotice(at, weeks: streak.weeks),
  ]);

  final hasEaten = visits.any(
    (entry) => entry.visit.result == VisitResult.eaten,
  );
  add(NotificationKind.monthly, [
    if (hasEaten)
      for (
        var month = DateTime(today.year, today.month);
        month.isBefore(until);
        month = DateTime(month.year, month.month + 1)
      )
        if (!ateInMonth(
          visits.map((entry) => entry.visit),
          month.year,
          month.month,
        ))
          MonthlyNotice(monthlyReminderAt(month.year, month.month)),
  ]);

  add(NotificationKind.event, [
    for (final (event, at) in ramenEventsBetween(today, until))
      EventNotice(at, event: event),
  ]);

  return [
    for (final plan in applyDailyCap([
      for (final plan in plans) plan.moveTo(avoidQuietNight(plan.at, settings)),
    ]))
      if (plan.at.isAfter(now)) plan,
  ];
}

/// いちばん新しく保存した「食べた」記録に★が無ければ、★の付け忘れを知らせる。
/// 夜を避けるなら翌朝8時に回す（食べてから12時間を過ぎるなら知らせない）。
RatingNotice? _ratingNotice(
  List<VisitWithShop> visits,
  NotificationSettings settings,
) {
  VisitWithShop? latest;
  for (final entry in visits) {
    if (entry.visit.result != VisitResult.eaten) continue;
    if (latest == null ||
        entry.visit.createdAt.isAfter(latest.visit.createdAt)) {
      latest = entry;
    }
  }
  if (latest == null) return null;
  var at = ratingReminderAt(latest.visit);
  if (at == null) return null;
  if (settings.quietNight && _isNight(at)) {
    at = DateTime(at.year, at.month, at.day + (at.hour >= 22 ? 1 : 0), 8);
    if (at.difference(latest.visit.eatenAt) > ratingWindow) return null;
  }
  return RatingNotice(at, visitId: latest.visit.id, shopName: latest.shop.name);
}
