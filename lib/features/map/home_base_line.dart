import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../home_base/home_base_picker_screen.dart';
import '../home_base/home_base_repository.dart';

/// 今の拠点を1行で見せる。まだ無ければ、拠点を決めるよう勧める。タップで拠点を決める画面へ。
class HomeBaseLine extends ConsumerWidget {
  const HomeBaseLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final base = ref.watch(currentHomeBaseProvider);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<bool>(builder: (_) => const HomeBasePickerScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              base == null ? Icons.home_outlined : Icons.home,
              size: 16,
              color: base == null ? colors.onSurfaceVariant : colors.primary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                base == null ? l10n.homeBaseNone : l10n.homeBaseLine(base.name),
                style: textTheme.bodySmall,
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
