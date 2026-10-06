import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../records/clock.dart';
import '../records/models.dart';
import '../records/record_repository.dart';

/// 今の連続記録。記録が変わったときと、「今」が進んだときに計算し直す。
final streakProvider = Provider<Streak>(
  (ref) => currentStreak([
    for (final entry in ref.watch(visitsProvider).value ?? const [])
      entry.visit,
  ], ref.watch(currentTimeProvider)),
);

class Streak {
  const Streak({required this.weeks, required this.thisWeekDone});

  static const none = Streak(weeks: 0, thisWeekDone: false);

  /// 1杯以上食べた週が、何週続いているか。今週まだでも、先週まで続いていれば数える。
  final int weeks;

  /// 今週すでに食べたか。
  final bool thisWeekDone;

  /// 今週食べないと途切れる状態か。
  bool get isAtRisk => weeks > 0 && !thisWeekDone;

  @override
  bool operator ==(Object other) =>
      other is Streak &&
      other.weeks == weeks &&
      other.thisWeekDone == thisWeekDone;

  @override
  int get hashCode => Object.hash(weeks, thisWeekDone);
}

/// 週は月曜はじまり。その週の月曜0時を返す。
DateTime weekStartOf(DateTime time) =>
    DateTime(time.year, time.month, time.day - (time.weekday - 1));

/// 連続記録が途切れそうなときに知らせる時刻。今週まだなら今週の[weekday]の[hour]時、
/// 今週すでに食べていれば来週の同じ時刻（来週アプリを開かなくても届くよう先に予約する）。
/// 連続記録が無ければnull。初期値は日曜18時。
DateTime? streakReminderTime(
  Streak streak,
  DateTime now, {
  int weekday = DateTime.sunday,
  int hour = 18,
  int minute = 0,
}) {
  if (streak.weeks == 0) return null;
  final monday = weekStartOf(now);
  final weeksAhead = streak.thisWeekDone ? 1 : 0;
  return DateTime(
    monday.year,
    monday.month,
    monday.day + (weekday - 1) + 7 * weeksAhead,
    hour,
    minute,
  );
}

Streak currentStreak(List<Visit> visits, DateTime now) {
  final weeks = {
    for (final visit in visits)
      if (visit.result == VisitResult.eaten) weekStartOf(visit.eatenAt),
  };
  final thisWeek = weekStartOf(now);
  final thisWeekDone = weeks.contains(thisWeek);
  var week = thisWeekDone ? thisWeek : _previousWeek(thisWeek);
  var count = 0;
  while (weeks.contains(week)) {
    count++;
    week = _previousWeek(week);
  }
  return Streak(weeks: count, thisWeekDone: thisWeekDone);
}

DateTime _previousWeek(DateTime monday) =>
    DateTime(monday.year, monday.month, monday.day - 7);
