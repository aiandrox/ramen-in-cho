import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'features/home/app_shell.dart';
import 'features/prefecture/prefectures.dart';
import 'features/records/photo_storage.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicenses);
  final documents = await getApplicationDocumentsDirectory();
  final prefectures = PrefectureIndex.fromJson(
    await rootBundle.loadString(prefecturesAsset),
  );
  await _activateAppCheck();
  runApp(
    ProviderScope(
      overrides: [
        documentsDirectoryProvider.overrideWithValue(documents),
        prefectureIndexProvider.overrideWithValue(prefectures),
      ],
      child: const RamenInChoApp(),
    ),
  );
}

const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

/// サーバーへの問い合わせにアプリからだと示す印を添えるため。失敗してもサーバーを使わずに探せるので止めない。
Future<void> _activateAppCheck() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // デバッグビルドは、--dart-define で渡したトークン（未指定なら SDK がログに出すトークン）を
    // Firebase コンソールに登録しておく必要がある。
    final debugToken = _appCheckDebugToken.isEmpty ? null : _appCheckDebugToken;
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider(debugToken: debugToken)
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? AppleDebugProvider(debugToken: debugToken)
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}

Stream<LicenseEntry> _fontLicenses() async* {
  for (final font in ['ShipporiMincho', 'YujiSyuku']) {
    yield LicenseEntryWithLineBreaks([
      font,
    ], await rootBundle.loadString('assets/fonts/$font-OFL.txt'));
  }
}

class RamenInChoApp extends StatelessWidget {
  const RamenInChoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      // 日本語に固定しないと、Androidが漢字を中国語系のグリフで描画することがある。
      locale: const Locale('ja'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
