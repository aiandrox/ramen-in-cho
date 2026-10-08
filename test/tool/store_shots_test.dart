import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/home/app_tab.dart';
import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';
import 'package:ramen_in_cho/features/record/record_result_screen.dart';
import 'package:ramen_in_cho/features/record/record_screen.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/rank_history.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/shop_candidate.dart';
import 'package:ramen_in_cho/features/visit_detail/visit_detail_screen.dart';
import 'package:ramen_in_cho/theme/app_theme.dart';
import 'package:ramen_in_cho/theme/washi.dart';

import '../support/builders.dart';
import '../support/fakes.dart';
import '../support/l10n.dart';
import 'shot_kit.dart';

/// App Store・Google Play のスクリーンショットを、架空のデータで実際の画面を描いて
/// `docs/release/screenshots/` に作る（どの画像をどの欄に入れるかは store-listing.md）。
///
/// ふだんは、どの場面もどの大きさで描けることと、画像がそろって決まりの大きさであることを確かめる。
/// 画面を変えたら
/// `flutter test --dart-define=UPDATE_STORE_SHOTS=true test/tool/store_shots_test.dart`
/// で作り直す（JPEG にするので macOS の `sips` を使う）。
/// 店名・地名・座標はすべて架空のもの。実在の人や店、利用者の住まいの近くの地名・座標は使わない。
const _update = bool.fromEnvironment('UPDATE_STORE_SHOTS');
const _dir = 'docs/release/screenshots';
const _jpegQuality = 82;

/// ストアの枠ごとの画像の大きさ（px）と、中に描く画面の論理サイズ。
enum StoreDevice {
  iphone69(
    canvas: Size(1320, 2868),
    screen: Size(440, 956),
    captionScale: 0.066,
  ),
  iphone65(
    canvas: Size(1284, 2778),
    screen: Size(428, 926),
    captionScale: 0.066,
  ),
  android(
    canvas: Size(1080, 1920),
    screen: Size(400, 740),
    captionScale: 0.066,
  ),
  ipad13(
    canvas: Size(2064, 2752),
    screen: Size(1032, 1376),
    captionScale: 0.044,
  );

  const StoreDevice({
    required this.canvas,
    required this.screen,
    required this.captionScale,
  });

  final Size canvas;
  final Size screen;

  /// 見出しの文字の大きさ（画像の幅に対する割合）。
  final double captionScale;
}

/// 並べる順の場面と、上に重ねる見出し（store-listing.md と同じ文）。
enum StoreShot {
  inchou('一杯ごとに、印を押す'),
  record('店内で、片手で記録'),
  result('並んだ時間が、修行点に'),
  shugyo('段位を上げ、秘伝を会得する'),
  journey('歩いた道が、旅路になる'),
  shop('一杯ごとに綴られる道中記');

  const StoreShot(this.caption);

  final String caption;

  String fileFor(StoreDevice device) =>
      '$_dir/${device.name}/${index + 1}-$name.jpg';
}

const _featureGraphic = '$_dir/android/feature-graphic.jpg';
const _featureSize = Size(1024, 500);

final _now = DateTime(2026, 10, 5, 19, 30);
const _here = GeoPoint(35.0, 139.0);

Shop _shop(String id, String name, double lat, double lng) =>
    buildShop(id: id, name: name, latitude: lat, longitude: lng);

final _kasumi = _shop('kasumi', '麺屋 かすみ', 35.0025, 139.0);
final _seiran = _shop('seiran', '中華そば 青嵐', 35.012, 139.018);
final _tsukishiro = _shop('tsukishiro', 'らぁ麺 月白', 35.006, 138.992);
final _shijima = _shop('shijima', 'つけ麺 しじま', 35.03, 138.98);
final _suzune = _shop('suzune', '煮干し 鈴音', 35.06, 139.04);
final _kogarashi = _shop('kogarashi', '味噌らーめん 木枯', 34.98, 139.05);
final _hoshimi = _shop('hoshimi', '豚骨 星見屋', 34.97, 138.99);
final _nagi = _shop('nagi', '塩そば 凪', 35.045, 138.965);
final _yukimi = _shop('yukimi', '鶏白湯 雪見', 35.02, 139.06);
final _koharu = _shop('koharu', '油そば 小春', 34.995, 139.03);

final _shops = [
  _kasumi,
  _seiran,
  _tsukishiro,
  _shijima,
  _suzune,
  _kogarashi,
  _hoshimi,
  _nagi,
  _yukimi,
  _koharu,
];

/// 系統ごとの写真の代わり（スープの色を変えた丼の絵）。
const _soups = {
  RamenStyle.shoyu: Color(0xFF8A4A22),
  RamenStyle.shio: Color(0xFFE2C27E),
  RamenStyle.miso: Color(0xFFB4732F),
  RamenStyle.tonkotsu: Color(0xFFEDE0C6),
  RamenStyle.tsukemen: Color(0xFF5A2E16),
  RamenStyle.shirunashi: Color(0xFFD9A55A),
  RamenStyle.other: Color(0xFFF0DDB0),
};

String _photoFor(RamenStyle style) => 'bowl-${style.name}.png';

typedef _Bowl = ({
  String id,
  Shop shop,
  DateTime at,
  int? wait,
  RamenStyle style,
  int rating,
  bool limited,
  bool retreated,
  String memo,
});

_Bowl _bowl(
  String id,
  Shop shop,
  DateTime at,
  RamenStyle style, {
  int? wait,
  int rating = 4,
  bool limited = false,
  bool retreated = false,
  String memo = '',
}) => (
  id: id,
  shop: shop,
  at: at,
  wait: wait,
  style: style,
  rating: rating,
  limited: limited,
  retreated: retreated,
  memo: memo,
);

DateTime _d(int month, int day, [int hour = 12, int minute = 20]) =>
    DateTime(2026, month, day, hour, minute);

/// 古い順。半年ほど、週に1〜2杯ずつ食べてきた記録。
final _bowls = [
  _bowl('b01', _kasumi, _d(4, 4), RamenStyle.shoyu, wait: 15, rating: 4),
  _bowl('b02', _seiran, _d(4, 12), RamenStyle.shoyu, wait: 10),
  _bowl('b03', _kogarashi, _d(4, 19, 19), RamenStyle.miso, rating: 3),
  _bowl('b04', _kasumi, _d(4, 26), RamenStyle.shoyu, wait: 25, rating: 5),
  _bowl('b05', _hoshimi, _d(5, 3, 20), RamenStyle.tonkotsu, wait: 5),
  _bowl('b06', _shijima, _d(5, 10), RamenStyle.tsukemen, wait: 40, rating: 5),
  _bowl('b07', _nagi, _d(5, 17, 11), RamenStyle.shio, retreated: true),
  _bowl('b08', _kasumi, _d(5, 24), RamenStyle.shoyu, wait: 20),
  _bowl('b09', _nagi, _d(5, 31, 11), RamenStyle.shio, wait: 30, rating: 5),
  _bowl('b11', _suzune, _d(6, 14), RamenStyle.shoyu, wait: 45, limited: true),
  _bowl('b14', _kasumi, _d(7, 5), RamenStyle.shoyu, wait: 30, limited: true),
  _bowl('b15', _shijima, _d(7, 12), RamenStyle.tsukemen, wait: 50),
  _bowl('b18', _suzune, _d(8, 2), RamenStyle.shoyu, wait: 35),
  _bowl('b20', _nagi, _d(8, 16, 11), RamenStyle.shio, wait: 25),
  _bowl('b21', _kasumi, _d(8, 23), RamenStyle.shoyu, wait: 20, rating: 5),
  _bowl('b22', _yukimi, _d(8, 30, 18), RamenStyle.other, wait: 15),
  _bowl('b23', _shijima, _d(9, 6), RamenStyle.tsukemen, wait: 60, rating: 5),
  _bowl('b24', _seiran, _d(9, 13), RamenStyle.shoyu, wait: 20),
  _bowl(
    'b25',
    _suzune,
    _d(9, 20),
    RamenStyle.shoyu,
    wait: 55,
    limited: true,
    rating: 5,
  ),
  _bowl(
    'b26',
    _kasumi,
    _d(9, 27),
    RamenStyle.shoyu,
    wait: 35,
    rating: 5,
    memo: '秋限定の煮干しが沁みた',
  ),
  _bowl(
    'today',
    _tsukishiro,
    _d(10, 5, 18, 50),
    RamenStyle.shio,
    wait: 40,
    limited: true,
    rating: 5,
  ),
];

/// 店のページで開く1杯。
const _shopVisitId = 'b26';

List<VisitWithShop> _visits() => [
  for (final bowl in _bowls.reversed)
    VisitWithShop(
      shop: bowl.shop,
      visit: buildVisit(
        id: bowl.id,
        shopId: bowl.shop.id,
        result: bowl.retreated ? VisitResult.retreated : VisitResult.eaten,
        eatenAt: bowl.at,
        waitMinutes: bowl.wait,
        style: bowl.style,
        rating: bowl.rating,
        isLimited: bowl.limited,
        memo: bowl.memo,
        photoPath: bowl.retreated ? null : _photoFor(bowl.style),
      ),
    ),
];

final _wishes = [
  Wish(
    id: 'w1',
    name: 'らぁめん 月見坂',
    latitude: 35.004,
    longitude: 139.004,
    trigger: '友だちのすすめ',
    note: '塩が名物らしい',
    createdAt: DateTime(2026, 9, 12),
  ),
  Wish(
    id: 'w2',
    name: '鶏そば 若竹',
    latitude: 35.05,
    longitude: 139.0,
    trigger: '雑誌で見た',
    createdAt: DateTime(2026, 8, 20),
  ),
  Wish(
    id: 'w3',
    shopId: _shijima.id,
    name: _shijima.name,
    createdAt: DateTime(2026, 4, 30),
    fulfilledVisitId: 'b06',
  ),
];

const _candidates = [
  ShopCandidate(
    name: 'らぁめん 月見坂',
    location: GeoPoint(35.004, 139.004),
    distanceMeters: 30,
    wishId: 'w1',
  ),
  ShopCandidate(
    osmId: 'node/21',
    name: '中華そば 白露',
    location: GeoPoint(35.0025, 138.996),
    distanceMeters: 140,
  ),
  ShopCandidate(
    shopId: 'kasumi',
    name: '麺屋 かすみ',
    location: GeoPoint(35.0025, 139.0),
    distanceMeters: 280,
  ),
];

final _world = ShotWorld(
  visits: _visits(),
  wishes: _wishes,
  shops: _shops,
  found: const [
    FoundShop(
      osmId: 'node/21',
      name: '中華そば 白露',
      location: GeoPoint(35.0025, 138.996),
    ),
  ],
  homeBases: [buildHomeBase(name: 'みどり台駅', setAt: DateTime(2026))],
  now: _now,
  here: _here,
);

ShotScene _sceneFor(StoreShot shot) => switch (shot) {
  StoreShot.inchou => const ShotScene(tab: AppTab.records),
  StoreShot.record => ShotScene(
    home: const RecordScreen(),
    candidates: _candidates,
    act: (tester) async {
      await tester.tap(find.text(ja.takePhoto));
      await settleShot(tester);
      await tester.tap(find.text(_candidates.first.name));
      await settleShot(tester);
    },
  ),
  StoreShot.result => const ShotScene(
    home: RecordResultScreen(visitId: 'today'),
  ),
  StoreShot.shugyo => const ShotScene(tab: AppTab.shugyo),
  StoreShot.journey => ShotScene(
    tab: AppTab.map,
    act: (tester) async {
      await tester.tap(find.byTooltip(ja.journeyToggle));
      await settleShot(tester);
    },
  ),
  StoreShot.shop => ShotScene(
    home: const VisitDetailScreen(visitId: _shopVisitId),
    act: (tester) async {
      // 印の並びを画面の上に置き、その下に道中記を見せる。
      final stamps = find.text(ja.shopStamps);
      await tester.scrollUntilVisible(
        stamps,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(stamps));
      await settleShot(tester);
    },
  ),
};

void main() {
  late Directory documents;
  late String photo;
  WidgetsApp.debugAllowBannerOverride = false;

  setUpAll(() async {
    documents = createTempDirectory();
    photo = p.join(documents.path, 'camera.png');
    if (!_update) {
      File(photo).writeAsBytesSync(const []);
      return;
    }
    await loadShotFonts();
    File(photo)
        .writeAsBytesSync(await bowlPhoto(soup: _soups[RamenStyle.shio]!));
    for (final MapEntry(key: style, value: soup) in _soups.entries) {
      File(p.join(documents.path, _photoFor(style)))
          .writeAsBytesSync(await bowlPhoto(soup: soup));
    }
  });

  test('架空の記録は場面の案どおり（最後の一杯で三段に昇段する）', () {
    final scored = scoreVisits(
      _world.visits,
      wishes: _wishes,
      homeBases: _world.homeBases,
    );
    final history = rankHistory(scored);
    expect(history.last.rank, AdventurerRank.dan3);
    expect(history.last.visit?.visit.id, 'today');
    final today = scored.last;
    expect(today.points.waitBonus, greaterThan(0));
    expect(today.points.limitedBonus, greaterThan(0));
    expect(today.points.firstVisitBonus, greaterThan(0));
    final grades = {
      for (final entry in scored) shopRankFor(entry.points.total),
    };
    expect(grades, containsAll([ShopRank.s, ShopRank.a]));
  });

  testWidgets('画像がそろっていて、決まりの大きさ', (tester) async {
    final files = {
      for (final device in StoreDevice.values)
        for (final shot in StoreShot.values)
          shot.fileFor(device): device.canvas,
      _featureGraphic: _featureSize,
    };
    for (final MapEntry(key: path, value: size) in files.entries) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
        return (await codec.getNextFrame()).image;
      });
      expect(
        Size(image!.width.toDouble(), image.height.toDouble()),
        size,
        reason: path,
      );
    }
  }, skip: _update);

  for (final device in StoreDevice.values) {
    for (final shot in StoreShot.values) {
      testWidgets('スクリーンショット ${device.name} ${shot.name}', (tester) async {
        final boundary = GlobalKey();
        await pumpShot(
          tester,
          _world,
          _sceneFor(shot),
          boundary: boundary,
          size: device.screen,
          photo: photo,
          documents: documents,
          render: _update,
        );
        expect(tester.takeException(), isNull);
        if (!_update) return;
        await tester.runAsync(() async {
          final layout = _Layout(device);
          final screen = await captureShot(
            boundary,
            layout.screen.width / device.screen.width,
          );
          final image = await _compose(device, shot.caption, screen, layout);
          await _writeJpeg(image, shot.fileFor(device));
        });
      });
    }
  }

  testWidgets('Google Play のフィーチャー グラフィック', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = _featureSize * 2;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final scored = scoreVisits(
      _world.visits,
      wishes: _wishes,
      homeBases: _world.homeBases,
    );
    ScoredVisit pick(ShopRank rank) => scored.lastWhere(
      (entry) =>
          entry.visit.result == VisitResult.eaten &&
          shopRankFor(entry.points.total) == rank,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: localizedApp(
          theme: buildAppTheme(),
          home: _FeatureGraphic(
            stamps: [pick(ShopRank.b), pick(ShopRank.s), pick(ShopRank.a)],
          ),
        ),
      ),
    );
    await settleShot(tester);
    expect(tester.takeException(), isNull);
    if (!_update) return;
    await tester.runAsync(() async {
      final image = await captureShot(boundary, 1);
      await _writeJpeg(image, _featureGraphic);
    });
  });
}

/// 見出しと画面を置く位置（px）。
class _Layout {
  factory _Layout(StoreDevice device) {
    final canvas = device.canvas;
    final fontSize = canvas.width * device.captionScale;
    final top = canvas.width * 0.06;
    final captionHeight = fontSize * 1.5;
    final gap = canvas.width * 0.035;
    final screenTop = top + captionHeight + gap;
    final maxWidth = canvas.width * 0.88;
    final maxHeight = canvas.height - screenTop - gap;
    final aspect = device.screen.height / device.screen.width;
    final width = maxHeight / aspect < maxWidth ? maxHeight / aspect : maxWidth;
    final screen = Rect.fromLTWH(
      ((canvas.width - width) / 2).roundToDouble(),
      screenTop.roundToDouble(),
      width.roundToDouble(),
      (width * aspect).roundToDouble(),
    );
    return _Layout._(fontSize, top, captionHeight, screen);
  }

  const _Layout._(this.fontSize, this.top, this.captionHeight, this.screen);

  final double fontSize;
  final double top;
  final double captionHeight;
  final Rect screen;
}

/// 和紙の地に見出しを書き、その下に縁を付けた画面を置く。
Future<ui.Image> _compose(
  StoreDevice device,
  String caption,
  ui.Image screen,
  _Layout layout,
) async {
  final size = device.canvas;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = Washi.desk);

  final paragraph =
      (ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textAlign: TextAlign.center,
                fontFamily: Washi.brush,
                fontSize: layout.fontSize,
                height: 1.5,
              ),
            )
            ..pushStyle(ui.TextStyle(color: Washi.ink))
            ..addText(caption))
          .build()
        ..layout(ui.ParagraphConstraints(width: size.width));
  canvas.drawParagraph(
    paragraph,
    Offset(0, layout.top + (layout.captionHeight - paragraph.height) / 2),
  );

  final rect = layout.screen;
  final frame = RRect.fromRectAndRadius(
    rect,
    Radius.circular(rect.width * 0.05),
  );
  canvas.drawShadow(
    Path()..addRRect(frame),
    Washi.ink.withValues(alpha: 0.5),
    rect.width * 0.02,
    false,
  );
  canvas
    ..save()
    ..clipRRect(frame)
    ..drawImage(
      screen,
      rect.topLeft,
      Paint()..filterQuality = FilterQuality.high,
    )
    ..restore();
  canvas.drawRRect(
    frame,
    Paint()
      ..color = Washi.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.008,
  );
  return recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
}

/// 透過の無い JPEG にする（ストアは透過のある画像を受け付けない）。
Future<void> _writeJpeg(ui.Image image, String path) async {
  final png = p.join(createTempDirectory().path, 'shot.png');
  File(png).writeAsBytesSync(await encodePng(image));
  File(path).parent.createSync(recursive: true);
  final result = await Process.run('sips', [
    '-s',
    'format',
    'jpeg',
    '-s',
    'formatOptions',
    '$_jpegQuality',
    png,
    '--out',
    path,
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

/// Google Play の掲載の上に出る横長の絵。題と、格のちがう印を3つ。
class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic({required this.stamps});

  final List<ScoredVisit> stamps;

  @override
  Widget build(BuildContext context) => Material(
    color: Washi.desk,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '麺印帳',
                  style: TextStyle(
                    fontFamily: Washi.brush,
                    fontSize: 112,
                    color: Washi.ink,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '一杯ごとに印を押す、麺道の修行帳',
                  style: TextStyle(
                    fontFamily: Washi.mincho,
                    fontSize: 26,
                    color: Washi.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          for (final (index, stamp) in stamps.indexed)
            Transform.rotate(
              angle: [-0.12, 0.06, -0.04][index],
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkanStamp(scored: stamp, size: 136),
              ),
            ),
        ],
      ),
    ),
  );
}
