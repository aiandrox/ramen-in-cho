import '../../l10n/app_localizations.dart';
import '../error_reporting/error_reporting.dart';

const supportEmailAddress = 'face-seal@aiandrox.com';

const _separator = '------------------------------';

/// 不具合の知らせのメールに添える調査用の情報。記録・写真・店・位置は含めない。
class SupportDiagnostics {
  const SupportDiagnostics({
    required this.installId,
    required this.appVersion,
    required this.osName,
    required this.osVersion,
    required this.deviceModel,
    required this.recentErrors,
    required this.sentAt,
  });

  /// [InstallIdStorage] が作った匿名の識別番号。
  final String? installId;
  final String? appVersion;
  final String? osName;
  final String? osVersion;
  final String? deviceModel;

  /// 新しい順。
  final List<RecentErrorEntry> recentErrors;
  final DateTime sentAt;
}

/// 確認の画面とメールの本文で同じ文面を使うため、ここだけで組み立てる。
String buildDiagnosticsBlock(
  AppLocalizations l10n,
  SupportDiagnostics diagnostics,
) {
  final unknown = l10n.diagnosticsUnknown;
  final os = [
    diagnostics.osName,
    diagnostics.osVersion,
  ].where((part) => part != null && part.isNotEmpty).join(' ');
  return [
    l10n.diagnosticsInstallId(diagnostics.installId ?? unknown),
    l10n.diagnosticsApp(diagnostics.appVersion ?? unknown),
    l10n.diagnosticsOs(os.isEmpty ? unknown : os),
    l10n.diagnosticsDevice(diagnostics.deviceModel ?? unknown),
    l10n.diagnosticsSentAt(formatSupportDateTime(diagnostics.sentAt)),
    l10n.diagnosticsRecentErrors,
    if (diagnostics.recentErrors.isEmpty)
      l10n.diagnosticsNoRecentErrors
    else
      for (final entry in diagnostics.recentErrors)
        '- ${formatSupportDateTime(entry.at)} '
            '${entry.reason == null ? entry.summary : '${entry.reason}: ${entry.summary}'}',
  ].join('\n');
}

String buildContactMailBody(
  AppLocalizations l10n,
  SupportDiagnostics diagnostics,
) =>
    '\n\n${l10n.contactMailBodyPlaceholder}\n$_separator\n'
    '${l10n.contactMailDiagnosticsNotice}\n'
    '${buildDiagnosticsBlock(l10n, diagnostics)}\n';

Uri buildContactMailUri({
  required String address,
  required String subject,
  required String body,
}) => Uri(
  scheme: 'mailto',
  path: address,
  // Uri(queryParameters:) は空白を + にし、そのまま件名・本文に出るメールアプリがあるため。
  query:
      'subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
);

String formatSupportDateTime(DateTime at) {
  final local = at.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
      '${_pad(local.hour)}:${_pad(local.minute)}:${_pad(local.second)} '
      '$sign${_pad(absolute.inHours)}:${_pad(absolute.inMinutes.remainder(60))}';
}

String _pad(int value) => value.toString().padLeft(2, '0');
