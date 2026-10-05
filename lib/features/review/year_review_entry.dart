import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../records/clock.dart';
import '../scoring/scoring_providers.dart';
import 'year_review.dart';
import 'year_review_list_screen.dart';

/// 修行タブの「年の振り返り」。年の一覧を開く。記録が1件も無いうちは出さない。
class YearReviewEntry extends ConsumerWidget {
  const YearReviewEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(scoredVisitsProvider).isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.reviewListTitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openYearReview(context),
    );
  }
}

/// 12月と1月に、一覧の上で振り返りを勧める。×で閉じる（アプリを開き直すとまた出る）。
class YearReviewInviteCard extends ConsumerStatefulWidget {
  const YearReviewInviteCard({super.key});

  @override
  ConsumerState<YearReviewInviteCard> createState() =>
      _YearReviewInviteCardState();
}

class _YearReviewInviteCardState extends ConsumerState<YearReviewInviteCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final year = reviewSeasonYear(ref.watch(currentTimeProvider));
    if (_dismissed ||
        year == null ||
        !reviewYears(ref.watch(scoredVisitsProvider)).contains(year)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        Card(
          elevation: 0,
          color: Washi.page,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Washi.ai),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: InkWell(
            onTap: () => openYearReview(context, year: year),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 44, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.reviewInvite(year),
                    style: const TextStyle(
                      fontFamily: Washi.brush,
                      fontSize: 18,
                      color: Washi.ai,
                    ),
                  ),
                  Text(l10n.reviewInviteSub, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            tooltip: l10n.reviewDismiss,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _dismissed = true),
          ),
        ),
      ],
    );
  }
}
