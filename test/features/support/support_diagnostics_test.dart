import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/features/error_reporting/error_reporting.dart';
import 'package:ramen_in_cho/features/support/install_id.dart';
import 'package:ramen_in_cho/features/support/support_diagnostics.dart';

import '../../support/l10n.dart';

void main() {
  final sentAt = DateTime(2026, 10, 6, 9, 5, 3);

  SupportDiagnostics diagnostics({List<RecentErrorEntry> errors = const []}) =>
      SupportDiagnostics(
        installId: 'abc-123',
        appVersion: '1.0.0 (2)',
        osName: 'Android',
        osVersion: '15 (SDK 35)',
        deviceModel: 'Google Pixel 8',
        recentErrors: errors,
        sentAt: sentAt,
      );

  test('添える情報を1行ずつ並べ、エラーが無ければ「なし」と書く', () {
    final block = buildDiagnosticsBlock(ja, diagnostics());
    final at = formatSupportDateTime(sentAt);
    expect(block, '''
識別番号: abc-123
アプリ: 1.0.0 (2)
OS: Android 15 (SDK 35)
端末: Google Pixel 8
送信日時: $at
直近のエラー:
- なし''');
  });

  test('直近のエラーは日時と理由と種類を書く', () {
    final at = DateTime(2026, 10, 6, 8, 0);
    final block = buildDiagnosticsBlock(
      ja,
      diagnostics(
        errors: [
          RecentErrorEntry(
            at: at,
            summary: 'SqliteException',
            reason: 'Record save failed',
          ),
          RecentErrorEntry(at: at, summary: 'StateError'),
        ],
      ),
    );
    final when = formatSupportDateTime(at);
    expect(
      block,
      endsWith(
        '直近のエラー:\n'
        '- $when Record save failed: SqliteException\n'
        '- $when StateError',
      ),
    );
  });

  test('取れなかった項目は「不明」にする', () {
    final block = buildDiagnosticsBlock(
      ja,
      SupportDiagnostics(
        installId: null,
        appVersion: null,
        osName: null,
        osVersion: null,
        deviceModel: null,
        recentErrors: const [],
        sentAt: sentAt,
      ),
    );
    expect(block, startsWith('識別番号: 不明\nアプリ: 不明\nOS: 不明\n端末: 不明\n'));
  });

  test('本文は書く場所を空けてから、区切りの下に情報を添える', () {
    final body = buildContactMailBody(ja, diagnostics());
    expect(body, startsWith('\n\n${ja.contactMailBodyPlaceholder}\n---'));
    expect(body, contains(ja.contactMailDiagnosticsNotice));
    expect(body, endsWith('- なし\n'));
  });

  test('メールの宛先・件名・本文は空白を + にせずに符号化する', () {
    final uri = buildContactMailUri(
      address: supportEmailAddress,
      subject: '麺印帳 不具合',
      body: 'a b\nc',
    );
    expect(uri.scheme, 'mailto');
    expect(uri.path, supportEmailAddress);
    expect(uri.query, contains('subject=%E9%BA%BA%E5%8D%B0%E5%B8%B3%20'));
    expect(uri.query, endsWith('&body=a%20b%0Ac'));
  });

  test('日時は時差つきで書く', () {
    final text = formatSupportDateTime(sentAt);
    expect(text, matches(RegExp(r'^2026-10-06 09:05:03 [+-]\d\d:\d\d$')));
  });

  group('InstallIdStorage', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('install_id'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('一度作った番号を、作り直したあとも使い続ける', () async {
      var made = 0;
      InstallIdStorage storage() => InstallIdStorage(
        directory: () async => dir,
        generate: () => 'id-${made++}',
      );
      final first = storage();
      final ids = await Future.wait([
        first.currentOrCreate(),
        first.currentOrCreate(),
      ]);
      expect(ids, ['id-0', 'id-0']);
      expect(await storage().currentOrCreate(), 'id-0');
      expect(made, 1);
    });

    test('保存できなければ null を返す', () async {
      final storage = InstallIdStorage(
        directory: () async => throw const FileSystemException('no'),
      );
      expect(await storage.currentOrCreate(), isNull);
    });
  });
}
