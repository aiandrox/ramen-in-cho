import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../inkan/inkan.dart';
import '../../l10n/app_localizations.dart';
import '../scoring/scoring_providers.dart';
import 'journey.dart';

/// 今の拠点を1行で見せる。まだ無ければ、拠点のでき方を見せる。
class HomeBaseLine extends ConsumerWidget {
  const HomeBaseLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final base = currentHomeBase(ref.watch(scoredVisitsProvider));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
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
              base == null
                  ? l10n.homeBaseNone(proseNumber(homeBaseBowls))
                  : l10n.homeBaseLine(base.shop.name, base.bowls),
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
