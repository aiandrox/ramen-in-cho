import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'features/error_reporting/error_reporting.dart';
import 'features/home/app_shell.dart';
import 'features/prefecture/prefectures.dart';
import 'features/records/photo_storage.dart';
import 'features/support/install_id.dart';
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
  final installIdStorage = InstallIdStorage();
  await _startFirebase(installIdStorage);
  runApp(
    ProviderScope(
      overrides: [
        documentsDirectoryProvider.overrideWithValue(documents),
        prefectureIndexProvider.overrideWithValue(prefectures),
        installIdStorageProvider.overrideWithValue(installIdStorage),
      ],
      child: const RamenInChoApp(),
    ),
  );
}

const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

const _buildMode = kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

/// Firebase の準備ができなくても、クラッシュの報告と App Check が使えないだけでアプリは使える。
/// 送るのはクラッシュ・エラーの情報と App Check のトークンだけで、記録・写真・位置は送らない。
Future<void> _startFirebase(InstallIdStorage installIdStorage) async {
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  // Firebase が使えなくても、直近のエラーは不具合の知らせのメールに載せられるようにする。
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    recentErrors.add(details.exception, reason: 'Flutter error');
    if (!firebaseReady) return;
    // 部品の説明（キーなど）に店名が入ることがあるため、どこで起きたかの一文だけを添える。
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(
            redactError(details.exception),
            details.stack,
            fatal: true,
            information: [?details.context?.toDescription()],
          )
          .catchError((_) {}),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    recentErrors.add(error, reason: 'Uncaught error');
    if (!firebaseReady) return false;
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(redactError(error), stack, fatal: true)
          .catchError((_) {}),
    );
    return true;
  };
  if (!firebaseReady) return;
  unawaited(
    FirebaseCrashlytics.instance
        .setCustomKey('build_mode', _buildMode)
        .catchError((Object e) {
          debugPrint('Crashlytics build_mode key failed: $e');
        }),
  );
  unawaited(_linkInstallId(installIdStorage));
  try {
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
  } catch (e, st) {
    reportError(e, st, reason: 'App Check activation failed');
  }
}

/// 不具合の知らせのメールに載せる識別番号と、Crashlytics の利用者の識別子をそろえる。
Future<void> _linkInstallId(InstallIdStorage storage) async {
  final id = await storage.currentOrCreate();
  if (id == null) return;
  await setErrorReportingUserId(id);
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
