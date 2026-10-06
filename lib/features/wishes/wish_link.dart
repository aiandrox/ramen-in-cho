import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi_buttons.dart';
import 'shared_wish.dart';

/// 願に残したリンク（Google マップ・YouTube など）を、端末のアプリやブラウザで開く筆の下線。
/// 開けないリンク（http・https 以外）なら何も出さない。
class WishLinkButton extends StatelessWidget {
  const WishLinkButton({super.key, required this.link});

  final String link;

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).wishLinkOpenFailed;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      debugPrint('Open wish link failed: $e');
    }
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final uri = openableLink(link);
    final host = linkHost(link);
    if (uri == null || host == null) return const SizedBox.shrink();
    return FudeLink(
      icon: const Icon(Icons.link),
      onPressed: () => _open(context, uri),
      child: Text(AppLocalizations.of(context).wishLinkOpen(host)),
    );
  }
}
