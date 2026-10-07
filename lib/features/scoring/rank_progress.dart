import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../inkan/inkan_stamp.dart';
import 'rank_history_screen.dart';
import 'rank_labels.dart';
import 'ranks.dart';
import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';

/// 段位と修行点、次の段位までの進み具合。タップで昇段の記録を開く。
class RankProgress extends StatelessWidget {
  const RankProgress({
    super.key,
    required this.totalPoints,
    required this.rank,
    this.compact = false,
  });

  final int totalPoints;

  /// 今の段位。1杯で1つずつしか上がらないので、累計だけでは決まらない。
  final AdventurerRank rank;

  /// 印帳の上では、次の段位まであと何点かを出さない（修行タブで見る）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final next = rank.next;
    final progress = next == null
        ? 1.0
        : ((totalPoints - rank.requiredPoints) /
                  (next.requiredPoints - rank.requiredPoints))
              .clamp(0.0, 1.0);

    final row = Row(
      children: [
        RankSeal(label: adventurerRankLabel(l10n, rank), fontSize: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.totalPoints(totalPoints),
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  if (!compact)
                    Text(
                      next == null
                          ? l10n.maxRank
                          : totalPoints >= next.requiredPoints
                          ? l10n.nextRankReady(adventurerRankLabel(l10n, next))
                          : l10n.nextRank(
                              adventurerRankLabel(l10n, next),
                              next.requiredPoints - totalPoints,
                            ),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                color: colors.onSurface,
                backgroundColor: Washi.line.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
      ],
    );
    return InkWell(
      onTap: () {
        logAnalytics(context, AnalyticsEvents.featureOpened('rank_history'));
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RankHistoryScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: row,
      ),
    );
  }
}
