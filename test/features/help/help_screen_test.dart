import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/help/help_screen.dart';
import 'package:ramen_in_cho/features/help/help_topics.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';

import '../../support/l10n.dart';

void main() {
  Future<void> pumpHelp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: localizedApp(home: const HelpScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('項目を並べ、いちばん下にはじめの案内への入口を置く', (tester) async {
    await pumpHelp(tester);

    for (final topic in helpTopics) {
      await tester.scrollUntilVisible(find.text(topic.title(ja)), 200);
      expect(find.text(topic.title(ja)), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text(ja.onboardingReplay), 200);
    expect(find.text(ja.onboardingReplay), findsOneWidget);
  });

  testWidgets('項目を開くと絵を1枚ずつめくり、最後は「閉じる」で戻る', (tester) async {
    await pumpHelp(tester);
    final topic = helpTopics.first;

    await tester.tap(find.text(topic.title(ja)));
    await tester.pumpAndSettle();
    expect(find.text(topic.pages.first.caption(ja)), findsOneWidget);
    expect(find.text(ja.helpPageCount(1, topic.pages.length)), findsOneWidget);
    expect(find.text(ja.helpPrev), findsNothing);

    for (var i = 1; i < topic.pages.length; i++) {
      await tester.tap(find.widgetWithText(AiFuda, ja.helpNext));
      await tester.pumpAndSettle();
      expect(find.text(topic.pages[i].caption(ja)), findsOneWidget);
    }
    expect(find.text(ja.helpPrev), findsOneWidget);

    await tester.tap(find.widgetWithText(SumiFuda, ja.helpDone));
    await tester.pumpAndSettle();
    expect(find.byType(HelpTopicScreen), findsNothing);
    expect(find.byType(HelpScreen), findsOneWidget);
  });

  test('どの項目にも絵が1枚以上あり、同じ絵を2度使わない', () {
    final shots = [
      for (final topic in helpTopics)
        for (final page in topic.pages) page.shot,
    ];
    expect(helpTopics.every((t) => t.pages.isNotEmpty), isTrue);
    expect(shots.toSet(), HelpShot.values.toSet());
    expect(shots.length, HelpShot.values.length);
  });
}
