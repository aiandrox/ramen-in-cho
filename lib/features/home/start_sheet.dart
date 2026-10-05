import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';
import '../../theme/washi_sheet.dart';

enum StartChoice { eaten, queue }

/// 真ん中の「麺」を押したときに、記録するか並び始めるかを選ぶ窓。
Future<StartChoice?> showStartSheet(BuildContext context) =>
    showWashiSheet<StartChoice>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StartChoiceButton(
                icon: Icons.ramen_dining,
                title: l10n.startEatenTitle,
                body: l10n.startEatenBody,
                onPressed: () => Navigator.of(context).pop(StartChoice.eaten),
              ),
              const SizedBox(height: 16),
              _StartChoiceButton(
                icon: Icons.groups,
                title: l10n.startQueueTitle,
                body: l10n.startQueueBody,
                onPressed: () => Navigator.of(context).pop(StartChoice.queue),
              ),
            ],
          ),
        );
      },
    );

class _StartChoiceButton extends StatelessWidget {
  const _StartChoiceButton({
    required this.icon,
    required this.title,
    required this.body,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OutlinedButton(
      style: FudaStyle.sumi(height: 96, expand: true),
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: Washi.brush,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: textTheme.bodyMedium?.copyWith(color: Washi.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
