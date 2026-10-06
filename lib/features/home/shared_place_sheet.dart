import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi_sheet.dart';
import 'start_sheet.dart';

enum SharedPlaceChoice { record, wish }

/// 地図アプリから店が共有されたときに、ここで食べた記録にするか、願を掛けるかを選ぶ窓。
Future<SharedPlaceChoice?> showSharedPlaceSheet(
  BuildContext context, {
  required String shopName,
}) => showWashiSheet<SharedPlaceChoice>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shopName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                shopName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          StartChoiceButton(
            icon: Icons.ramen_dining,
            title: l10n.sharedPlaceRecordTitle,
            body: l10n.sharedPlaceRecordBody,
            onPressed: () => closeWashiSheet(context, SharedPlaceChoice.record),
          ),
          const SizedBox(height: 16),
          StartChoiceButton(
            icon: Icons.bookmark_add_outlined,
            title: l10n.sharedPlaceWishTitle,
            body: l10n.sharedPlaceWishBody,
            onPressed: () => closeWashiSheet(context, SharedPlaceChoice.wish),
          ),
        ],
      ),
    );
  },
);
