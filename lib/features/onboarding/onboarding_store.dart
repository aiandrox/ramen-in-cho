import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../records/photo_storage.dart';
import 'onboarding_flow.dart';

final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => OnboardingStore(ref.watch(documentsDirectoryProvider)),
);

/// 起動したときに案内を出すか。テストでは出さない。
final showOnboardingOnLaunchProvider = Provider<bool>((ref) => true);

/// 案内の進み具合。[completed]なら起動時に出さない。まだなら[step]から続ける。
typedef OnboardingProgress = ({bool completed, OnboardingStep step});

/// 案内を終えた（閉じた）か、途中ならどの段階にいるかを、documents の `onboarding.json` に残す。
class OnboardingStore {
  OnboardingStore(this._documents);

  static const fileName = 'onboarding.json';

  final Directory _documents;

  File get _file => File(p.join(_documents.path, fileName));

  Future<OnboardingProgress> load() async {
    const fresh = (completed: false, step: OnboardingStep.welcome);
    try {
      final json = jsonDecode(await _file.readAsString());
      if (json is! Map<String, dynamic>) return fresh;
      final step = onboardingStepNamed(json['step']);
      return (
        completed: json['completedAt'] is String,
        step: step ?? OnboardingStep.welcome,
      );
    } on FileSystemException {
      return fresh;
    } on FormatException {
      return fresh;
    }
  }

  /// 終えたあと（設定から見直しているとき）は残さない。見直しはいつも其の一から。
  Future<void> saveStep(OnboardingStep step) => _serial(() async {
    if ((await load()).completed) return;
    await _file.writeAsString(jsonEncode({'step': step.name}));
  });

  Future<void> markCompleted(DateTime now) => _serial(
    () => _file.writeAsString(
      jsonEncode({'completedAt': now.toUtc().toIso8601String()}),
    ),
  );

  // 段階を残す途中で閉じても、終えた印が段階で上書きされないよう、書き込みを順に並べる。
  Future<void> _pending = Future.value();

  Future<void> _serial(Future<void> Function() write) {
    final next = _pending.then((_) => write());
    _pending = next.catchError((Object _) {});
    return next;
  }
}
