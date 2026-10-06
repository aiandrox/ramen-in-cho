import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/safe_bottom.dart';
import '../../theme/washi.dart';
import '../error_reporting/error_reporting.dart';
import '../journal/journal.dart';
import '../records/record_repository.dart';
import '../scoring/scoring_providers.dart';
import 'share_card.dart';
import '../../theme/washi_buttons.dart';

/// 1杯を1枚の絵にして、OSの共有画面で送る。写真・道中記・修行点を入れるかは送る前に選べる。
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _cardKey = GlobalKey();
  final _buttonKey = GlobalKey();
  bool _includePhoto = true;
  bool _includeJournal = true;
  bool _includePoints = true;
  bool _isSharing = false;

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final button = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    // iPadでは共有の画面の出どころを指定しないと落ちるため、ボタンの位置を渡す。
    final origin = button == null
        ? null
        : button.localToGlobal(Offset.zero) & button.size;
    if (boundary == null) return;
    setState(() => _isSharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('画像を作れませんでした');
      final directory = await getTemporaryDirectory();
      final file = File(
        p.join(directory.path, 'ramen-in-cho-${widget.visitId}.png'),
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e, st) {
      reportError(e, st, reason: 'Share failed');
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visits = ref.watch(visitsProvider).value ?? const [];
    final entry = visits.where((e) => e.visit.id == widget.visitId).firstOrNull;
    final all = ref.watch(scoredVisitsProvider);
    final scored = ref.watch(scoredVisitByIdProvider)[widget.visitId];
    if (entry == null || scored == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.visitNotFound)),
      );
    }
    final hasPhoto = entry.visit.photoPath != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shareTitle)),
      backgroundColor: Washi.desk,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Center(
            child: FittedBox(
              child: RepaintBoundary(
                key: _cardKey,
                child: ShareCard(
                  entry: entry,
                  scored: scored,
                  journal: buildJournal(scored, all, includeMemo: false),
                  includePhoto: _includePhoto,
                  includeJournal: _includeJournal,
                  includePoints: _includePoints,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (hasPhoto)
            SwitchListTile(
              title: Text(l10n.shareIncludePhoto),
              value: _includePhoto,
              onChanged: (value) => setState(() => _includePhoto = value),
            ),
          SwitchListTile(
            title: Text(l10n.shareIncludeJournal),
            value: _includeJournal,
            onChanged: (value) => setState(() => _includeJournal = value),
          ),
          SwitchListTile(
            title: Text(l10n.shareIncludePoints),
            value: _includePoints,
            onChanged: _includeJournal
                ? (value) => setState(() => _includePoints = value)
                : null,
          ),
          const SizedBox(height: 8),
          Text(l10n.shareNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      // スマホの戻るボタンの帯に重ならないよう、画面の下に固定する。
      bottomNavigationBar: SafeBottomBar(
        child: AiFuda(
          key: _buttonKey,
          expand: true,
          height: 56,
          onPressed: _isSharing ? null : _share,
          icon: const Icon(Icons.ios_share),
          child: Text(l10n.shareButton),
        ),
      ),
    );
  }
}
