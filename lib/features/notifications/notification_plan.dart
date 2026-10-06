import 'package:flutter/foundation.dart';

import '../streak/streak.dart';
import 'notification_settings.dart';

/// 先に予約しておく通知1件。文言は画面の側（[NotificationKind]ごと）で組み立てる。
@immutable
sealed class PlannedNotification {
  const PlannedNotification(this.at);

  final DateTime at;

  NotificationKind get kind;

  /// 予約の ID。同じ ID で予約し直すと前の予約が置き換わる。並び中の通知（1）とは重ねない。
  int get id;

  PlannedNotification moveTo(DateTime at);
}

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
  bool operator ==(Object other) =>
      other is StreakNotice && other.at == at && other.weeks == weeks;

  @override
  int get hashCode => Object.hash(at, weeks);
}

/// 夜（22時〜8時）を避けるなら、同じ日のうちに動かす（22時以降は21時、8時より前は8時）。
/// 日をまたがせないのは、曜日や日付で決めた通知の意味を変えないため。
DateTime avoidQuietNight(DateTime at, NotificationSettings settings) {
  if (!settings.quietNight) return at;
  if (at.hour >= 22) return DateTime(at.year, at.month, at.day, 21);
  if (at.hour < 8) return DateTime(at.year, at.month, at.day, 8);
  return at;
}

/// 今の記録と設定から、予約しておく通知を決める。オフの種類と過ぎた時刻は含めない。
List<PlannedNotification> planNotifications({
  required NotificationSettings settings,
  required Streak streak,
  required DateTime now,
}) {
  final plans = <PlannedNotification>[];
  if (settings.isEnabled(NotificationKind.streak)) {
    final at = streakReminderTime(
      streak,
      now,
      weekday: settings.streakWeekday,
      hour: settings.streakHour,
      minute: settings.streakMinute,
    );
    if (at != null) plans.add(StreakNotice(at, weeks: streak.weeks));
  }
  return [
    for (final plan in plans)
      if (plan.moveTo(avoidQuietNight(plan.at, settings)) case final moved
          when moved.at.isAfter(now))
        moved,
  ];
}
