import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../checkin/checkin_rules.dart';
import 'notification_settings.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(),
);

abstract class NotificationService {
  /// 並んでいる間の通知。Androidでは消えない通知にして経過時間を数え続ける。
  Future<void> showCheckin({
    required String title,
    required String body,
    required DateTime checkedInAt,
  });

  Future<void> cancelCheckin();

  /// 通知の許可を尋ねる（まだ尋ねていないときだけ、OSが画面を出す）。
  Future<void> requestPermission();

  /// 通知が許可されているか。わからなければnull。
  Future<bool?> isPermitted();

  /// 予約済みの通知（並び中の通知を除く）を[notifications]に置き換える。
  Future<void> replaceScheduled(List<ScheduledNotification> notifications);
}

@immutable
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final NotificationKind kind;
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ScheduledNotification &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, kind, at, title, body);
}

const _checkinNotificationId = 1;

/// Android の通知チャンネルの名前と説明。スマホの設定の「通知」に、この名前で並ぶ。
(String, String) _channelOf(NotificationKind kind) {
  final l10n = lookupAppLocalizations(const Locale('ja'));
  return switch (kind) {
    NotificationKind.checkin => (
      l10n.notificationKindCheckin,
      l10n.notificationKindCheckinNote,
    ),
    NotificationKind.streak => (
      l10n.notificationKindStreak,
      l10n.notificationKindStreakNote,
    ),
  };
}

int? _remainingUntilTimeout(DateTime checkedInAt) {
  final remaining = checkedInAt
      .add(checkinTimeout)
      .difference(DateTime.now())
      .inMilliseconds;
  return remaining > 0 ? remaining : null;
}

class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;

  Future<void>? _permissionRequest;

  Future<void> _initialize() => _initialization ??= () async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  /// 許可は、初めて通知を出すとき（並んだとき）に尋ねる。起動しただけでは尋ねない。
  Future<void> _requestPermission() => _permissionRequest ??= () async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true);
  }();

  @override
  Future<void> showCheckin({
    required String title,
    required String body,
    required DateTime checkedInAt,
  }) async {
    try {
      await _initialize();
      await _requestPermission();
      final (channelName, channelDescription) = _channelOf(
        NotificationKind.checkin,
      );
      await _plugin.show(
        id: _checkinNotificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationKind.checkin.key,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            showWhen: true,
            when: checkedInAt.millisecondsSinceEpoch,
            usesChronometer: true,
            // アプリを開かないまま3時間を過ぎても、自動の取り消しに合わせて消えるようにする。
            timeoutAfter: _remainingUntilTimeout(checkedInAt),
          ),
          // アプリを開いている最中に出すので、上から出るバナーは出さず通知センターにだけ置く。
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBanner: false,
            presentSound: false,
            presentList: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Checkin notification failed: $e');
    }
  }

  @override
  Future<void> requestPermission() async {
    try {
      await _initialize();
      await _requestPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  @override
  Future<bool?> isPermitted() async {
    try {
      await _initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) return await android.areNotificationsEnabled();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) return (await ios.checkPermissions())?.isEnabled;
    } catch (e) {
      debugPrint('Notification permission check failed: $e');
    }
    return null;
  }

  Future<void> _replacing = Future.value();

  // 続けて呼ばれても前の置き換えと混ざらないよう、1つずつ順に行う。
  @override
  Future<void> replaceScheduled(List<ScheduledNotification> notifications) =>
      _replacing = _replacing.then((_) => _replace(notifications));

  Future<void> _replace(List<ScheduledNotification> notifications) async {
    try {
      await _initialize();
      final keep = {for (final n in notifications) n.id};
      for (final pending in await _plugin.pendingNotificationRequests()) {
        if (pending.id == _checkinNotificationId) continue;
        if (!keep.contains(pending.id)) await _plugin.cancel(id: pending.id);
      }
      for (final notification in notifications) {
        final (channelName, channelDescription) = _channelOf(notification.kind);
        await _plugin.zonedSchedule(
          id: notification.id,
          // 1回きりの通知は時刻そのもの（瞬間）で決まるので、端末のタイムゾーン名を
          // 調べなくてもUTCで表せば端末の[at]どおりに届く。
          scheduledDate: tz.TZDateTime.from(notification.at, tz.UTC),
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              notification.kind.key,
              channelName,
              channelDescription: channelDescription,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          // 正確な時刻の予約には追加の許可が要るため、多少ずれてもよい方式にする。
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Notification schedule failed: $e');
    }
  }

  @override
  Future<void> cancelCheckin() async {
    try {
      await _initialize();
      await _plugin.cancel(id: _checkinNotificationId);
    } catch (e) {
      debugPrint('Checkin notification cancel failed: $e');
    }
  }
}
