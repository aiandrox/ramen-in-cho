import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/features/settings/location_access.dart';
import 'package:ramen_in_cho/l10n/app_localizations.dart';
import 'package:ramen_in_cho/l10n/app_localizations_ja.dart';

class _FakeAccess implements LocationAccessService {
  _FakeAccess(this.access);

  LocationAccess access;
  final fixed = <LocationAccess>[];

  @override
  Future<LocationAccess> check() async => access;

  @override
  Future<void> fix(LocationAccess access) async {
    fixed.add(access);
    this.access = LocationAccess.granted;
  }
}

void main() {
  final ja = AppLocalizationsJa();

  Future<_FakeAccess> pump(WidgetTester tester, LocationAccess access) async {
    final fake = _FakeAccess(access);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationAccessServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ja'),
          home: Scaffold(body: LocationAccessTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('許可が無ければそう出し、タップで直して出し直す', (tester) async {
    final fake = await pump(tester, LocationAccess.deniedForever);
    expect(find.text(ja.locationAccessDeniedForever), findsOneWidget);

    await tester.tap(find.text(ja.locationSettings));
    await tester.pumpAndSettle();

    expect(fake.fixed, [LocationAccess.deniedForever]);
    expect(find.text(ja.locationAccessGranted), findsOneWidget);
  });

  testWidgets('スマホの位置情報がオフならそう出す', (tester) async {
    await pump(tester, LocationAccess.serviceOff);
    expect(find.text(ja.locationAccessServiceOff), findsOneWidget);
  });
}
