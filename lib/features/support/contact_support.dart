import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';
import '../error_reporting/error_reporting.dart';
import '../settings/app_about.dart';
import 'install_id.dart';
import 'support_diagnostics.dart';
import 'support_environment.dart';

/// テストで送る日時を決めるための窓口。
final supportClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// テストでメールアプリを開く処理を差し替えるための窓口。
final mailOpenerProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) => openExternally,
);

/// 設定の「不具合を知らせる」。
void startContactSupportFlow(BuildContext context, WidgetRef ref) {
  final flow = runContactSupportFlow(
    navigator: Navigator.of(context),
    readInstallId: ref.read(installIdStorageProvider).currentOrCreate,
    readEnvironment: ref.read(supportEnvironmentReaderProvider),
    openMail: ref.read(mailOpenerProvider),
    now: ref.read(supportClockProvider),
  );
  // 切り離した Future の例外は PlatformDispatcher.onError に届き、落ちていないのに
  // 致命的なエラーとして記録されるため、ここで受け止める。
  unawaited(
    flow.catchError((Object e, StackTrace stackTrace) {
      reportError(e, stackTrace, reason: 'Contact support failed');
    }),
  );
}

/// 添える情報を確認の画面で見せ、よいと言われたときだけメールアプリを開く
/// （アプリが自分から送ることはない）。
Future<void> runContactSupportFlow({
  required NavigatorState navigator,
  required Future<String?> Function() readInstallId,
  required Future<SupportEnvironment> Function() readEnvironment,
  required Future<bool> Function(Uri uri) openMail,
  required DateTime Function() now,
}) async {
  final (installId, environment) = await (
    readInstallId(),
    readEnvironment(),
  ).wait;
  if (!navigator.mounted) return;

  final diagnostics = SupportDiagnostics(
    installId: installId,
    appVersion: environment.appVersion,
    osName: environment.osName,
    osVersion: environment.osVersion,
    deviceModel: environment.deviceModel,
    recentErrors: recentErrors.entries,
    sentAt: now(),
  );

  final confirmed = await showDialog<bool>(
    context: navigator.context,
    builder: (context) => _ContactConfirmDialog(diagnostics: diagnostics),
  );
  if (confirmed != true || !navigator.mounted) return;

  final l10n = AppLocalizations.of(navigator.context);
  final uri = buildContactMailUri(
    address: supportEmailAddress,
    subject: l10n.contactMailSubject,
    body: buildContactMailBody(l10n, diagnostics),
  );
  if (await openMail(uri)) return;
  if (!navigator.mounted) return;

  final messenger = ScaffoldMessenger.of(navigator.context);
  final copied = await showDialog<bool>(
    context: navigator.context,
    builder: (context) => const _MailAppUnavailableDialog(),
  );
  if (copied == true && messenger.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.addressCopied)));
  }
}

class _ContactConfirmDialog extends StatelessWidget {
  const _ContactConfirmDialog({required this.diagnostics});

  final SupportDiagnostics diagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.contactSupport),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.contactConfirmBody),
            const SizedBox(height: 12),
            Text(
              l10n.contactConfirmDiagnosticsNote,
              style: theme.textTheme.bodySmall?.copyWith(color: Washi.inkSoft),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Washi.page,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Washi.line),
              ),
              child: Text(
                buildDiagnosticsBlock(l10n, diagnostics),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        AiFuda(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.composeEmail),
        ),
      ],
    );
  }
}

class _MailAppUnavailableDialog extends StatelessWidget {
  const _MailAppUnavailableDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mailAppUnavailableTitle),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.mailAppUnavailableBody),
          const SizedBox(height: 12),
          const SelectableText(supportEmailAddress),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.close),
        ),
        AiFuda(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: supportEmailAddress),
            );
            if (context.mounted) Navigator.of(context).pop(true);
          },
          child: Text(l10n.copyAddress),
        ),
      ],
    );
  }
}
