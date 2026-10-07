import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/settings/app_about.dart';
import 'package:ramen_in_cho/features/settings/location_access.dart';
import 'package:ramen_in_cho/features/settings/settings_screen.dart';

import '../../support/l10n.dart';

class _GrantedAccess implements LocationAccessService {
  @override
  Future<LocationAccess> check() async => LocationAccess.granted;

  @override
  Future<void> fix(LocationAccess access) async {}
}

void main() {
  final opened = <Uri>[];
  var opens = true;

  setUp(() {
    opened.clear();
    opens = true;
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          locationAccessServiceProvider.overrideWithValue(_GrantedAccess()),
          appVersionProvider.overrideWith(
            (ref) async => (version: '1.2.3', build: '45'),
          ),
          externalPageOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return opens;
          }),
        ],
        child: localizedApp(home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('下のほうに、アプリの版数を出す', (tester) async {
    await pump(tester);

    expect(find.text(ja.appVersion('1.2.3', '45')), findsOneWidget);
    expect(ja.appVersion('1.2.3', '45'), '版 1.2.3（45）');
  });

  testWidgets('「プライバシーポリシー」で、外のブラウザでポリシーのページを開く', (tester) async {
    await pump(tester);

    await tester.tap(find.text(ja.privacyPolicy));
    await tester.pumpAndSettle();

    expect(opened, [
      Uri.parse('https://ramen-in-cho.aiandrox.com/privacy.html'),
    ]);
    expect(find.text(ja.privacyPolicyOpenFailed), findsNothing);
  });

  testWidgets('ブラウザを開けなければ知らせる', (tester) async {
    opens = false;
    await pump(tester);

    await tester.tap(find.text(ja.privacyPolicy));
    await tester.pumpAndSettle();

    expect(find.text(ja.privacyPolicyOpenFailed), findsOneWidget);
  });
}
