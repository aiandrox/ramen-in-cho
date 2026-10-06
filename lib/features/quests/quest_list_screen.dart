import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/even_grid.dart';
import '../../theme/washi.dart';
import '../scoring/scoring_providers.dart';
import '../visit_detail/visit_detail_screen.dart';
import 'quest_seal.dart';
import 'quests.dart';
import '../../theme/washi_buttons.dart';
import '../../theme/washi_sheet.dart';

/// 型と秘伝の一覧。修行タブの中に並べる。
class QuestSections extends ConsumerWidget {
  const QuestSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(questProgressProvider);
    final standing = [
      for (final progress in all)
        if (progress.quest.kind == QuestKind.standing) progress,
    ];
    final spot = [
      for (final progress in all)
        if (progress.quest.kind == QuestKind.spot) progress,
    ];
    // 秘伝は会得したものだけを、会得した順に印で並べる（まだのものは隠しておく）。
    final achieved =
        [
          for (final progress in spot)
            if (progress.isAchieved) progress,
        ]..sort(
          (a, b) => a.levelAchievedAt.first.compareTo(b.levelAchievedAt.first),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: l10n.questStanding),
        for (final progress in standing) _QuestCard(progress: progress),
        const SizedBox(height: 24),
        _SectionHeader(title: l10n.questSpot),
        if (achieved.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.questSpotNone,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Washi.inkSoft),
            ),
          )
        else
          _SpotGrid(achieved: achieved),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SectionTitle(title),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.progress});

  final QuestProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final quest = progress.quest;
    final isSpot = quest.kind == QuestKind.spot;
    final next = progress.nextThreshold;
    final count = isSpot
        ? null
        : next == null
        ? l10n.questMaxLevel
        : l10n.questCount(progress.current, quest.unit);

    // 印・名前・数だけ。会得した日などは出さない。
    return Card(
      elevation: 0,
      color: progress.isAchieved
          ? colors.surfaceContainerHigh
          : colors.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        child: Row(
          children: [
            QuestSeal(quest: quest, level: progress.level, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontFamily: Washi.brush,
                    ),
                  ),
                  Text(
                    quest.description,
                    style: textTheme.bodySmall?.copyWith(color: Washi.inkSoft),
                  ),
                ],
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Text(
                count,
                style: textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 秘伝の印を、1行に4つずつ横幅いっぱいにそろえて並べる。
class _SpotGrid extends StatelessWidget {
  const _SpotGrid({required this.achieved});

  final List<QuestProgress> achieved;

  static const _columns = 4;
  static const _spacing = 8.0;

  @override
  Widget build(BuildContext context) {
    return EvenGrid(
      columns: _columns,
      spacing: _spacing,
      runSpacing: _spacing,
      itemCount: achieved.length,
      itemBuilder: (context, index, width) =>
          _SpotSeal(progress: achieved[index], width: width),
    );
  }
}

/// 会得した秘伝の印。タップすると、どの店で会得したかを見られる。
class _SpotSeal extends StatelessWidget {
  const _SpotSeal({required this.progress, required this.width});

  final QuestProgress progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    final quest = progress.quest;
    return InkWell(
      onTap: () => showWashiSheet<void>(
        context: context,
        builder: (_) => _SpotDetails(progress: progress),
      ),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              QuestSeal(
                quest: quest,
                level: progress.level,
                size: 64,
                achievedAt: progress.levelAchievedAt.first,
              ),
              const SizedBox(height: 6),
              Text(
                quest.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotDetails extends StatelessWidget {
  const _SpotDetails({required this.progress});

  final QuestProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final quest = progress.quest;
    final by = progress.levelAchievedBy.firstOrNull;
    final homeBase = progress.achievedHomeBase;
    // どの秘伝でも同じ高さにし、ボタンの位置もそろえる（説明や店名の長さで変わらないように）。
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        height: 400,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              QuestSeal(
                quest: quest,
                level: progress.level,
                size: 112,
                achievedAt: progress.levelAchievedAt.first,
              ),
              const SizedBox(height: 12),
              Text(
                quest.title,
                style: textTheme.titleLarge?.copyWith(fontFamily: Washi.brush),
              ),
              const SizedBox(height: 4),
              Text(
                quest.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: Washi.inkSoft),
              ),
              const SizedBox(height: 16),
              Text(
                by != null
                    ? l10n.questSpotAchievedShop(by.shop.name)
                    : l10n.questSpotAchievedHomeBase(homeBase?.name ?? ''),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge,
              ),
              const Spacer(),
              if (by != null)
                SumiFuda(
                  onPressed: () {
                    closeWashiSheet<void>(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VisitDetailScreen(visitId: by.visit.id),
                      ),
                    );
                  },
                  child: Text(l10n.questSpotOpenShop),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
