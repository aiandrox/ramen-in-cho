import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../records/clock.dart';
import '../records/record_repository.dart';
import 'wish_repository.dart';
import '../../theme/washi_buttons.dart';

class WishText {
  const WishText({
    required this.name,
    required this.trigger,
    required this.note,
  });

  final String name;
  final String trigger;
  final String note;
}

/// 願を書き留める・書き直す。[name]を渡すと店名は変えられない（地図や店のページから掛けるとき）。
Future<WishText?> showWishDialog(
  BuildContext context, {
  String? name,
  String trigger = '',
  String note = '',
  bool isEditing = false,
}) => showDialog<WishText>(
  context: context,
  builder: (_) => _WishDialog(
    name: name,
    trigger: trigger,
    note: note,
    isEditing: isEditing,
  ),
);

/// [shop]に願を掛ける。きっかけ・ひとことを尋ね、書き留めたら知らせる。
Future<void> addWishFor(
  BuildContext context,
  WidgetRef ref,
  ShopInput shop,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(wishRepositoryProvider);
  final now = ref.read(clockProvider)();
  final text = await showWishDialog(context, name: shop.name);
  if (text == null) return;
  try {
    await repository.addWish(
      shop: shop,
      trigger: text.trigger,
      note: text.note,
      now: now,
    );
    messenger.showSnackBar(SnackBar(content: Text(l10n.wishAdded(shop.name))));
  } catch (e) {
    debugPrint('Wish save failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(l10n.wishSaveFailed)));
  }
}

class _WishDialog extends StatefulWidget {
  const _WishDialog({
    required this.name,
    required this.trigger,
    required this.note,
    required this.isEditing,
  });

  final String? name;
  final String trigger;
  final String note;
  final bool isEditing;

  @override
  State<_WishDialog> createState() => _WishDialogState();
}

class _WishDialogState extends State<_WishDialog> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _trigger = TextEditingController(text: widget.trigger);
  late final _note = TextEditingController(text: widget.note);

  @override
  void dispose() {
    _name.dispose();
    _trigger.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      WishText(
        name: name,
        trigger: _trigger.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fixedName = widget.name;
    return AlertDialog(
      title: Text(widget.isEditing ? l10n.wishEditTitle : l10n.wishAddTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fixedName != null)
              Text(fixedName, style: Theme.of(context).textTheme.titleMedium)
            else
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.wishShopName),
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _trigger,
              decoration: InputDecoration(
                labelText: l10n.wishTrigger,
                hintText: l10n.wishTriggerHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.wishNote,
                hintText: l10n.wishNoteHint,
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
        AiFuda(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: Text(widget.isEditing ? l10n.editSave : l10n.wishAddButton),
        ),
      ],
    );
  }
}
