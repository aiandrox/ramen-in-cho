import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_about.dart';

/// 不具合の知らせに添えるアプリ・端末の情報。取れなかった項目は null。
class SupportEnvironment {
  const SupportEnvironment({
    this.appVersion,
    this.osName,
    this.osVersion,
    this.deviceModel,
  });

  /// `1.0.0 (2)` のようなバージョンとビルド番号。
  final String? appVersion;
  final String? osName;
  final String? osVersion;
  final String? deviceModel;
}

Future<SupportEnvironment> readSupportEnvironment() async {
  final (version, device) = await (_appVersionLabel(), _readDevice()).wait;
  return SupportEnvironment(
    appVersion: version,
    osName: _osName,
    osVersion: device?.osVersion,
    deviceModel: device?.model,
  );
}

/// テストで端末の情報をにせものに差し替えるための窓口。
final supportEnvironmentReaderProvider =
    Provider<Future<SupportEnvironment> Function()>(
      (ref) => readSupportEnvironment,
    );

Future<String?> _appVersionLabel() async {
  final app = await readAppVersion();
  if (app == null) return null;
  return '${app.version} (${app.build})';
}

String? get _osName => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'Android',
  TargetPlatform.iOS => 'iOS',
  _ => null,
};

Future<({String model, String osVersion})?> _readDevice() async {
  try {
    final plugin = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final info = await plugin.androidInfo;
        return (
          model: '${info.manufacturer} ${info.model}',
          osVersion: '${info.version.release} (SDK ${info.version.sdkInt})',
        );
      case TargetPlatform.iOS:
        final info = await plugin.iosInfo;
        return (
          model: '${info.model} (${info.utsname.machine})',
          osVersion: info.systemVersion,
        );
      default:
        return null;
    }
  } catch (_) {
    return null;
  }
}
