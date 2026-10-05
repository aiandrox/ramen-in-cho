import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../scoring/scoring_providers.dart';
import 'year_review.dart';
import 'year_review_screen.dart';

/// 年の一覧を開く。[year] を渡すと、その年の紙芝居を一覧の上に重ねて開く（戻ると一覧へ）。
void openYearReview(BuildContext context, {int? year}) {
  final navigator = Navigator.of(context);
  navigator.push(
    MaterialPageRoute<void>(builder: (_) => const YearReviewListScreen()),
  );
  if (year != null) {
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => YearReviewScreen(year: year)),
    );
  }
}

/// 記録のある年を新しい順に並べる。タップでその年の紙芝居を開く。
class YearReviewListScreen extends ConsumerWidget {
  const YearReviewListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scored = ref.watch(scoredVisitsProvider);
    final questProgress = ref.watch(questProgressProvider);

    return Scaffold(
      backgroundColor: Washi.desk,
      appBar: AppBar(
        backgroundColor: Washi.desk,
        title: Text(l10n.reviewListTitle),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          for (final year in reviewYears(scored))
            Builder(
              builder: (context) {
                final review = yearReview(
                  scored,
                  year,
                  questProgress: questProgress,
                );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.reviewEntry(year)),
                  subtitle: Text(
                    l10n.reviewSummaryLine(
                      review.bowls,
                      review.shops,
                      review.points,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => YearReviewScreen(year: year),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
