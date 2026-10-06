import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import 'credits_screen.dart';

/// Yahoo! のクレジットは API の案内ページにつなぐ決まり。
final _yahooUri = Uri.parse('https://developer.yahoo.co.jp/sitemap/');

/// 地図や店の検索結果に添える、小さな出典の1行。
/// 細かな出典（OpenPOI・国土数値情報など）は「出典」から開く「出典・ライセンス」に任せる。
class SourceCredit extends StatelessWidget {
  const SourceCredit({super.key, this.yahoo = true, this.onMap = false});

  /// Yahoo! の検索結果を出しているとき（サーバー経由の店の検索）。
  final bool yahoo;

  /// 地図の上に重ねるときは、読めるように薄い和紙の地を敷く。
  final bool onMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontSize: 11, color: Washi.inkSoft);
    final linkStyle = style?.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: Washi.inkSoft,
    );

    void openCredits() => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CreditsScreen()));

    Future<void> openYahoo() async {
      try {
        if (!await launchUrl(_yahooUri, mode: LaunchMode.externalApplication)) {
          debugPrint('Open Yahoo! credit failed');
        }
      } on PlatformException catch (e) {
        debugPrint('Open Yahoo! credit failed: $e');
      }
    }

    Widget part(String text, TextStyle? style, VoidCallback onTap) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(text, style: style),
          ),
        );

    final separator = Text(' ・ ', style: style);
    final line = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        part(l10n.sourceCreditOsm, style, openCredits),
        if (yahoo) ...[
          separator,
          part(l10n.sourceCreditYahoo, linkStyle, openYahoo),
        ],
        separator,
        part(l10n.sourceCreditMore, linkStyle, openCredits),
      ],
    );
    if (!onMap) return line;
    return ColoredBox(
      color: Washi.paper.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: line,
      ),
    );
  }
}
