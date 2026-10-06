import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/style_tiles.dart';
import 'package:ramen_in_cho/theme/app_theme.dart';

import '../../support/l10n.dart';

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  RamenStyle? style;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: RamenStyleTiles(
        selected: style,
        onChanged: (value) => setState(() => style = value),
      ),
    ),
  );
}

void main() {
  testWidgets('系統の札を押すと選ばれ、もう一度押すと外れる', (tester) async {
    await tester.pumpWidget(
      localizedApp(theme: buildAppTheme(), home: const _Harness()),
    );
    final state = tester.state<_HarnessState>(find.byType(_Harness));

    for (final label in [
      ja.styleShoyu,
      ja.styleMiso,
      ja.styleShio,
      ja.styleTonkotsu,
      ja.styleIekei,
      ja.styleJiro,
      ja.styleTsukemen,
      ja.styleShirunashi,
      ja.styleOther,
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text(ja.styleJiro));
    await tester.pump();
    expect(state.style, RamenStyle.jiro);

    await tester.tap(find.text(ja.styleMiso));
    await tester.pump();
    expect(state.style, RamenStyle.miso);

    await tester.tap(find.text(ja.styleMiso));
    await tester.pump();
    expect(state.style, isNull);
    expect(tester.takeException(), isNull);
  });

  test('札は横幅いっぱいに、行ごとの数がそろうように並べる', () {
    expect(RamenStyleTiles.columnsFor(328, 9), 5);
    expect(RamenStyleTiles.columnsFor(600, 9), 9);
    expect(RamenStyleTiles.columnsFor(240, 9), 3);
  });

  testWidgets('系統の札は1行の幅をすき間なく使う', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(theme: buildAppTheme(), home: const _Harness()),
    );
    final row = tester.getRect(find.byType(RamenStyleTiles));
    final last = tester.getRect(
      find
          .ancestor(
            of: find.text(ja.styleIekei),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(last.right, moreOrLessEquals(row.right, epsilon: 0.5));
  });

  testWidgets('選ぶ札はチェックを出さず、選んでも幅が変わらない', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      localizedApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FilterChip(
              label: const Text('札'),
              selected: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    final chip = find.widgetWithText(FilterChip, '札');
    final before = tester.getSize(chip);

    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(selected, isTrue);
    expect(tester.getSize(chip), before);
    final theme = Theme.of(tester.element(chip)).chipTheme;
    expect(theme.showCheckmark, isFalse);
  });
}
