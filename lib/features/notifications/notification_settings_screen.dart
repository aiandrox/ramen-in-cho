import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../settings/system_settings.dart';
import 'notification_channels.dart';
import 'notification_labels.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

/// 通知の設定。連続記録を知らせる曜日・時刻と、夜は知らせないかを選ぶ。
/// 種類ごとのオン・オフは、iOS ではここで、Android ではスマホの設定（通知のカテゴリ）で切り替える。
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  // スマホの設定で許可して戻ってきたときに、案内を消す。
  late final _lifecycle = AppLifecycleListener(onResume: _checkPermission);
  bool? _permitted;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _checkPermission();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final permitted = await ref.read(notificationServiceProvider).isPermitted();
    if (mounted) setState(() => _permitted = permitted);
  }

  /// まだ一度も尋ねていなければ OS に尋ね、それでも許可が無ければスマホの設定を開く。
  /// iOS は一度も尋ねていないアプリの通知の項目を設定に出さないため。
  Future<void> _allow() async {
    await ref.read(notificationServiceProvider).requestPermission();
    await _checkPermission();
    if (_permitted == false) await openNotificationSettings();
  }

  Future<void> _pickStreakTime(NotificationSettings settings) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.streakHour,
        minute: settings.streakMinute,
      ),
    );
    if (time == null || !mounted) return;
    ref
        .read(notificationSettingsProvider.notifier)
        .update(
          settings.copyWith(streakHour: time.hour, streakMinute: time.minute),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(notificationSettingsProvider);
    final controller = ref.read(notificationSettingsProvider.notifier);
    final systemCategories = ref.watch(
      usesSystemNotificationCategoriesProvider,
    );
    final streakOn =
        ref
            .watch(effectiveNotificationSettingsProvider)
            ?.isEnabled(NotificationKind.streak) ??
        false;
    final streakTime = _StreakTimePicker(
      settings: settings,
      onWeekday: (weekday) =>
          controller.update(settings.copyWith(streakWeekday: weekday)),
      onPickTime: () => _pickStreakTime(settings),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettings)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          8 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          if (_permitted == false)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: Text(l10n.notificationNotPermitted),
                subtitle: Text(l10n.notificationNotPermittedNote),
                trailing: const Icon(Icons.open_in_new),
                onTap: _allow,
              ),
            ),
          if (systemCategories && streakOn) streakTime,
          if (!systemCategories)
            for (final kind in NotificationKind.values) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(notificationKindLabel(l10n, kind)),
                subtitle: switch (notificationKindNote(l10n, kind)) {
                  final note? => Text(note),
                  null => null,
                },
                value: settings.isEnabled(kind),
                onChanged: (on) => controller.setEnabled(kind, on),
              ),
              if (kind == NotificationKind.streak && streakOn) streakTime,
            ],
          if (!systemCategories || streakOn) const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notificationQuietNight),
            subtitle: Text(l10n.notificationQuietNightNote),
            value: settings.quietNight,
            onChanged: (on) =>
                controller.update(settings.copyWith(quietNight: on)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notificationOsSettings),
            subtitle: Text(
              systemCategories
                  ? l10n.notificationOsSettingsKindsNote
                  : l10n.notificationOsSettingsNote,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: openNotificationSettings,
          ),
          if (kDebugMode) const _PlannedNotificationsDebug(),
        ],
      ),
    );
  }
}

class _StreakTimePicker extends StatelessWidget {
  const _StreakTimePicker({
    required this.settings,
    required this.onWeekday,
    required this.onPickTime,
  });

  final NotificationSettings settings;
  final ValueChanged<int> onWeekday;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = TimeOfDay(
      hour: settings.streakHour,
      minute: settings.streakMinute,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notificationStreakTime),
            subtitle: Text(
              l10n.notificationStreakTimeValue(
                l10n.weekdayShort('${settings.streakWeekday}'),
                MaterialLocalizations.of(context)
                    .formatTimeOfDay(time, alwaysUse24HourFormat: true),
              ),
            ),
            trailing: const Icon(Icons.schedule),
            onTap: onPickTime,
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var weekday = 1; weekday <= 7; weekday++)
                ChoiceChip(
                  label: Text(l10n.weekdayShort('$weekday')),
                  selected: settings.streakWeekday == weekday,
                  onSelected: (_) => onWeekday(weekday),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 開発用（デバッグビルドだけ）: 予約中の通知を並べ、タップで5秒後に出して文言や行き先を確かめる。
class _PlannedNotificationsDebug extends ConsumerWidget {
  const _PlannedNotificationsDebug();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plans = ref.watch(notificationPlanProvider) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text(l10n.notificationDebugTitle),
        Text(
          l10n.notificationDebugNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final plan in plans)
          if (describeNotification(l10n, plan) case final notification)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(notification.title),
              subtitle: Text('${plan.at}\n${notification.body}'),
              onTap: () =>
                  ref.read(notificationServiceProvider).showSoon(notification),
            ),
      ],
    );
  }
}
