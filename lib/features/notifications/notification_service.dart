import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../checkin/checkin_rules.dart';
import 'notification_labels.dart';
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

  /// Android で、スマホの設定で止められている種類（通知そのものを止めていればすべて）。
  /// iOS や、わからないときは空。
  Future<Set<NotificationKind>> blockedKinds();

  /// 予約済みの通知（並び中の通知を除く）を[notifications]に置き換える。
  /// 置き換えられなかったらfalse。
  Future<bool> replaceScheduled(List<ScheduledNotification> notifications);

  /// アプリを開いている間（裏にあるときも）に通知がタップされたときの行き先（payload）。
  Stream<String> get taps;

  /// 通知をタップしてアプリが起動したときの行き先。1回だけ返す。
  Future<String?> takeLaunchPayload();

  /// 開発用: [notification]をすぐに（5秒後に）出す。予約済みの通知はそのまま。
  Future<void> showSoon(ScheduledNotification notification);
}

@immutable
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.payload,
  });

  final int id;
  final NotificationKind kind;
  final DateTime at;
  final String title;
  final String body;
  final String? payload;

  @override
  bool operator ==(Object other) =>
      other is ScheduledNotification &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, kind, at, title, body, payload);
}

const _checkinNotificationId = 1;
const _testNotificationId = 999;

/// Android の通知チャンネルの名前と説明。スマホの設定の「通知」に、この名前で並ぶ。
(String, String?) _channelOf(NotificationKind kind) {
  final l10n = lookupAppLocalizations(const Locale('ja'));
  return (notificationKindLabel(l10n, kind), notificationKindNote(l10n, kind));
}

Importance _channelImportance(NotificationKind kind) =>
    kind == NotificationKind.checkin
    ? Importance.low
    : Importance.defaultImportance;

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
  final _taps = StreamController<String>.broadcast();
  bool _launchTaken = false;

  Future<void> _initialize() => _initialization ??= () async {
    await _plugin.initialize(
      onDidReceiveNotificationResponse: (response) {
        if (response.payload case final payload?) _taps.add(payload);
      },
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _prepareChannels();
  }();

  /// 通知チャンネルは予約より先にすべて作り、はじめからスマホの設定に種類が並ぶようにする。
  /// 「季節のお知らせ」にまとめる前のチャンネルは消す。
  Future<void> _prepareChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    try {
      for (final kind in NotificationKind.values) {
        final (name, description) = _channelOf(kind);
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            kind.key,
            name,
            description: description,
            importance: _channelImportance(kind),
          ),
        );
      }
      for (final key in legacySeasonalKeys) {
        await android.deleteNotificationChannel(channelId: key);
      }
    } catch (e) {
      debugPrint('Notification channel setup failed: $e');
    }
  }

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
            importance: _channelImportance(NotificationKind.checkin),
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

  @override
  Future<Set<NotificationKind>> blockedKinds() async {
    try {
      await _initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return const {};
      if (await android.areNotificationsEnabled() == false) {
        return {...NotificationKind.values};
      }
      final blocked = {
        for (final channel in await android.getNotificationChannels() ?? [])
          if (channel.importance == Importance.none) channel.id,
      };
      return {
        for (final kind in NotificationKind.values)
          if (blocked.contains(kind.key)) kind,
      };
    } catch (e) {
      debugPrint('Notification channel check failed: $e');
      return const {};
    }
  }

  Future<bool> _replacing = Future.value(true);

  // 続けて呼ばれても前の置き換えと混ざらないよう、1つずつ順に行う。
  @override
  Future<bool> replaceScheduled(List<ScheduledNotification> notifications) =>
      _replacing = _replacing.then((_) => _replace(notifications));

  Future<bool> _replace(List<ScheduledNotification> notifications) async {
    try {
      await _initialize();
      final keep = {for (final n in notifications) n.id};
      for (final pending in await _plugin.pendingNotificationRequests()) {
        if (pending.id == _checkinNotificationId ||
            pending.id == _testNotificationId) {
          continue;
        }
        if (!keep.contains(pending.id)) await _plugin.cancel(id: pending.id);
      }
      for (final notification in notifications) {
        await _schedule(notification.id, notification);
      }
      return true;
    } catch (e) {
      debugPrint('Notification schedule failed: $e');
      return false;
    }
  }

  Future<void> _schedule(int id, ScheduledNotification notification) async {
    final (channelName, channelDescription) = _channelOf(notification.kind);
    await _plugin.zonedSchedule(
      id: id,
      // 1回きりの通知は時刻そのもの（瞬間）で決まるので、端末のタイムゾーン名を
      // 調べなくてもUTCで表せば端末の[at]どおりに届く。
      scheduledDate: tz.TZDateTime.from(notification.at, tz.UTC),
      title: notification.title,
      body: notification.body,
      payload: notification.payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          notification.kind.key,
          channelName,
          channelDescription: channelDescription,
          importance: _channelImportance(notification.kind),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // 正確な時刻の予約には追加の許可が要るため、多少ずれてもよい方式にする。
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Stream<String> get taps {
    _initialize();
    return _taps.stream;
  }

  @override
  Future<String?> takeLaunchPayload() async {
    if (_launchTaken) return null;
    _launchTaken = true;
    try {
      await _initialize();
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (e) {
      debugPrint('Notification launch details failed: $e');
      return null;
    }
  }

  @override
  Future<void> showSoon(ScheduledNotification notification) async {
    try {
      await _initialize();
      await _schedule(
        _testNotificationId,
        ScheduledNotification(
          id: _testNotificationId,
          kind: notification.kind,
          at: DateTime.now().add(const Duration(seconds: 5)),
          title: notification.title,
          body: notification.body,
          payload: notification.payload,
        ),
      );
    } catch (e) {
      debugPrint('Test notification failed: $e');
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
