import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../error_reporting/error_reporting.dart';
import '../record/star_rating.dart';
import '../records/models.dart';
import '../records/record_repository.dart';

/// ★をすぐに保存する。失敗したら知らせる。保存できたら true。
Future<bool> saveRating(
  BuildContext context,
  WidgetRef ref,
  String visitId,
  int rating,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context).editSaveFailed;
  try {
    await ref.read(recordRepositoryProvider).setRating(visitId, rating);
    return true;
  } catch (e, st) {
    reportError(e, st, reason: 'Rating save failed');
    messenger.showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}

/// 食べ終わったあとに★を付けてもらうための案内。★をタップするとその場で保存する。
class RatingPrompt extends ConsumerWidget {
  const RatingPrompt({super.key, required this.entry});

  final VisitWithShop entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerHigh,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
        child: Column(
          children: [
            Text(
              l10n.ratingPrompt(entry.shop.name),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            StarRating(
              rating: null,
              size: 32,
              onChanged: (rating) async {
                final messenger = ScaffoldMessenger.of(context);
                if (await saveRating(context, ref, entry.visit.id, rating)) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.ratingSaved('★' * rating))),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
