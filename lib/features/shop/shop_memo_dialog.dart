import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi_buttons.dart';

/// 店の覚え書きを書く。保存するなら書いた内容、やめるならnullを返す。
Future<String?> showShopMemoDialog(BuildContext context, String initial) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ShopMemoDialog(initial: initial),
    );

class _ShopMemoDialog extends StatefulWidget {
  const _ShopMemoDialog({required this.initial});

  final String initial;

  @override
  State<_ShopMemoDialog> createState() => _ShopMemoDialogState();
}

class _ShopMemoDialogState extends State<_ShopMemoDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.shopMemoSection),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: l10n.shopMemoHint,
          helperText: l10n.shopMemoHelper,
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        AiFuda(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.editSave),
        ),
      ],
    );
  }
}
