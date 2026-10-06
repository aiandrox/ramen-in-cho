import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/theme/washi_sheet.dart';

void main() {
  testWidgets('タブの画面の窓は、中身が少なくても幅が変わらない', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = GlobalKey<ShellSheetHostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: ShellSheetHost(
          key: host,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    for (final text in ['短い', 'とても長い文がここに入ってもう少し長くなる']) {
      host.currentState!.show<void>(builder: (_) => Text(text));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(BottomSheet)).width, 400);
      host.currentState!.close();
      await tester.pumpAndSettle();
    }
  });
}
