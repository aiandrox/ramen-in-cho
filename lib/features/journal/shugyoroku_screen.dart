import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../inkan/inkan_stamp.dart';
import '../records/clock.dart';
import '../scoring/scoring_providers.dart';
import '../visit_detail/visit_detail_screen.dart';
import 'shugyoroku.dart';

/// 修行録。1年分の道中記を、月ごとの章に分けて古い順に読む。
class ShugyorokuScreen extends ConsumerStatefulWidget {
  const ShugyorokuScreen({super.key});

  @override
  ConsumerState<ShugyorokuScreen> createState() => _ShugyorokuScreenState();
}

class _ShugyorokuScreenState extends ConsumerState<ShugyorokuScreen> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scored = ref.watch(scoredVisitsProvider);
    final years = shugyorokuYears(scored);
    // 選んだ年の記録が消えたら（削除・日付の変更）、いちばん新しい年に戻す。
    final chosen = _year;
    final year = chosen != null && years.contains(chosen)
        ? chosen
        : (years.isEmpty ? ref.watch(clockProvider)().year : years.first);
    final months = shugyoroku(scored, year);

    return Scaffold(
      backgroundColor: Washi.desk,
      appBar: AppBar(
        backgroundColor: Washi.desk,
        title: Text(l10n.shugyorokuTitle),
      ),
      body: years.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.shugyorokuEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                if (years.length > 1)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final y in years)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(l10n.journeyYear(y)),
                              selected: y == year,
                              onSelected: (_) => setState(() => _year = y),
                            ),
                          ),
                      ],
                    ),
                  ),
                for (final month in months) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                    child: Text(
                      l10n.shugyorokuChapter(year, month.month),
                      style: const TextStyle(
                        fontFamily: Washi.brush,
                        fontSize: 22,
                        color: Washi.ink,
                      ),
                    ),
                  ),
                  for (final entry in month.entries) _EntryPage(entry: entry),
                ],
              ],
            ),
    );
  }
}

class _EntryPage extends StatelessWidget {
  const _EntryPage({required this.entry});

  final ShugyorokuEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scored = entry.scored;
    final at = scored.visit.eatenAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Washi.page,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VisitDetailScreen(visitId: scored.visit.id),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Washi.line)),
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.shugyorokuEntryTitle(
                          at.month,
                          at.day,
                          scored.shop.name,
                        ),
                        style: const TextStyle(
                          fontFamily: Washi.brush,
                          fontSize: 17,
                          color: Washi.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final line in entry.journal)
                        Text(
                          line,
                          style: const TextStyle(
                            fontFamily: Washi.mincho,
                            fontSize: 14,
                            height: 1.7,
                            color: Washi.ink,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkanStamp(scored: scored, size: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
