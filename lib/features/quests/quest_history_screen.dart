import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/history_row.dart';
import '../../theme/washi.dart';
import '../records/date_format.dart';
import '../scoring/scoring_providers.dart';
import '../visit_detail/visit_detail_screen.dart';
import 'quest_seal.dart';
import 'quests.dart';

/// 型のこれまでの段。上がった段は日付とその段に届いた1杯。次の段は「？？」で伏せ、その先は出さない。
class QuestHistoryScreen extends ConsumerWidget {
  const QuestHistoryScreen({super.key, required this.questId});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final progress = ref
        .watch(questProgressProvider)
        .where((p) => p.quest.id == questId)
        .firstOrNull;
    if (progress == null) return Scaffold(appBar: AppBar());
    final quest = progress.quest;
    final history = questLevelHistory(progress);

    return Scaffold(
      appBar: AppBar(title: Text(quest.title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Text(
            quest.description,
            style: textTheme.bodyMedium?.copyWith(color: Washi.inkSoft),
          ),
          Text(
            l10n.questHistoryCurrent(progress.current, quest.unit),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.questHistoryNone, style: textTheme.bodyMedium),
            ),
          for (final attainment in history)
            _LevelRow(quest: quest, attainment: attainment),
          // 先の段は、いくつあるかも含めて伏せ、次の段だけを「？？」で置く。
          if (!progress.isMaxLevel) _HiddenLevelRow(quest: quest),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.quest, required this.attainment});

  final Quest quest;
  final QuestLevelAttainment attainment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final visit = attainment.visit;
    return HistoryRow(
      seal: QuestSeal(quest: quest, level: attainment.level, size: 48),
      lines: [
        Text(
          l10n.questHistoryLevel(
            daijiNumber(attainment.level),
            attainment.threshold,
            quest.unit,
          ),
          style: textTheme.titleMedium?.copyWith(fontFamily: Washi.brush),
        ),
        Text(
          l10n.rankHistoryAchievedAt(
            formatDate(visit.visit.eatenAt),
            visit.shop.name,
          ),
          style: textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisitDetailScreen(visitId: visit.visit.id),
        ),
      ),
    );
  }
}

class _HiddenLevelRow extends StatelessWidget {
  const _HiddenLevelRow({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    return HistoryRow(
      seal: QuestSeal(quest: quest, level: 0, size: 48),
      lines: [
        Text(
          AppLocalizations.of(context).rankHistoryHidden,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Washi.faded),
        ),
      ],
    );
  }
}
