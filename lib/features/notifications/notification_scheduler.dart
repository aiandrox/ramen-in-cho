import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../checkin/checkin_controller.dart';
import '../inkan/inkan.dart';
import '../records/clock.dart';
import '../records/models.dart';
import '../streak/streak.dart';
import '../words/words.dart';
import 'notification_plan.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

/// 予約しておく通知。記録・設定・「今」が変わるたびに決め直す。
final notificationPlanProvider = Provider<List<PlannedNotification>>(
  (ref) => planNotifications(
    settings: ref.watch(notificationSettingsProvider),
    streak: ref.watch(streakProvider),
    now: ref.watch(currentTimeProvider),
  ),
);

ScheduledNotification describeNotification(
  AppLocalizations l10n,
  PlannedNotification plan,
) {
  final (title, body) = switch (plan) {
    StreakNotice(:final weeks, :final at) => (
      l10n.streakReminderTitle(proseNumber(weeks)),
      streakReminderBody(at),
    ),
  };
  return ScheduledNotification(
    id: plan.id,
    kind: plan.kind,
    at: plan.at,
    title: title,
    body: body,
  );
}

/// 並び中の通知と、先に予約しておく通知を見張りはじめる。
/// 通知の文言に画面の言語設定を使うため、最初の描画のあとで呼ぶ。
void listenForNotifications(WidgetRef ref, AppLocalizations Function() l10n) {
  void updateCheckin() {
    final next = ref.read(activeCheckinProvider);
    if (next.isLoading) return;
    final checkin = next.value;
    final notifications = ref.read(notificationServiceProvider);
    final enabled = ref
        .read(notificationSettingsProvider)
        .isEnabled(NotificationKind.checkin);
    if (checkin == null || next.hasError || !enabled) {
      // 起動時に期限切れで取り消された場合なども、前の通知が残らないよう必ず消す。
      notifications.cancelCheckin();
      return;
    }
    final texts = l10n();
    notifications.showCheckin(
      title: texts.checkinBanner(checkin.name),
      body: texts.checkinNotificationBody(
        DateFormat.Hm().format(checkin.checkedInAt),
      ),
      checkedInAt: checkin.checkedInAt,
    );
  }

  // チェックインの始め方・終わり方（記録・撤退・取り消し・期限切れ）によらず、
  // 並んでいる間だけ通知を出す。
  ref.listenManual<AsyncValue<Checkin?>>(activeCheckinProvider, (
    previous,
    next,
  ) {
    if (!next.isLoading &&
        next.value != null &&
        previous?.value?.checkedInAt == next.value?.checkedInAt &&
        previous?.value?.name == next.value?.name) {
      return;
    }
    updateCheckin();
  }, fireImmediately: true);
  ref.listenManual<bool>(
    notificationSettingsProvider.select(
      (settings) => settings.isEnabled(NotificationKind.checkin),
    ),
    (_, _) => updateCheckin(),
  );

  List<ScheduledNotification>? scheduled;
  ref.listenManual<List<PlannedNotification>>(notificationPlanProvider, (
    _,
    plans,
  ) {
    final texts = l10n();
    final next = [for (final plan in plans) describeNotification(texts, plan)];
    // 「今」は1分ごとに進むので、予約が変わらないときは問い合わせない。
    if (scheduled != null && listEquals(scheduled, next)) return;
    scheduled = next;
    ref.read(notificationServiceProvider).replaceScheduled(next);
  }, fireImmediately: true);
}
