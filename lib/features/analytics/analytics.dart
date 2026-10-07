import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_events.dart';

/// 使い方の統計を送る先。送るのは [AnalyticsEvent] の名前と、種類・数・はい/いいえだけ。
/// 店名・位置・写真・メモ・願の中身・リンク・記録の日時など、人が入れたものは送らない。
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => FirebaseAnalyticsService(),
);

/// [WidgetRef] の無い部品から送る。ProviderScope の外（一部のテストなど）では何もしない。
void logAnalytics(BuildContext context, AnalyticsEvent event) {
  try {
    unawaited(
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(analyticsProvider).log(event),
    );
  } catch (e) {
    debugPrint('Analytics failed: $e');
  }
}

abstract class AnalyticsService {
  Future<void> log(AnalyticsEvent event);

  Future<void> logScreen(String screen);

  /// 値が null のものは消す。
  Future<void> setUserProperties(Map<String, String?> properties);
}

/// 送れないとき（Firebase の準備ができていないなど）は黙って諦め、呼び出し元の処理を止めない。
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _override = analytics;

  final FirebaseAnalytics? _override;

  FirebaseAnalytics? get _analytics {
    if (_override != null) return _override;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAnalytics.instance;
  }

  @override
  Future<void> log(AnalyticsEvent event) => _guard(
    (analytics) =>
        analytics.logEvent(name: event.name, parameters: event.parameters),
  );

  @override
  Future<void> logScreen(String screen) =>
      _guard((analytics) => analytics.logScreenView(screenName: screen));

  @override
  Future<void> setUserProperties(Map<String, String?> properties) =>
      _guard((analytics) async {
        for (final MapEntry(:key, :value) in properties.entries) {
          await analytics.setUserProperty(name: key, value: value);
        }
      });

  Future<void> _guard(Future<void> Function(FirebaseAnalytics) action) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await action(analytics);
    } catch (e) {
      debugPrint('Analytics failed: $e');
    }
  }
}

/// 何も送らない。テストや、統計を送らないときに使う。
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> log(AnalyticsEvent event) async {}

  @override
  Future<void> logScreen(String screen) async {}

  @override
  Future<void> setUserProperties(Map<String, String?> properties) async {}
}
