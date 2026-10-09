import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi_buttons.dart';
import '../words/words.dart';

/// 撤退を記録するか確かめる。記録するならメモ（空でもよい）、やめるならnullを返す。
Future<String?> showRetreatDialog(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const _RetreatDialog(),
);

/// 撤退を残したあとの知らせ（並び中の帯からでも、判子の窓からでも同じ）。
String retreatSavedText(AppLocalizations l10n, String memo, String visitId) =>
    '${l10n.retreatSaved}\n${retreatConsolation(memo, visitId)}';

class _RetreatDialog extends StatefulWidget {
  const _RetreatDialog();

  @override
  State<_RetreatDialog> createState() => _RetreatDialogState();
}

class _RetreatDialogState extends State<_RetreatDialog> {
  final _memoController = TextEditingController();

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reasons = [
      l10n.retreatReasonSoldOut,
      l10n.retreatReasonClosed,
      l10n.retreatReasonNoTime,
    ];

    return AlertDialog(
      title: Text(l10n.retreatTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.retreatMessage),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final reason in reasons)
                  ActionChip(
                    label: Text(reason),
                    onPressed: () =>
                        setState(() => _memoController.text = reason),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              decoration: InputDecoration(
                labelText: l10n.retreatMemoLabel,
                helperText: l10n.optionalHelper,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        KeshiFuda(
          onPressed: () =>
              Navigator.of(context).pop(_memoController.text.trim()),
          child: Text(l10n.retreatConfirm),
        ),
      ],
    );
  }
}
