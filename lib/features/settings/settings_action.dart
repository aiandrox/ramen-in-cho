import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'settings_screen.dart';

/// 下のタブの各画面の右上に置く、設定を開く歯車。
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).settingsSection,
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
    );
  }
}
