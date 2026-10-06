import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/quests/quest_seal.dart';
import 'package:ramen_in_cho/features/quests/quests.dart';

import '../support/l10n.dart';

/// 秘伝の一覧（管理用）を `docs/hiden/` に作る。
///
/// ふだんは一覧がクエストの定義と合っているかを確かめる。秘伝を足したり変えたりしたら、
/// `flutter test --dart-define=UPDATE_HIDEN_CATALOG=true test/tool/hiden_catalog_test.dart`
/// で作り直す。
const _dir = 'docs/hiden';
const _update = bool.fromEnvironment('UPDATE_HIDEN_CATALOG');

const _shapeNames = {
  QuestSealShape.eightRing: '8つの丸の輪',
  QuestSealShape.doubleCircle: '二重丸',
  QuestSealShape.square: '角',
  QuestSealShape.octagon: '八角形',
  QuestSealShape.diamond: '菱形',
  QuestSealShape.hexagon: '六角形',
  QuestSealShape.flower: '花',
  QuestSealShape.dottedRing: '点の輪',
  QuestSealShape.castle: '城壁',
  QuestSealShape.sunburst: '光の筋',
  QuestSealShape.crescent: '三日月',
  QuestSealShape.triangle: '三角',
  QuestSealShape.pill: '縦長の角丸',
  QuestSealShape.boldRing: '太い輪',
  QuestSealShape.dashedRing: '切れ目の輪',
  QuestSealShape.pentagon: '五角形',
  QuestSealShape.star: '星',
  QuestSealShape.garlic: 'にんにく',
  QuestSealShape.compass: '方位',
  QuestSealShape.cornerDots: '四隅の点',
  QuestSealShape.wave: '波',
  QuestSealShape.fortySevenDots: '47の点の輪',
  QuestSealShape.globe: '地球儀',
};

String _date(DateTime d) => '${d.year}/${d.month}/${d.day}';

String _period(Quest quest) {
  final from = quest.availableFrom;
  final until = quest.availableUntil;
  if (from == null && until == null) return 'いつでも';
  final end = until?.subtract(const Duration(days: 1));
  return '${from == null ? '' : _date(from)}〜${end == null ? '' : _date(end)}';
}

List<Quest> get _spots => [
  for (final quest in quests)
    if (quest.kind == QuestKind.spot) quest,
];

String catalogMarkdown() {
  final buffer = StringBuffer()
    ..writeln('# 秘伝の一覧')
    ..writeln()
    ..writeln('アプリに出てくる秘伝（1回きりのクエスト）の印と内容の一覧。管理用。')
    ..writeln()
    ..writeln('- 定義は `lib/features/quests/quests.dart`。期間限定の秘伝も、期間が過ぎたら消さずに残す')
    ..writeln(
      '- 秘伝を足したり変えたりしたら `flutter test --dart-define=UPDATE_HIDEN_CATALOG=true '
      'test/tool/hiden_catalog_test.dart` でこの一覧と印の画像を作り直す',
    )
    ..writeln('- 印の日付は見本（2026/10/3）')
    ..writeln()
    ..writeln('| 印 | 名前 | 会得の条件 | 字 | 形 | 期間 | ID |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final quest in _spots) {
    final seal = quest.seal;
    buffer.writeln(
      '| <img src="${quest.id}.png" width="72"> '
      '| ${quest.title} '
      '| ${quest.description} '
      '| ${seal?.glyph ?? ''} '
      '| ${seal == null ? '' : _shapeNames[seal.shape]} '
      '| ${_period(quest)} '
      '| `${quest.id}` |',
    );
  }
  return buffer.toString();
}

void main() {
  test('すべての秘伝に、それぞれ違う印がある', () {
    final designs = <String>{};
    for (final quest in _spots) {
      final seal = quest.seal;
      expect(seal, isNotNull, reason: quest.id);
      expect(
        designs.add('${seal!.glyph}:${seal.shape}'),
        isTrue,
        reason: '${quest.id} の印がほかと同じ',
      );
    }
  });

  testWidgets('秘伝の一覧が定義と合っている', (tester) async {
    final readme = File('$_dir/README.md');
    if (!_update) {
      expect(
        readme.existsSync() ? readme.readAsStringSync() : '',
        catalogMarkdown(),
        reason:
            '秘伝の定義が変わったので、一覧を作り直してください: '
            'flutter test --dart-define=UPDATE_HIDEN_CATALOG=true test/tool/hiden_catalog_test.dart',
      );
      for (final quest in _spots) {
        expect(File('$_dir/${quest.id}.png').existsSync(), isTrue);
      }
      return;
    }

    await (FontLoader(
      'YujiSyuku',
    )..addFont(rootBundle.load('assets/fonts/YujiSyuku-Regular.ttf'))).load();
    Directory(_dir).createSync(recursive: true);
    for (final quest in _spots) {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        localizedApp(
          home: Material(
            type: MaterialType.transparency,
            child: Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox.square(
                  dimension: 140,
                  child: Center(
                    child: QuestSeal(
                      quest: quest,
                      level: 1,
                      size: 120,
                      achievedAt: DateTime(2026, 10, 3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_dir/${quest.id}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    readme.writeAsStringSync(catalogMarkdown());
  });
}
