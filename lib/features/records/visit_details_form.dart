import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'models.dart';
import 'style_tiles.dart';

/// 系統・限定・待ち時間・「この一杯について」・「店の覚え書き」の入力欄。記録画面と編集画面で共有する。
class VisitDetailsForm extends StatelessWidget {
  const VisitDetailsForm({
    super.key,
    required this.style,
    required this.isLimited,
    required this.memoController,
    required this.onStyleChanged,
    required this.onLimitedChanged,
    required this.onMemoChanged,
    this.waitController,
    this.onWaitChanged,
    this.shopMemoController,
    this.onShopMemoChanged,
  });

  final RamenStyle? style;
  final bool isLimited;
  final TextEditingController memoController;
  final ValueChanged<RamenStyle?> onStyleChanged;
  final ValueChanged<bool> onLimitedChanged;
  final ValueChanged<String> onMemoChanged;

  /// 待ち時間（分）の入力欄。nullなら出さない（並んだ時刻から自動で計算するときなど）。
  final TextEditingController? waitController;
  final ValueChanged<int?>? onWaitChanged;

  /// 店の覚え書き（店ごと）の入力欄。nullなら出さない（店がまだ決まっていないときなど）。
  final TextEditingController? shopMemoController;
  final ValueChanged<String>? onShopMemoChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.styleSection, style: textTheme.labelLarge),
        const SizedBox(height: 6),
        RamenStyleTiles(selected: style, onChanged: onStyleChanged),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.isLimited),
          value: isLimited,
          onChanged: onLimitedChanged,
        ),
        if (waitController case final controller?) ...[
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: l10n.waitMinutesLabel,
              suffixText: l10n.waitMinutesUnit,
            ),
            onChanged: (text) => onWaitChanged?.call(parseWaitMinutes(text)),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: memoController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.memoLabel,
            hintText: l10n.memoHint,
            helperText: l10n.memoHelper,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: onMemoChanged,
        ),
        if (shopMemoController case final controller?) ...[
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l10n.shopMemoSection,
              hintText: l10n.shopMemoHint,
              helperText: l10n.shopMemoHelper,
              helperMaxLines: 2,
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            onChanged: onShopMemoChanged,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// 入力された待ち時間（分）。空や0はnull（並ばなかった）。
int? parseWaitMinutes(String text) {
  final minutes = int.tryParse(text.trim());
  return minutes == null || minutes <= 0 ? null : minutes;
}
