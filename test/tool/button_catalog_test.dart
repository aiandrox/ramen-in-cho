import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/theme/app_theme.dart';
import 'package:ramen_in_cho/theme/washi.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';

/// ボタンの見本帳（確認用）を `docs/buttons/` に作る。
///
/// ふだんは見本帳が組み立てられることだけを確かめる。ボタンの見た目を変えたら、
/// `flutter test --dart-define=UPDATE_BUTTON_CATALOG=true test/tool/button_catalog_test.dart`
/// で画像を作り直す。
const _dir = 'docs/buttons';
const _update = bool.fromEnvironment('UPDATE_BUTTON_CATALOG');

void _noop() {}

Widget _label(String text, {required bool night}) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 6),
  child: Text(
    text,
    style: TextStyle(
      fontFamily: Washi.mincho,
      fontSize: 12,
      color: night ? Washi.nightSoft : Washi.faded,
    ),
  ),
);

Widget _panel({required bool night}) {
  final children = <Widget>[
    _label('藍札（いちばん大事な決定）', night: night),
    AiFuda(
      expand: true,
      height: 60,
      fontSize: 26,
      onPressed: _noop,
      child: const Text('着丼！'),
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: AiFuda(
            night: night,
            expand: true,
            onPressed: _noop,
            icon: const Icon(Icons.ios_share),
            child: const Text('共有する'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AiFuda(
            night: night,
            expand: true,
            onPressed: null,
            child: const Text('押せない'),
          ),
        ),
      ],
    ),
    _label('墨札（ほかの選び方・寄り道）', night: night),
    Row(
      children: [
        Expanded(
          child: SumiFuda(
            night: night,
            expand: true,
            onPressed: _noop,
            child: const Text('印帳にもどる'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SumiFuda(
            night: night,
            expand: true,
            onPressed: null,
            child: const Text('押せない'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    SumiFuda(
      night: night,
      expand: true,
      onPressed: _noop,
      icon: const Icon(Icons.groups),
      child: const Text('いま並んでいる'),
    ),
    _label('消し札（取り消し・撤退・削除）', night: night),
    Row(
      children: [
        KeshiFuda(night: night, onPressed: _noop, child: const Text('撤退')),
        const SizedBox(width: 12),
        KeshiFuda(night: night, onPressed: _noop, child: const Text('削除')),
        const SizedBox(width: 12),
        KeshiFuda(night: night, onPressed: null, child: const Text('押せない')),
      ],
    ),
    _label('筆の下線（控えめな文字リンク）', night: night),
    Wrap(
      children: [
        FudeLink(
          night: night,
          onPressed: _noop,
          icon: const Icon(Icons.travel_explore),
          child: const Text('地図に載せる（店名で探す）'),
        ),
        FudeLink(night: night, onPressed: _noop, child: const Text('取り消す')),
        FudeLink(night: night, onPressed: null, child: const Text('押せない')),
      ],
    ),
    _label('丸印（画面に浮かぶボタン）', night: night),
    Row(
      children: [
        RecordSealButton(tooltip: '記録する', onPressed: _noop),
        const SizedBox(width: 16),
        ShioriFab(tooltip: '願を足す', onPressed: _noop),
        const SizedBox(width: 16),
        SealFab(
          tooltip: '探す',
          onPressed: _noop,
          child: const Icon(Icons.search),
        ),
        const SizedBox(width: 16),
        SealFab(
          tooltip: '現在地',
          sumi: true,
          small: true,
          onPressed: _noop,
          child: const Icon(Icons.my_location),
        ),
      ],
    ),
    if (!night) ...[
      _label('選ぶ札（系統・営業の条件・年）', night: night),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            label: const Text('醤油'),
            selected: true,
            onSelected: (_) {},
          ),
          ChoiceChip(
            label: const Text('味噌'),
            selected: false,
            onSelected: (_) {},
          ),
          FilterChip(
            label: const Text('昼のみ'),
            selected: true,
            onSelected: (_) {},
          ),
          FilterChip(
            label: const Text('不定休'),
            selected: false,
            onSelected: (_) {},
          ),
          ActionChip(label: const Text('売り切れ'), onPressed: _noop),
        ],
      ),
      _label('確かめる窓の下の並び', night: night),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: _noop, child: const Text('キャンセル')),
          const SizedBox(width: 8),
          KeshiFuda(onPressed: _noop, child: const Text('削除')),
          const SizedBox(width: 8),
          AiFuda(onPressed: _noop, child: const Text('保存')),
        ],
      ),
    ],
  ];
  return Container(
    width: 380,
    color: night ? Washi.ink : Washi.paper,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    ),
  );
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync()))))
      .load();
}

void main() {
  testWidgets('ボタンの見本帳', (tester) async {
    final boundary = GlobalKey();
    if (_update) {
      await tester.runAsync(() async {
        await _loadFont('YujiSyuku', 'assets/fonts/YujiSyuku-Regular.ttf');
        await _loadFont(
          'ShipporiMincho',
          'assets/fonts/ShipporiMincho-Regular.ttf',
        );
        final root = Platform.environment['FLUTTER_ROOT'];
        if (root != null) {
          await _loadFont(
            'MaterialIcons',
            '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          );
        }
      });
    }
    tester.view.physicalSize = const Size(800, 1000) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: boundary,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [_panel(night: false), _panel(night: true)],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    if (!_update) return;

    Directory(_dir).createSync(recursive: true);
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_dir/catalog.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
