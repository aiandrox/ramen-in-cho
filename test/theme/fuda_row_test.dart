import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/theme/app_theme.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );

  List<Size> sizesOf(WidgetTester tester, List<Type> types) => [
    for (final type in types) tester.getSize(find.byType(type)),
  ];

  TextStyle? labelStyle(WidgetTester tester, String text) => tester
      .widget<RichText>(
        find.descendant(of: find.text(text), matching: find.byType(RichText)),
      )
      .text
      .style;

  testWidgets('横に並べた札は、役割が違っても同じ大きさ・同じ字の大きさになる', (tester) async {
    await pump(
      tester,
      FudaRow(
        children: [
          KeshiFuda(onPressed: () {}, child: const Text('撤退')),
          SumiFuda(onPressed: () {}, child: const Text('印帳にもどる')),
          AiFuda(
            onPressed: () {},
            icon: const Icon(Icons.ios_share),
            child: const Text('着丼！'),
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);

    final sizes = sizesOf(tester, [KeshiFuda, SumiFuda, AiFuda]);
    expect(sizes.toSet(), hasLength(1));
    expect(sizes.first.height, FudaStyle.defaultHeight);
    expect(sizes.first.width, closeTo((360 - 12 * 2) / 3, 0.01));

    for (final text in ['撤退', '印帳にもどる', '着丼！']) {
      expect(labelStyle(tester, text)?.fontSize, FudaStyle.rowFontSize);
    }
  });

  testWidgets('幅の狭い画面でも、2つ並べた札の字は1行に収まる', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 320 - 32,
        child: FudaRow(
          height: 56,
          children: [
            AiFuda(
              onPressed: () {},
              icon: const Icon(Icons.ios_share),
              child: const Text('共有する'),
            ),
            SumiFuda(onPressed: () {}, child: const Text('印帳にもどる')),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final text in ['共有する', '印帳にもどる']) {
      final height = tester.getSize(find.text(text)).height;
      expect(height, lessThan(FudaStyle.rowFontSize * 2), reason: text);
    }
  });

  testWidgets('縦に積んだ札も、同じ幅・同じ高さになる', (tester) async {
    await pump(
      tester,
      FudaRow(
        direction: Axis.vertical,
        height: 56,
        children: [
          AiFuda(onPressed: () {}, child: const Text('下書きに残してやめる')),
          KeshiFuda(onPressed: () {}, child: const Text('破棄してやめる')),
        ],
      ),
    );
    expect(tester.takeException(), isNull);

    final sizes = sizesOf(tester, [AiFuda, KeshiFuda]);
    expect(sizes, everyElement(const Size(360, 56)));
  });

  testWidgets('並べないときも、3つの札の高さは同じ', (tester) async {
    await pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiFuda(onPressed: () {}, child: const Text('保存')),
          SumiFuda(onPressed: () {}, child: const Text('読み込む')),
          KeshiFuda(onPressed: () {}, child: const Text('削除')),
        ],
      ),
    );

    final heights = [
      for (final type in [AiFuda, SumiFuda, KeshiFuda])
        tester.getSize(find.byType(type)).height,
    ];
    expect(heights, everyElement(FudaStyle.defaultHeight));
  });
}
