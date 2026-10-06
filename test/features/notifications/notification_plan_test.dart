import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/features/notifications/notification_plan.dart';
import 'package:ramen_in_cho/features/notifications/notification_settings.dart';
import 'package:ramen_in_cho/features/streak/streak.dart';

void main() {
  // 2026-10-01 は木曜。
  final thursday = DateTime(2026, 10, 1, 12);
  const atRisk = Streak(weeks: 3, thisWeekDone: false);
  const done = Streak(weeks: 3, thisWeekDone: true);

  List<PlannedNotification> plan(
    Streak streak, {
    NotificationSettings settings = NotificationSettings.defaults,
  }) => planNotifications(settings: settings, streak: streak, now: thursday);

  test('初期値では、今週まだなら今週の日曜18時に連続記録を知らせる', () {
    expect(plan(atRisk), [StreakNotice(DateTime(2026, 10, 4, 18), weeks: 3)]);
  });

  test('今週すでに食べていれば、来週の同じ曜日と時刻に予約しておく', () {
    expect(plan(done), [StreakNotice(DateTime(2026, 10, 11, 18), weeks: 3)]);
  });

  test('連続記録をオフにすると何も予約しない（予約済みも取り消される）。オンに戻すと予約し直す', () {
    final off = NotificationSettings.defaults.withEnabled(
      NotificationKind.streak,
      false,
    );
    expect(plan(atRisk, settings: off), isEmpty);
    expect(plan(done, settings: off), isEmpty);
    expect(
      plan(atRisk, settings: off.withEnabled(NotificationKind.streak, true)),
      plan(atRisk),
    );
  });

  test('並び中だけをオフにしても、連続記録の予約は変わらない', () {
    final settings = NotificationSettings.defaults.withEnabled(
      NotificationKind.checkin,
      false,
    );
    expect(plan(atRisk, settings: settings), plan(atRisk));
  });

  test('選んだ曜日と時刻に知らせる。今週の分がもう過ぎていれば予約しない', () {
    const friday = NotificationSettings(
      streakWeekday: DateTime.friday,
      streakHour: 20,
      streakMinute: 30,
    );
    expect(plan(atRisk, settings: friday), [
      StreakNotice(DateTime(2026, 10, 2, 20, 30), weeks: 3),
    ]);

    const tuesday = NotificationSettings(streakWeekday: DateTime.tuesday);
    expect(plan(atRisk, settings: tuesday), isEmpty);
    expect(plan(done, settings: tuesday), [
      StreakNotice(DateTime(2026, 10, 6, 18), weeks: 3),
    ]);
  });

  test('連続記録が無ければ予約しない', () {
    expect(plan(Streak.none), isEmpty);
  });

  test('夜は知らせない設定では、22時以降は21時に、8時より前は8時に動かす', () {
    const late = NotificationSettings(streakHour: 23, quietNight: true);
    expect(plan(atRisk, settings: late).single.at, DateTime(2026, 10, 4, 21));

    const early = NotificationSettings(streakHour: 6, quietNight: true);
    expect(plan(atRisk, settings: early).single.at, DateTime(2026, 10, 4, 8));

    const off = NotificationSettings(streakHour: 23);
    expect(plan(atRisk, settings: off).single.at, DateTime(2026, 10, 4, 23));
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
}
