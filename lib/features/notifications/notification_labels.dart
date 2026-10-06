import '../../l10n/app_localizations.dart';
import 'notification_settings.dart';

/// 通知の種類の名前。設定の画面と、Android の通知チャンネルの名前に使う。
String notificationKindLabel(AppLocalizations l10n, NotificationKind kind) =>
    switch (kind) {
      NotificationKind.checkin => l10n.notificationKindCheckin,
      NotificationKind.rating => l10n.notificationKindRating,
      NotificationKind.yearReview => l10n.notificationKindYearReview,
      NotificationKind.newYearWish => l10n.notificationKindNewYearWish,
      NotificationKind.streak => l10n.notificationKindStreak,
      NotificationKind.monthly => l10n.notificationKindMonthly,
      NotificationKind.event => l10n.notificationKindEvent,
    };

String notificationKindNote(AppLocalizations l10n, NotificationKind kind) =>
    switch (kind) {
      NotificationKind.checkin => l10n.notificationKindCheckinNote,
      NotificationKind.rating => l10n.notificationKindRatingNote,
      NotificationKind.yearReview => l10n.notificationKindYearReviewNote,
      NotificationKind.newYearWish => l10n.notificationKindNewYearWishNote,
      NotificationKind.streak => l10n.notificationKindStreakNote,
      NotificationKind.monthly => l10n.notificationKindMonthlyNote,
      NotificationKind.event => l10n.notificationKindEventNote,
    };
