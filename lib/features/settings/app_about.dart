import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final privacyPolicyUri = Uri.parse(
  'https://ramen-in-cho.aiandrox.com/privacy.html',
);

/// 外のブラウザでページを開く。開けなければfalse。テストで差し替える。
final externalPageOpenerProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);

/// アプリの版数とビルド番号。取れなければnull。
final appVersionProvider = FutureProvider<({String version, String build})?>((
  ref,
) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, build: info.buildNumber);
  } catch (_) {
    return null;
  }
});
