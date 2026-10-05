import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../backup/backup_screen.dart';
import '../credits/credits_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// 設定。修行タブの右上の歯車から開く。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

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
