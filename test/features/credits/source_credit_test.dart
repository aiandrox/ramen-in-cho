import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/features/credits/source_credit.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/l10n/app_localizations.dart';

import '../../support/l10n.dart';

void main() {
  Future<void> pump(WidgetTester tester, SourceCredit credit) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [visitsProvider.overrideWithValue(const AsyncData([]))],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(body: credit),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Yahoo! の結果を出すときだけ Yahoo! のクレジットを添える', (tester) async {
    await pump(tester, const SourceCredit(yahoo: false));
    expect(find.text(ja.sourceCreditOsm), findsOneWidget);
    expect(find.text(ja.sourceCreditYahoo), findsNothing);

    await pump(tester, const SourceCredit());
    expect(find.text(ja.sourceCreditYahoo), findsOneWidget);
  });

  testWidgets('「出典」をタップすると出典・ライセンスを開く', (tester) async {
    await pump(tester, const SourceCredit());

    await tester.tap(find.text(ja.sourceCreditMore));
    await tester.pumpAndSettle();

    expect(find.text(ja.creditsTitle), findsOneWidget);
    expect(find.text(ja.creditsOpenPoi), findsOneWidget);
  });
}
