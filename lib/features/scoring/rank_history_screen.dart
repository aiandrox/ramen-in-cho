import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/history_row.dart';
import '../../theme/washi.dart';
import '../inkan/inkan_stamp.dart';
import '../records/date_format.dart';
import '../visit_detail/visit_detail_screen.dart';
import '../words/words.dart';
import 'rank_history.dart';
import 'rank_labels.dart';
import 'ranks.dart';
import 'scoring_providers.dart';

/// 昇段の記録。上がった段位は日付と1杯、次の段位は名前と残りの点、その先は伏せる。
class RankHistoryScreen extends ConsumerWidget {
  const RankHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = rankHistory(ref.watch(scoredVisitsProvider));
    final total = ref.watch(totalPointsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rankHistoryTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          for (final rank in AdventurerRank.values)
            if (rank.index < history.length)
              _ReachedRow(attainment: history[rank.index])
            else if (rank.index == history.length)
              _NextRow(rank: rank, remaining: rank.requiredPoints - total)
            else
              const _HiddenRow(),
        ],
      ),
    );
  }
}

class _ReachedRow extends StatelessWidget {
  const _ReachedRow({required this.attainment});

  final RankAttainment attainment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final visit = attainment.visit;
    return HistoryRow(
      seal: RankSeal(
        label: adventurerRankLabel(l10n, attainment.rank),
        fontSize: 15,
      ),
      lines: [
        if (visit == null)
          Text(
            l10n.rankHistoryNoRecord,
            style: textTheme.bodySmall?.copyWith(color: Washi.inkSoft),
          )
        else
          Text(
            l10n.rankHistoryAchievedAt(
              formatDate(visit.visit.eatenAt),
              visit.shop.name,
            ),
            style: textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 2),
        Text(
          masterWords(attainment.rank),
          style: textTheme.bodyMedium?.copyWith(fontFamily: Washi.brush),
        ),
      ],
      onTap: visit == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VisitDetailScreen(visitId: visit.visit.id),
              ),
            ),
    );
  }
}

class _NextRow extends StatelessWidget {
  const _NextRow({required this.rank, required this.remaining});

  final AdventurerRank rank;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HistoryRow(
      seal: RankSeal(
        label: adventurerRankLabel(l10n, rank),
        fontSize: 15,
        color: Washi.faded,
      ),
      lines: [
        Text(
          remaining <= 0
              ? l10n.rankHistoryReady
              : l10n.rankHistoryRemaining(remaining),
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Washi.faded),
        ),
      ],
    );
  }
}

class _HiddenRow extends StatelessWidget {
  const _HiddenRow();

  @override
  Widget build(BuildContext context) {
    return HistoryRow(
      seal: RankSeal(
        label: AppLocalizations.of(context).rankHistoryHidden,
        fontSize: 15,
        color: Washi.line,
      ),
      lines: const [],
    );
  }
}
