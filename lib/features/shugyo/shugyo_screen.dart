import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../journal/shugyoroku_screen.dart';
import '../map/home_base_line.dart';
import '../prefecture/prefecture_book_screen.dart';
import '../quests/quest_list_screen.dart';
import '../review/year_review_entry.dart';
import '../scoring/rank_progress.dart';
import '../scoring/scoring_providers.dart';
import '../settings/settings_action.dart';
import '../stats/stats_screen.dart';
import '../streak/streak_line.dart';
import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';

/// 修行タブの下半分に出すもの。切り替えで1つだけを出す。
enum _Section { quests, records, stats }

/// 修行の記録をひとまとめにした画面。上に段位と、小さく連続記録・拠点。その下の切り替えで
/// 型と秘伝・記録・統計のどれか1つを出す（画面は移らない）。選んだものは、アプリを開いている間だけ覚える。設定は右上の歯車から開く。
class ShugyoScreen extends ConsumerStatefulWidget {
  const ShugyoScreen({super.key});

  @override
  ConsumerState<ShugyoScreen> createState() => _ShugyoScreenState();
}

class _ShugyoScreenState extends ConsumerState<ShugyoScreen> {
  var _section = _Section.quests;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shugyoTitle),
        actions: const [SettingsAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          RankProgress(
            totalPoints: ref.watch(totalPointsProvider),
            rank: ref.watch(currentRankProvider),
          ),
          const StreakLine(),
          const HomeBaseLine(),
          const SizedBox(height: 20),
          _SectionSwitch(
            selected: _section,
            onSelected: (section) => setState(() => _section = section),
          ),
          const SizedBox(height: 16),
          switch (_section) {
            _Section.quests => const QuestSections(),
            _Section.records => const _RecordsSection(),
            _Section.stats => const StatsSections(),
          },
        ],
      ),
    );
  }
}

/// 「型と秘伝｜記録｜統計」の切り替え。選ぶ札（角を落とした木札）を同じ幅で横に並べる。
class _SectionSwitch extends StatelessWidget {
  const _SectionSwitch({required this.selected, required this.onSelected});

  final _Section selected;
  final ValueChanged<_Section> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        for (final (i, section) in _Section.values.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: Text(
                  switch (section) {
                    _Section.quests => l10n.shugyoSectionQuests,
                    _Section.records => l10n.shugyoSectionRecords,
                    _Section.stats => l10n.shugyoSectionStats,
                  },
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              selected: section == selected,
              onSelected: (_) => onSelected(section),
            ),
          ),
        ],
      ],
    );
  }
}

/// 記録: 修行録・都道府県の印帳・年の振り返り。
class _RecordsSection extends StatelessWidget {
  const _RecordsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.shugyorokuTitle),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shugyorokuOpen),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            logAnalytics(context, AnalyticsEvents.featureOpened('shugyoroku'));
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ShugyorokuScreen()),
            );
          },
        ),
        const PrefectureBookEntry(),
        const YearReviewEntry(),
      ],
    );
  }
}
