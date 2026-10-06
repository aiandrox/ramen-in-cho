import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../error_reporting/error_reporting.dart';
import '../records/clock.dart';
import 'backup_service.dart';
import '../../theme/washi_buttons.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _exportButtonKey = GlobalKey();
  bool _isBusy = false;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // iPadでは共有の画面の出どころを指定しないと落ちるため、ボタンの位置を渡す。
    final box =
        _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _isBusy = true);
    try {
      final file = await ref
          .read(backupServiceProvider)
          .writeBackup(ref.read(clockProvider)());
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin),
      );
      // ドライブの「マイドライブ」などは画面を出さずに保存するので、送ったことを知らせる。
      if (result.status == ShareResultStatus.success) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.backupExportSent)));
      }
    } catch (e, st) {
      reportError(e, st, reason: 'Backup export failed');
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupExportFailed)));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _isBusy = true);
    try {
      await pickAndRestoreBackup(context, ref);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Text(l10n.backupDescription, style: textTheme.bodyLarge),
          const SizedBox(height: 24),
          AiFuda(
            key: _exportButtonKey,
            onPressed: _isBusy ? null : _export,
            icon: const Icon(Icons.upload_file),
            child: Text(l10n.backupExport),
          ),
          const SizedBox(height: 4),
          Text(l10n.backupExportNote, style: textTheme.bodySmall),
          const SizedBox(height: 24),
          SumiFuda(
            onPressed: _isBusy ? null : _import,
            icon: const Icon(Icons.download),
            child: Text(l10n.backupImport),
          ),
          const SizedBox(height: 4),
          Text(l10n.backupImportNote, style: textTheme.bodySmall),
          if (_isBusy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

/// バックアップの zip を選んで読み込み、結果を知らせる。読み込めたら件数を返す（選ばなかった・失敗したら null）。
Future<RestoreSummary?> pickAndRestoreBackup(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(backupServiceProvider);
  final file = await openFile(
    acceptedTypeGroups: [
      XTypeGroup(
        label: l10n.backupFileType,
        extensions: const ['zip'],
        mimeTypes: const ['application/zip'],
        uniformTypeIdentifiers: const ['public.zip-archive'],
      ),
    ],
  );
  if (file == null) return null;
  try {
    final summary = await service.restoreBackup(file.path);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.backupImportDone(summary.addedVisits, summary.totalVisits),
        ),
      ),
    );
    return summary;
  } on FormatException catch (e) {
    debugPrint('Backup import rejected: $e');
    messenger.showSnackBar(SnackBar(content: Text(l10n.backupImportInvalid)));
  } catch (e, st) {
    reportError(e, st, reason: 'Backup import failed');
    messenger.showSnackBar(SnackBar(content: Text(l10n.backupImportFailed)));
  }
  return null;
}
