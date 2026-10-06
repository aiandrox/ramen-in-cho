import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import 'models.dart';
import 'style_tiles.dart';

/// 系統・限定・待ち時間・「この一杯について」・名店の印・「店の覚え書き」の入力欄。記録画面と編集画面で共有する。
/// 開け閉めはせず、見出しをつけてそのまま並べる（どれも任意）。
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
    this.shopFamous = false,
    this.onShopFamousChanged,
  });

  static const waitFieldKey = ValueKey('visitWaitField');
  static const memoFieldKey = ValueKey('visitMemoField');
  static const shopMemoFieldKey = ValueKey('visitShopMemoField');
  static const shopMemoDisabledFieldKey = ValueKey('visitShopMemoDisabled');
  static const shopFamousSwitchKey = ValueKey('visitShopFamousSwitch');

  final RamenStyle? style;
  final bool isLimited;
  final TextEditingController memoController;
  final ValueChanged<RamenStyle?> onStyleChanged;
  final ValueChanged<bool> onLimitedChanged;
  final ValueChanged<String> onMemoChanged;

  /// 待ち時間（分）の入力欄。nullなら出さない（並んだ時刻から自動で計算するときなど）。
  final TextEditingController? waitController;
  final ValueChanged<int?>? onWaitChanged;

  /// 店の覚え書き（店ごと）の入力欄。nullなら、どの店のものか決まっていないので押せない欄にする。
  final TextEditingController? shopMemoController;
  final ValueChanged<String>? onShopMemoChanged;

  /// 名店の印（店ごと）。[onShopFamousChanged]がnullなら、店が決まっていないので押せない。
  final bool shopFamous;
  final ValueChanged<bool>? onShopFamousChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shopMemo = shopMemoController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.styleSection, ruled: false),
        RamenStyleTiles(selected: style, onChanged: onStyleChanged),
        const SizedBox(height: 24),
        SectionTitle(l10n.limitedSection, ruled: false),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.isLimited),
          value: isLimited,
          onChanged: onLimitedChanged,
        ),
        if (waitController case final controller?) ...[
          const SizedBox(height: 24),
          SectionTitle(l10n.waitMinutesLabel, ruled: false),
          TextField(
            key: waitFieldKey,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(suffixText: l10n.waitMinutesUnit),
            onChanged: (text) => onWaitChanged?.call(parseWaitMinutes(text)),
          ),
        ],
        const SizedBox(height: 24),
        SectionTitle(l10n.memoLabel, ruled: false),
        TextField(
          key: memoFieldKey,
          controller: memoController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.memoHint,
            helperText: l10n.memoHelper,
          ),
          onChanged: onMemoChanged,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          key: shopFamousSwitchKey,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shopFamousToggle),
          subtitle: onShopFamousChanged == null
              ? Text(l10n.shopFamousNeedsShop)
              : null,
          value: onShopFamousChanged != null && shopFamous,
          onChanged: onShopFamousChanged,
        ),
        const SizedBox(height: 16),
        SectionTitle(l10n.shopMemoSection, ruled: false),
        if (shopMemo != null)
          TextField(
            key: shopMemoFieldKey,
            controller: shopMemo,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l10n.shopMemoHint,
              helperText: l10n.shopMemoHelper,
              helperMaxLines: 2,
            ),
            onChanged: onShopMemoChanged,
          )
        else
          // 鍵を分けて作り直し、前の店の書きかけを押せない欄に持ち越さない。
          TextField(
            key: shopMemoDisabledFieldKey,
            enabled: false,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l10n.shopMemoNeedsShop,
              helperText: l10n.shopMemoHelper,
              helperMaxLines: 2,
            ),
          ),
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
