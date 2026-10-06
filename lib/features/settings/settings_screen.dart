import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../backup/backup_screen.dart';
import '../credits/credits_screen.dart';
import '../home_base/home_base_picker_screen.dart';
import '../home_base/home_base_repository.dart';
import '../notifications/notification_settings_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// 設定。修行タブの右上の歯車から開く。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));
    final homeBase = ref.watch(currentHomeBaseProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSection)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          8 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.homeBaseTitle),
            subtitle: Text(homeBase?.name ?? l10n.homeBaseNotSet),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const HomeBasePickerScreen()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notificationSettings),
            subtitle: Text(l10n.notificationSettingsNote),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const NotificationSettingsScreen()),
          ),
          for (final (title, screen) in [
            (l10n.backupTitle, const BackupScreen()),
            (l10n.onboardingReplay, const OnboardingScreen()),
            (l10n.creditsTitle, const CreditsScreen()),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(screen),
            ),
        ],
      ),
    );
  }
}
