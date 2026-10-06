import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../checkin/checkin_controller.dart';
import '../inkan/inkan.dart';
import '../records/clock.dart';
import '../records/models.dart';
import '../records/record_repository.dart';
import '../review/year_review_seen.dart';
import '../streak/streak.dart';
import '../wishes/wish_repository.dart';
import '../words/words.dart';
import 'notification_plan.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

/// 予約しておく通知。記録・願・設定・「今」が変わるたびに決め直す。
/// 記録や願を読み込んでいる間はnull（読み込む前の空の記録で予約し直さないため）。
final notificationPlanProvider = Provider<List<PlannedNotification>?>((ref) {
  final visits = ref.watch(visitsProvider);
  final wishes = ref.watch(wishesProvider);
  if (!visits.hasValue || !wishes.hasValue) return null;
  return planNotifications(
    settings: ref.watch(notificationSettingsProvider),
    streak: ref.watch(streakProvider),
    now: ref.watch(currentTimeProvider),
    visits: visits.value!,
    wishes: wishes.value!,
    reviewedYears: ref.watch(yearReviewSeenProvider),
  );
});

ScheduledNotification describeNotification(
  AppLocalizations l10n,
  PlannedNotification plan,
) {
  final (title, body) = switch (plan) {
    StreakNotice(:final weeks, :final at) => (
      l10n.streakReminderTitle(proseNumber(weeks)),
      streakReminderBody(at),
    ),
    RatingNotice(:final shopName, :final visitId) => (
      l10n.ratingReminderTitle(shopName),
      ratingReminderBody(visitId),
    ),
    YearReviewNotice(:final year, :final at) => (
      l10n.yearReviewReminderTitle(year),
      yearReviewReminderBody(at),
    ),
    NewYearWishNotice(:final at) => (
      l10n.newYearWishReminderTitle,
      newYearWishReminderBody(at),
    ),
    MonthlyNotice(:final at) => (
      l10n.monthlyReminderTitle(at.month),
      monthlyReminderBody(at),
    ),
    EventNotice(:final event, :final at) => (
      l10n.eventReminderTitle(event.name),
      eventReminderBody(event, at.year),
    ),
  };
  return ScheduledNotification(
    id: plan.id,
    kind: plan.kind,
    at: plan.at,
    title: title,
    body: body,
    payload: plan.payload,
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
  ref.listenManual<List<PlannedNotification>?>(notificationPlanProvider, (
    _,
    plans,
  ) {
    if (plans == null) return;
    final texts = l10n();
    final next = [for (final plan in plans) describeNotification(texts, plan)];
    // 「今」は1分ごとに進むので、予約が変わらないときは問い合わせない。
    if (scheduled != null && listEquals(scheduled, next)) return;
    scheduled = next;
    ref.read(notificationServiceProvider).replaceScheduled(next).then((ok) {
      // 失敗したら、次に「今」が進んだときに予約し直す。
      if (!ok && identical(scheduled, next)) scheduled = null;
    });
  }, fireImmediately: true);
}
