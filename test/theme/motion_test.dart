import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/theme/motion.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  double opacityOf(WidgetTester tester, Finder finder) {
    final opacity = tester.widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)),
    );
    return opacity.fold(1.0, (value, widget) => value * widget.opacity);
  }

  testWidgets('時計の中の部品は、時間がたつと最後の状態になる', (tester) async {
    await tester.pumpWidget(
      app(
        const MotionTimeline(
          duration: Duration(milliseconds: 600),
          child: RiseIn(delay: Duration(milliseconds: 200), child: Text('浮かぶ')),
        ),
      ),
    );
    expect(opacityOf(tester, find.text('浮かぶ')), 0);

    await tester.pumpAndSettle();
    expect(opacityOf(tester, find.text('浮かぶ')), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('タップで最後の状態まで飛ばせる', (tester) async {
    const words = '修行に終わりなし。';
    await tester.pumpWidget(
      app(
        const MotionTimeline(
          duration: Duration(seconds: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StampPress(delay: Duration(milliseconds: 300), child: Text('印')),
              BrushText(words, delay: Duration(milliseconds: 800)),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(words), findsOneWidget);
    expect(opacityOf(tester, find.text('印')), 0);

    await tester.tap(find.text('印'), warnIfMissed: false);
    await tester.pump();
    expect(opacityOf(tester, find.text('印')), 1);
    // 書き終えた筆の文は、ふつうの文字になる。
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == words),
      findsOneWidget,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('時計の外の筆の文は、タップで書き終える', (tester) async {
    const words = 'ゆっくり書く';
    await tester.pumpWidget(app(const BrushText(words)));
    await tester.pump(const Duration(milliseconds: 30));
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == words),
      findsNothing,
    );

    await tester.tap(find.text(words));
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == words),
      findsOneWidget,
    );
  });

  testWidgets('「動きを減らす」なら、はじめから最後の状態を見せる', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      app(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkBleed(delay: Duration(milliseconds: 300), child: Text('にじむ')),
            MotionTimeline(
              duration: Duration(seconds: 1),
              child: StampPress(
                delay: Duration(milliseconds: 300),
                child: Text('押す'),
              ),
            ),
          ],
        ),
      ),
    );
    expect(opacityOf(tester, find.text('にじむ')), 1);
    expect(opacityOf(tester, find.text('押す')), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('筆の文は1文字25ms、長くても1秒', () {
    expect(Motion.brushDuration('一二三四'), const Duration(milliseconds: 100));
    expect(Motion.brushDuration('あ' * 100), Motion.brushMax);
  });
}
