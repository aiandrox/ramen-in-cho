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
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../streak/healthy_life_card.dart';
import '../streak/streak_line.dart';

/// 修行の記録をひとまとめにした画面。段位 → 型と秘伝 → 数字の順に並べ、設定は右上の歯車から開く。
class ShugyoScreen extends ConsumerWidget {
  const ShugyoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shugyoTitle),
        actions: [
          IconButton(
            tooltip: l10n.settingsSection,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => open(const SettingsScreen()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          RankProgress(
            totalPoints: ref.watch(totalPointsProvider),
            rank: ref.watch(currentRankProvider),
          ),
          const StreakLine(),
          const HealthyLifeCard(),
          const HomeBaseLine(),
          const SizedBox(height: 24),
          const QuestSections(),
          const SizedBox(height: 32),
          SectionTitle(l10n.shugyorokuTitle),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.shugyorokuOpen),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const ShugyorokuScreen()),
          ),
          const PrefectureBookEntry(),
          const YearReviewEntry(),
          const SizedBox(height: 32),
          const StatsSections(),
        ],
      ),
    );
  }
}
