import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';

/// 写真の上に重ねる小さな墨の丸ボタン（外す・回す）。
class PhotoRoundButton extends StatelessWidget {
  const PhotoRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  /// 写真を時計回りに90度回すボタン。
  factory PhotoRoundButton.rotate(
    BuildContext context, {
    Key? key,
    required VoidCallback? onPressed,
  }) => PhotoRoundButton(
    key: key,
    icon: Icons.rotate_right,
    tooltip: AppLocalizations.of(context).rotatePhoto,
    onPressed: onPressed,
  );

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: Washi.ink,
        foregroundColor: Washi.page,
        minimumSize: const Size(36, 36),
      ),
    );
  }
}
