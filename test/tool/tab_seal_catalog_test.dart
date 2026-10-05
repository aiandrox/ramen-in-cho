import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home/app_tab.dart';
import 'package:ramen_in_cho/features/home/tab_seals.dart';
import 'package:ramen_in_cho/theme/washi.dart';

/// 下のタブのアイコンの見本（確認用）を `docs/buttons/tab_seals.png` に作る。
///
/// ふだんは組み立てられることだけを確かめる。絵を変えたら
/// `flutter test --dart-define=UPDATE_TAB_SEALS=true test/tool/tab_seal_catalog_test.dart`
/// で画像を作り直す。
const _update = bool.fromEnvironment('UPDATE_TAB_SEALS');

const _labels = {
  AppTab.records: '印帳',
  AppTab.wishes: '願掛け',
  AppTab.shugyo: '修行',
  AppTab.map: '地図',
};

Widget _caption(String text) => Text(
  text,
  style: const TextStyle(
    fontFamily: Washi.mincho,
    fontSize: 12,
    color: Washi.faded,
  ),
);

Widget _row(double size) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final tab in AppTab.values)
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabSeal(tab: tab, selected: true, size: size),
                SizedBox(width: size / 4),
                TabSeal(tab: tab, selected: false, size: size),
              ],
            ),
            const SizedBox(height: 4),
            _caption(_labels[tab]!),
          ],
        ),
      ),
  ],
);

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync()))))
      .load();
}

void main() {
  testWidgets('タブのアイコンの見本', (tester) async {
    final boundary = GlobalKey();
    if (_update) {
      await tester.runAsync(
        () => _loadFont(
          'ShipporiMincho',
          'assets/fonts/ShipporiMincho-Regular.ttf',
        ),
      );
    }
    tester.view.physicalSize = const Size(1400, 600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: Container(
              color: Washi.paper,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _caption('実際の大きさ（左が選んだとき、右が選んでいないとき）'),
                  _row(32),
                  _caption('4倍'),
                  _row(128),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    if (!_update) return;

    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('docs/buttons/tab_seals.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
