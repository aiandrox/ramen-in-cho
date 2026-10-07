import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../records/clock.dart';
import '../records/date_format.dart';
import '../records/labels.dart';
import '../records/record_repository.dart';
import '../scoring/rank_labels.dart';
import '../scoring/ranks.dart';
import '../scoring/scoring_providers.dart';
import 'stats.dart';
import '../visit_detail/visit_detail_screen.dart';
import '../records/models.dart';
import '../../theme/ink_wear.dart';
import '../../theme/washi.dart';

/// 杯数・自己ベスト・系統の割合などの数字。修行タブの中に並べる。
class StatsSections extends ConsumerWidget {
  const StatsSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final visits = ref.watch(visitsProvider);
    final scored = ref.watch(scoredVisitsProvider);
    final total = totalBowls(scored);
    final thisYear = bowlsInYear(scored, ref.watch(currentTimeProvider).year);

    if (visits.hasError) return Text(l10n.homeLoadFailed);
    if (visits.isLoading && !visits.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (total == 0) return Text(l10n.statsEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.statsBowls),
        Text(
          l10n.statsBowlsLine(thisYear, total),
          style: textTheme.titleMedium,
        ),
        ..._bests(context, l10n, textTheme, personalBests(scored)),
        const SizedBox(height: 24),
        SectionTitle(l10n.statsStyles),
        StyleBreakdown(shares: styleShares(scored)),
        const SizedBox(height: 24),
        SectionTitle(l10n.statsFrequent),
        if (frequentShops(scored).isEmpty)
          Text(l10n.statsFrequentNone, style: textTheme.bodyMedium),
        for (final frequent in frequentShops(scored))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(frequent.shop.name),
            trailing: _Value(
              Text(l10n.bowls(frequent.count), style: textTheme.bodyLarge),
            ),
            onTap: () => _openShop(context, frequent.lastVisitId),
          ),
        const SizedBox(height: 24),
        SectionTitle(l10n.statsShopRanks),
        for (final ranked in rankedShops(scored).take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: _RankBadge(rank: ranked.rank),
            title: Text(ranked.shop.name),
            trailing: _Value(
              Text(
                l10n.statsBestPoints(ranked.bestPoints),
                style: textTheme.bodyMedium,
              ),
            ),
            onTap: () => _openShop(context, ranked.bestVisitId),
          ),
      ],
    );
  }
}

void _openShop(BuildContext context, String visitId) => Navigator.of(context)
    .push(
      MaterialPageRoute<void>(
        builder: (_) => VisitDetailScreen(visitId: visitId),
      ),
    );

class _Value extends StatelessWidget {
  const _Value(this.value);

  final Widget value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      value,
      Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ],
  );
}

List<Widget> _bests(
  BuildContext context,
  AppLocalizations l10n,
  TextTheme textTheme,
  PersonalBests bests,
) {
  ListTile row(String label, PersonalBest best, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label),
    subtitle: Text(
      l10n.bestDetail(
        best.entry.shop.name,
        formatDate(best.entry.visit.eatenAt),
      ),
    ),
    trailing: _Value(Text(value, style: textTheme.titleMedium)),
    onTap: () => _openShop(context, best.entry.visit.id),
  );
  final rows = [
    if (bests.longestWait case final best?)
      row(l10n.bestLongestWait, best, l10n.minutes(best.value)),
    if (bests.highestPoints case final best?)
      row(l10n.bestHighestPoints, best, l10n.points(best.value)),
    if (bests.mostRetreats case final best?)
      row(l10n.bestMostRetreats, best, l10n.retreatCount(best.value)),
  ];
  if (rows.isEmpty) return const [];
  return [const SizedBox(height: 24), SectionTitle(l10n.statsBests), ...rows];
}

/// 系統ごとの色。隣り合っても見分けやすいよう、明るさも変えた和の色にする。
Color styleColor(RamenStyle? style) => switch (style) {
  RamenStyle.shoyu => const Color(0xFF6B3A22),
  RamenStyle.miso => const Color(0xFFB4793A),
  RamenStyle.shio => const Color(0xFF7FA7B8),
  RamenStyle.tonkotsu => const Color(0xFFE3C26F),
  RamenStyle.iekei => Washi.shu,
  RamenStyle.jiro => const Color(0xFF3F6B3F),
  RamenStyle.tsukemen => const Color(0xFF2E4A6B),
  RamenStyle.shirunashi => const Color(0xFF7E5A96),
  RamenStyle.other => Washi.faded,
  null => const Color(0xFFD8CDB8),
};

/// 全体を100とした1本の帯を系統ごとに色分けし、下に色・系統・杯数・割合を並べる。
class StyleBreakdown extends StatelessWidget {
  const StyleBreakdown({super.key, required this.shares});

  final List<StyleShare> shares;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    String label(RamenStyle? style) =>
        style == null ? l10n.styleUnset : styleLabel(l10n, style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: [
            for (final share in shares)
              '${label(share.style)} ${l10n.percent((share.ratio * 100).round())}',
          ].join('、'),
          child: ExcludeSemantics(
            child: SizedBox(
              height: 28,
              child: Row(
                children: [
                  for (final (i, share) in shares.indexed)
                    Expanded(
                      flex: share.count,
                      child: Container(
                        decoration: BoxDecoration(
                          color: styleColor(share.style),
                          border: i == 0
                              ? null
                              : const Border(
                                  left: BorderSide(color: Washi.page),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final share in shares)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: styleColor(share.style),
                    border: Border.all(color: Washi.line),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label(share.style), style: textTheme.bodyMedium),
                ),
                Text(l10n.bowls(share.count), style: textTheme.bodyMedium),
                SizedBox(
                  width: 56,
                  child: Text(
                    l10n.percent((share.ratio * 100).round()),
                    style: textTheme.bodyMedium?.copyWith(color: Washi.inkSoft),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final ShopRank rank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTop = rank == ShopRank.s;
    return InkWear(
      seed: inkSeed('rank:${rank.name}'),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isTop ? Washi.shu : Washi.page,
          border: Border.all(color: Washi.shu, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          shopRankLabel(l10n, rank),
          style: TextStyle(
            fontFamily: Washi.brush,
            fontSize: 18,
            color: isTop ? Washi.page : Washi.shu,
          ),
        ),
      ),
    );
  }
}
