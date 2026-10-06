import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/features/error_reporting/error_reporting.dart';

void main() {
  setUp(recentErrors.clear);

  test('Firebase の準備ができていなくても reportError は例外を投げない', () {
    expect(
      () => reportError(
        const FileSystemException('x', '/private/path/麺屋'),
        StackTrace.current,
        reason: 'Record save failed',
      ),
      returnsNormally,
    );
    final entry = recentErrors.entries.single;
    expect(entry.reason, 'Record save failed');
    expect(entry.summary, 'FileSystemException');
  });

  group('redactError', () {
    test('中身に店名やパスが入りうる例外は種類の名前だけにする', () {
      final redacted = redactError(const FormatException('麺屋 武蔵'));
      expect(redacted, isA<RedactedError>());
      expect(redacted.toString(), 'FormatException');
      expect(redacted.toString(), isNot(contains('武蔵')));
    });

    test('プラットフォームの例外はコードだけを残す', () {
      final redacted = redactError(
        PlatformException(code: 'camera_access_denied', message: '/path'),
      );
      expect(redacted.toString(), 'PlatformException(camera_access_denied)');
    });

    test('部品や受け手の中身が文に出る例外も種類の名前だけにする', () {
      expect(redactError(StateError('麺屋')).toString(), 'StateError');
      expect(
        redactError(FlutterError('Text("麺屋")')).toString(),
        'FlutterError',
      );
    });

    test('型の名前しか出ない例外はそのまま送る', () {
      final error = AssertionError('x != null');
      expect(identical(redactError(error), error), isTrue);
    });
  });

  test('直近のエラーは新しい順に、決めた件数だけ残す', () {
    var minute = 0;
    final errors = RecentErrors(
      capacity: 2,
      now: () => DateTime(2026, 10, 6, 12, minute++),
    );
    errors.add(Exception('a'), reason: 'first');
    errors.add(Exception('b'), reason: 'second');
    errors.add(Exception('c'), reason: 'third');
    expect(errors.entries.map((e) => e.reason), ['third', 'second']);
  });
}
