import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../backup/backup_screen.dart';
import '../credits/credits_screen.dart';
import '../home_base/home_base_picker_screen.dart';
import '../home_base/home_base_repository.dart';
import '../notifications/notification_settings_screen.dart';
import '../help/help_screen.dart';
import '../support/contact_support.dart';
import 'app_about.dart';
import 'location_access.dart';

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
    final version = ref.watch(appVersionProvider).value;

    Future<void> openPrivacyPolicy() async {
      final messenger = ScaffoldMessenger.of(context);
      final opened = await ref.read(externalPageOpenerProvider)(
        privacyPolicyUri,
      );
      if (!opened) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.privacyPolicyOpenFailed)),
        );
      }
    }

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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homeBase?.name ?? l10n.homeBaseNotSet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(l10n.homeBaseSettingNote),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const HomeBasePickerScreen()),
          ),
          const LocationAccessTile(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notificationSettings),
            subtitle: Text(l10n.notificationSettingsNote),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const NotificationSettingsScreen()),
          ),
          for (final (title, onTap) in [
            (l10n.backupTitle, () => open(const BackupScreen())),
            (l10n.helpTitle, () => open(const HelpScreen())),
            (l10n.creditsTitle, () => open(const CreditsScreen())),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              trailing: const Icon(Icons.chevron_right),
              onTap: onTap,
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.contactSupport),
            subtitle: Text(l10n.contactSupportNote),
            trailing: const Icon(Icons.mail_outline),
            onTap: () => startContactSupportFlow(context, ref),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.open_in_new),
            onTap: openPrivacyPolicy,
          ),
          if (version != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                version.build.isEmpty
                    ? l10n.appVersionOnly(version.version)
                    : l10n.appVersion(version.version, version.build),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
