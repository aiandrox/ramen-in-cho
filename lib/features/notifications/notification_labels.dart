import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import 'notification_settings.dart';

/// 通知の種類の名前。設定の画面と、Android の通知チャンネルの名前に使う。
String notificationKindLabel(AppLocalizations l10n, NotificationKind kind) =>
    switch (kind) {
      NotificationKind.checkin => l10n.notificationKindCheckin,
      NotificationKind.streak => l10n.notificationKindStreak,
      NotificationKind.rating => l10n.notificationKindRating,
      NotificationKind.monthly => l10n.notificationKindMonthly,
      NotificationKind.seasonal => l10n.notificationKindSeasonal,
    };

/// 種類の短い説明。名前だけでわかる種類はnull。
/// 並び中の通知は、iOS では経過時間が進まないので説明を分ける。
String? notificationKindNote(
  AppLocalizations l10n,
  NotificationKind kind, {
  TargetPlatform? platform,
}) => switch (kind) {
  NotificationKind.checkin =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
        ? l10n.notificationKindCheckinNoteIos
        : l10n.notificationKindCheckinNote,
  NotificationKind.streak => l10n.notificationKindStreakNote,
  NotificationKind.rating => null,
  NotificationKind.monthly => l10n.notificationKindMonthlyNote,
  NotificationKind.seasonal => l10n.notificationKindSeasonalNote,
};
