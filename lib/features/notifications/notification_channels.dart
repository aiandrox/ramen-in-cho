import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';
import 'notification_settings.dart';

/// 通知の種類ごとのオン・オフを、スマホの設定（Android の通知のカテゴリ）に任せるか。
/// iOS には種類ごとの設定が無いので、アプリの設定で切り替える。
final usesSystemNotificationCategoriesProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

/// スマホの設定で止められている種類。アプリに戻ってくるたびに読み直す。
final blockedNotificationKindsProvider =
    AsyncNotifierProvider<BlockedNotificationKinds, Set<NotificationKind>>(
      BlockedNotificationKinds.new,
    );

class BlockedNotificationKinds extends AsyncNotifier<Set<NotificationKind>> {
  @override
  Future<Set<NotificationKind>> build() async {
    if (!ref.watch(usesSystemNotificationCategoriesProvider)) return const {};
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(lifecycle.dispose);
    return ref.read(notificationServiceProvider).blockedKinds();
  }

  Future<void> refresh() async {
    final next = await ref.read(notificationServiceProvider).blockedKinds();
    if (!setEquals(next, state.value)) state = AsyncData(next);
  }
}

/// 予約や並び中の通知に使う設定。Android では、スマホの設定で止めた種類をオフとして扱う
/// （1日の上限の枠を使わないよう、予約もしない）。止めた種類を読み込む前はnull。
final effectiveNotificationSettingsProvider = Provider<NotificationSettings?>((
  ref,
) {
  final settings = ref.watch(notificationSettingsProvider);
  if (!ref.watch(usesSystemNotificationCategoriesProvider)) return settings;
  final blocked = ref.watch(blockedNotificationKindsProvider);
  if (!blocked.hasValue) return null;
  return settings.copyWith(disabled: blocked.value);
});
