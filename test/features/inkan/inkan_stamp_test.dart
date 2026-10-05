import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/l10n/app_localizations.dart';

import '../../support/builders.dart';

void main() {
  Future<void> pumpStamp(WidgetTester tester, RamenStyle style) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: InkanStamp(
            scored: ScoredVisit(
              visit: buildVisit(style: style),
              shop: buildShop(),
              points: PointsBreakdown.zero,
              isFirstVisit: false,
              isRetrySuccess: false,
            ),
          ),
        ),
      );

  testWidgets('つけ麺の印は、小さな縦の「つけ」を大きな「麺」の左に添える', (tester) async {
    await pumpStamp(tester, RamenStyle.tsukemen);
    expect(find.text('つ'), findsOneWidget);
    expect(find.text('け'), findsOneWidget);
    expect(find.text('麺'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^つけ麺 ')), findsOneWidget);
  });

  testWidgets('ほかの系統は名前を1行で組む', (tester) async {
    await pumpStamp(tester, RamenStyle.shoyu);
    expect(find.text('醤油'), findsOneWidget);
    expect(find.text('つ'), findsNothing);
  });
}
