import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../records/date_format.dart';
import '../scoring/scoring_providers.dart';
import '../visit_detail/visit_detail_screen.dart';
import 'quest_seal.dart';
import 'quests.dart';

/// 型のこれまでの段。上がった段は日付とその段に届いた1杯、まだの段は数を伏せる。
class QuestHistoryScreen extends ConsumerWidget {
  const QuestHistoryScreen({super.key, required this.questId});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final progress = ref
        .watch(questProgressProvider)
        .firstWhere((p) => p.quest.id == questId);
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
          const SizedBox(height: 8),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.questHistoryNone, style: textTheme.bodyMedium),
            ),
          for (final attainment in history)
            _LevelRow(quest: quest, attainment: attainment),
          for (var level = history.length + 1; level <= quest.maxLevel; level++)
            _HiddenLevelRow(quest: quest),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.seal, required this.lines, this.onTap});

  final Widget seal;
  final List<Widget> lines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Washi.line, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(width: 64, child: Center(child: seal)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines,
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Washi.faded),
          ],
        ),
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
    return _Row(
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
    return _Row(
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
