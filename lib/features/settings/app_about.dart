import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final privacyPolicyUri = Uri.parse(
  'https://ramen-in-cho.aiandrox.com/privacy.html',
);

/// 外のアプリ（ブラウザ・メールなど）で開く。開けなければfalse。
Future<bool> openExternally(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Open external failed: $e');
    return false;
  }
}

/// 外のブラウザでページを開く。テストで差し替える。
final externalPageOpenerProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) => openExternally,
);

typedef AppVersion = ({String version, String build});

/// アプリの版数とビルド番号。取れなければnull。
Future<AppVersion?> readAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, build: info.buildNumber);
  } catch (_) {
    return null;
  }
}

final appVersionProvider = FutureProvider<AppVersion?>(
  (ref) => readAppVersion(),
);
