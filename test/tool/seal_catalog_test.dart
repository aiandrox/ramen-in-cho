import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';
import 'package:ramen_in_cho/features/prefecture/regions.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/theme/washi.dart';

import '../support/builders.dart';
import '../support/l10n.dart';

/// 地方の印の見本帳（管理用）を `docs/seals/` に作る。
///
/// ふだんは見本帳が印の描き方と合っているかを、描き方のファイルの指紋で確かめる。印の形や飾りを変えたら、
/// `flutter test --dart-define=UPDATE_SEAL_CATALOG=true test/tool/seal_catalog_test.dart`
/// で作り直す。
const _dir = 'docs/seals';
const _update = bool.fromEnvironment('UPDATE_SEAL_CATALOG');

/// 印の見た目を決めるファイル。どれかが変わったら見本帳を作り直す。
const _sources = [
  'lib/features/inkan/inkan_stamp.dart',
  'lib/features/inkan/region_frame.dart',
  'lib/features/prefecture/regions.dart',
];

const _regions = <Region, (String, String, String)>{
  Region.hokkaido: ('北海道', '雪の結晶のような、角を上にした六角', '北海道'),
  Region.tohoku: ('東北', '米粒のような縦長の楕円', '宮城県'),
  Region.kanto: ('関東', '角印（角の丸い四角）', '東京都'),
  Region.chubu: ('中部', '上に三つの山を持つ四角', '長野県'),
  Region.kinki: ('近畿', '瓦（下は角、上は丸い）', '京都府'),
  Region.chugoku: ('中国', '瀬戸内の波（細かくうねる輪）', '広島県'),
  Region.shikoku: ('四国', '四つ割り（上下左右に切れ込みのある輪）', '香川県'),
  Region.kyushu: ('九州・沖縄', '南国の花（八枚の花びら）', '沖縄県'),
};

/// 格ごとの見本の修行点（易・厳・難・極の境の内側）。
const _grades = [('易', 20), ('厳', 30), ('難', 45), ('極', 70)];

/// 描き方のファイルの指紋（FNV-1a）。
String sourceFingerprint() {
  var hash = 0x811c9dc5;
  for (final path in _sources) {
    for (final byte in utf8.encode(File(path).readAsStringSync())) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String catalogMarkdown() {
  final buffer = StringBuffer()
    ..writeln('# 地方の印')
    ..writeln()
    ..writeln('1杯ごとの印の外枠は、店のある都道府県の地方で形が変わる。管理用。')
    ..writeln()
    ..writeln(
      '- 外枠は `lib/features/inkan/region_frame.dart`、格の飾りは `lib/features/inkan/inkan_stamp.dart` の `RegionalInkanPainter`',
    )
    ..writeln(
      '- 格（易・厳・難・極）の飾りは外枠の上に重ねる: 易＝細い枠 / 厳＝二重枠と点の輪 / 難＝三重枠と点線と四隅の菱形 / 極＝朱塗りと金の輪と外側の点',
    )
    ..writeln('- 印の下に短い都道府県名（「東京」「北海道」など）を入れる。都道府県のわからない店は、今までの丸・角の印のまま')
    ..writeln('- 撤退の印も地方の形で灰色に塗る')
    ..writeln(
      '- 印の描き方を変えたら `flutter test --dart-define=UPDATE_SEAL_CATALOG=true '
      'test/tool/seal_catalog_test.dart` で、この一覧と画像を作り直す（作り直さないとテストが失敗する）',
    )
    ..writeln()
    ..writeln('![地方の印の見本帳](catalog.png)')
    ..writeln()
    ..writeln('| 地方 | 外枠 | 都道府県 | 見本 |')
    ..writeln('|---|---|---|---|');
  for (final MapEntry(key: region, value: (name, frame, sample))
      in _regions.entries) {
    buffer.writeln(
      '| $name | $frame | ${prefecturesIn(region).join('・')} | $sample |',
    );
  }
  buffer
    ..writeln()
    ..writeln('<!-- 描き方の指紋: ${sourceFingerprint()} -->');
  return buffer.toString();
}

ScoredVisit _sample(String prefecture, int points, int index) => ScoredVisit(
  visit: buildVisit(
    id: 'seal-$prefecture-$points',
    style: RamenStyle.values[index % 8],
    eatenAt: DateTime(2026, 10, 6, 12),
  ),
  shop: buildShop(),
  points: PointsBreakdown(
    base: points,
    waitBonus: 0,
    limitedBonus: 0,
    firstVisitBonus: 0,
    retryBonus: 0,
  ),
  isFirstVisit: false,
  isRetrySuccess: false,
  prefecture: prefecture,
);

Widget _catalog() {
  Widget cell(Widget child) =>
      SizedBox(width: 108, height: 108, child: Center(child: child));
  Widget label(String text) => SizedBox(
    width: 108,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: Washi.brush,
        fontSize: 16,
        color: Washi.ink,
      ),
    ),
  );
  var index = 0;
  return Container(
    color: Washi.paper,
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            label(''),
            for (final (grade, _) in _grades) label(grade),
            label('撤退'),
            label('まだ'),
          ],
        ),
        for (final MapEntry(key: region, value: (name, _, sample))
            in _regions.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              label(name),
              for (final (_, points) in _grades)
                cell(
                  InkanStamp(
                    scored: _sample(sample, points, index++),
                    size: 96,
                  ),
                ),
              cell(
                InkanStamp(
                  scored: ScoredVisit(
                    visit: buildVisit(
                      id: 'seal-$region-retreat',
                      result: VisitResult.retreated,
                      eatenAt: DateTime(2026, 10, 6, 12),
                    ),
                    shop: buildShop(),
                    points: PointsBreakdown.zero,
                    isFirstVisit: false,
                    isRetrySuccess: false,
                    prefecture: sample,
                  ),
                  size: 96,
                ),
              ),
              cell(
                BlankPrefectureSeal(
                  prefecture: prefecturesIn(region).last,
                  size: 80,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

void main() {
  test('8つの地方に、47都道府県がもれなく入る', () {
    expect(Region.values, hasLength(8));
    expect([
      for (final region in Region.values) ...prefecturesIn(region),
    ], prefectureNames);
  });

  testWidgets('地方の印の見本帳が、印の描き方と合っている', (tester) async {
    final readme = File('$_dir/README.md');
    tester.view.physicalSize = const Size(900, 1100) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    if (_update) {
      await tester.runAsync(() async {
        await (FontLoader('YujiSyuku')
              ..addFont(rootBundle.load('assets/fonts/YujiSyuku-Regular.ttf')))
            .load();
      });
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
      localizedApp(
        home: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: RepaintBoundary(key: boundary, child: _catalog()),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    if (!_update) {
      expect(
        readme.existsSync() ? readme.readAsStringSync() : '',
        catalogMarkdown(),
        reason:
            '印の描き方が変わったので、見本帳を作り直してください: '
            'flutter test --dart-define=UPDATE_SEAL_CATALOG=true test/tool/seal_catalog_test.dart',
      );
      expect(File('$_dir/catalog.png').existsSync(), isTrue);
      return;
    }

    Directory(_dir).createSync(recursive: true);
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_dir/catalog.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    readme.writeAsStringSync(catalogMarkdown());
  });
}
