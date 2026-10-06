import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// catch で捕まえた失敗をログに出し、Crashlytics に致命的でないエラーとして送る
/// （`main.dart` の受け口は捕まえられなかった例外しか拾わないため）。
/// 送れないとき（Firebase の準備ができていないなど）は黙って諦め、呼び出し元の処理を止めない。
/// 通信できないなど、よく起きる想定内の失敗には使わない。
void reportError(Object error, StackTrace stackTrace, {String? reason}) {
  debugPrint(
    reason == null ? '$error\n$stackTrace' : '$reason: $error\n$stackTrace',
  );
  recentErrors.add(error, reason: reason);
  try {
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(
            redactError(error),
            stackTrace,
            reason: reason,
            fatal: false,
          )
          .catchError((_) {}),
    );
  } catch (_) {
    // 上の説明のとおり、送れなくても呼び出し元には影響させない。
  }
}

/// 不具合の知らせのメールに載せる識別番号で、Crashlytics の記録をたどれるようにする。
Future<void> setErrorReportingUserId(String id) async {
  try {
    await FirebaseCrashlytics.instance.setUserIdentifier(id);
  } catch (e) {
    debugPrint('Crashlytics user identifier failed: $e');
  }
}

/// 例外の文に店名・メモ・ファイルの場所などが混ざることがある（部品や受け手の中身も文に出る）ため、
/// 型の名前しか出ない種類だけ文を残し、ほかは種類の名前だけにする。
Object redactError(Object error) {
  if (error is FlutterError) return RedactedError(summarizeError(error));
  if (error is TypeError || error is AssertionError) return error;
  return RedactedError(summarizeError(error));
}

/// 例外の種類だけの短い要約（プラットフォームの例外はコードも添える）。
String summarizeError(Object error) => switch (error) {
  PlatformException(:final code) => 'PlatformException($code)',
  _ => error.runtimeType.toString(),
};

/// 中身を伏せた例外。スタックトレースは元のものをそのまま送る。
class RedactedError implements Exception {
  const RedactedError(this.summary);

  final String summary;

  @override
  String toString() => summary;
}

/// 直近のエラーの要約。端末のメモリにだけ置き、不具合の知らせのメールに添える。
class RecentErrors {
  RecentErrors({this.capacity = 5, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final int capacity;
  final DateTime Function() _now;
  final _entries = <RecentErrorEntry>[];

  /// 新しい順。
  List<RecentErrorEntry> get entries => List.unmodifiable(_entries.reversed);

  void add(Object error, {String? reason}) {
    _entries.add(
      RecentErrorEntry(
        at: _now(),
        summary: summarizeError(error),
        reason: reason,
      ),
    );
    if (_entries.length > capacity) _entries.removeAt(0);
  }

  void clear() => _entries.clear();
}

class RecentErrorEntry {
  const RecentErrorEntry({
    required this.at,
    required this.summary,
    this.reason,
  });

  final DateTime at;
  final String summary;
  final String? reason;
}

final recentErrors = RecentErrors();
