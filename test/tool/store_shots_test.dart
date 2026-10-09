import 'dart:io';
import 'dart:math' as math;
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
import 'package:ramen_in_cho/features/scoring/points_breakdown_view.dart';
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
/// 画面を端末の枠に入れ、見出しと一緒に1枚ごとにちがう構図で並べる。記録の写真には
/// `docs/release/screenshots/photos/` の実写の写真を使う（使い方の絵は丼のイラストのまま）。
///
/// ふだんは、どの場面もどの大きさで描けることと、画像がそろって決まりの大きさであることを確かめる。
/// 画面を変えたら
/// `flutter test --dart-define=UPDATE_STORE_SHOTS=true test/tool/store_shots_test.dart`
/// で作り直す（JPEG にするので macOS の `sips` を使う）。
/// 店名・地名・座標はすべて架空のもの。実在の人や店、利用者の住まいの近くの地名・座標は使わない。
const _update = bool.fromEnvironment('UPDATE_STORE_SHOTS');
const _dir = 'docs/release/screenshots';
const _photoDir = '$_dir/photos';
const _jpegQuality = 82;

/// 端末の枠の種類。
enum StoreFrame { iphone, android, ipad }

/// ストアの枠ごとの画像の大きさ（px）と、中に描く画面の論理サイズ・時刻やホームバーの余白。
enum StoreDevice {
  iphone69(
    canvas: Size(1320, 2868),
    screen: Size(440, 956),
    frame: StoreFrame.iphone,
    padding: EdgeInsets.only(top: 54, bottom: 30),
  ),
  iphone65(
    canvas: Size(1284, 2778),
    screen: Size(428, 926),
    frame: StoreFrame.iphone,
    padding: EdgeInsets.only(top: 50, bottom: 30),
  ),
  android(
    canvas: Size(1080, 1920),
    screen: Size(400, 740),
    frame: StoreFrame.android,
    padding: EdgeInsets.only(top: 30),
  ),
  ipad13(
    canvas: Size(2064, 2752),
    screen: Size(1032, 1376),
    frame: StoreFrame.ipad,
    padding: EdgeInsets.only(top: 24, bottom: 20),
  );

  const StoreDevice({
    required this.canvas,
    required this.screen,
    required this.frame,
    required this.padding,
  });

  final Size canvas;
  final Size screen;
  final StoreFrame frame;
  final EdgeInsets padding;

  bool get isTablet => frame == StoreFrame.ipad;
}

/// 並べる順の場面と、見出し・添え書き（store-listing.md と同じ文）。
/// 前の3枚でアプリの要点を、後ろの3枚で機能を1つずつ見せる。
enum StoreShot {
  inchou('一杯ごとに、印を押す', '食べたラーメンが、印帳に並んでいく'),
  record('店内で、片手ですぐ記録', '撮って、店を選んで、着丼！'),
  result('並んだ時間が、修行点に', '行列も限定も遠征も、点になる'),
  shugyo('型と秘伝を、会得する', '通うほど段位が上がり、印が増える'),
  journey('歩いた道が、旅路になる', '食べた順に、店を地図でつなぐ'),
  shop('一杯ごとに、道中記を綴る', '記録から、短い物語が生まれる');

  const StoreShot(this.caption, this.sub);

  final String caption;
  final String sub;

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
final _tsukishiro = _shop('tsukishiro', '月白家', 35.006, 138.992);
final _shijima = _shop('shijima', 'つけ麺 しじま', 35.03, 138.98);
final _suzune = _shop('suzune', '煮干し 鈴音', 35.06, 139.04);
final _kogarashi = _shop('kogarashi', '味噌らーめん 木枯', 34.98, 139.05);
final _hoshimi = _shop('hoshimi', '豚骨 星見屋', 34.97, 138.99);
final _nagi = _shop('nagi', '塩そば 凪', 35.045, 138.965);
final _yukimi = _shop('yukimi', '極太麺 雪見', 35.02, 139.06);
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

/// 系統ごとの実写の写真（`docs/release/screenshots/photos/` の名前）。記録はこの系統だけにし、
/// 系統と写真を合わせる。
const _stylePhotos = {
  RamenStyle.shoyu: ['shoyu', 'shoyu2'],
  RamenStyle.tonkotsu: ['tonkotsu'],
  RamenStyle.jiro: ['jiro', 'jiro2'],
  RamenStyle.tsukemen: ['tsukemen'],
  RamenStyle.iekei: ['iekei'],
  RamenStyle.shirunashi: ['shirunashi', 'shirunashi2'],
  RamenStyle.shio: ['shio'],
  RamenStyle.miso: ['miso'],
};

/// 行列の写真（3枚目の背景）。
const _queuePhoto = 'queue';

final _photoNames = [
  ..._stylePhotos.values.expand((names) => names),
  _queuePhoto,
];

String _photoFor(String name) => 'photo-$name.jpg';

String _sourcePhoto(String name) => '$_photoDir/$name.jpg';

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
  String photo,
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
  String? photo,
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
  photo: photo ?? _stylePhotos[style]!.first,
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
  _bowl(
    'b14',
    _yukimi,
    _d(7, 5),
    RamenStyle.jiro,
    wait: 30,
    limited: true,
    photo: 'jiro2',
  ),
  _bowl('b15', _kogarashi, _d(7, 12), RamenStyle.miso, wait: 50),
  _bowl('b18', _nagi, _d(8, 2, 11), RamenStyle.shio, wait: 35),
  _bowl(
    'b20',
    _koharu,
    _d(8, 16, 11),
    RamenStyle.shirunashi,
    wait: 5,
    photo: 'shirunashi2',
  ),
  _bowl('b21', _koharu, _d(8, 23), RamenStyle.shirunashi, wait: 5, rating: 5),
  _bowl('b22', _hoshimi, _d(8, 30, 18), RamenStyle.tonkotsu, wait: 15),
  _bowl('b23', _shijima, _d(9, 6), RamenStyle.tsukemen, wait: 60, rating: 5),
  _bowl('b24', _yukimi, _d(9, 13), RamenStyle.jiro, wait: 20),
  _bowl(
    'b25',
    _suzune,
    _d(9, 20),
    RamenStyle.shoyu,
    wait: 55,
    limited: true,
    rating: 5,
    photo: 'shoyu2',
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
    RamenStyle.iekei,
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
        photoPath: bowl.retreated ? null : _photoFor(bowl.photo),
      ),
    ),
];

final _wishes = [
  Wish(
    id: 'w1',
    name: '月白家',
    latitude: 35.006,
    longitude: 138.992,
    trigger: '友だちのすすめ',
    note: '限定の濃厚が名物らしい',
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
    name: '月白家',
    location: GeoPoint(35.006, 138.992),
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

/// 端末の枠に入れる1つの画面。[dark]は画面の上下が暗い色か（時刻やホームバーを明るく描く）。
/// [zoom]は、構図の中で拡大して見せる部分（論理座標）を返す。
class _Screen {
  const _Screen(this.scene, {this.dark = false, this.zoom});

  final ShotScene scene;
  final bool dark;
  final Rect Function(WidgetTester tester)? zoom;
}

/// 1枚に使う画面（2台重ねる場面は2つ）。
List<_Screen> _screensFor(StoreShot shot) => switch (shot) {
  StoreShot.inchou => const [_Screen(ShotScene(tab: AppTab.records))],
  StoreShot.record => [
    _Screen(
      ShotScene(
        home: const RecordScreen(),
        candidates: _candidates,
        act: (tester) async {
          await tester.tap(find.text(ja.takePhoto));
          await settleShot(tester);
          await tester.tap(find.text(_candidates.first.name));
          await settleShot(tester);
        },
      ),
    ),
  ],
  StoreShot.result => [
    _Screen(
      const ShotScene(home: RecordResultScreen(visitId: 'today')),
      dark: true,
      zoom: (tester) => tester
          .getRect(find.text(ja.pointsGained(_today.points.total)))
          .expandToInclude(tester.getRect(find.byType(PointsBreakdownView)))
          .inflate(14),
    ),
  ],
  StoreShot.shugyo => [
    const _Screen(ShotScene(tab: AppTab.shugyo)),
    _Screen(
      ShotScene(
        tab: AppTab.shugyo,
        act: (tester) async {
          final spot = find.text(ja.questSpot);
          await tester.scrollUntilVisible(
            spot,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(tester.element(spot));
          await settleShot(tester);
        },
      ),
    ),
  ],
  StoreShot.journey => [
    _Screen(
      ShotScene(
        tab: AppTab.map,
        act: (tester) async {
          await tester.tap(find.byTooltip(ja.journeyToggle));
          await settleShot(tester);
        },
      ),
    ),
  ],
  StoreShot.shop => [
    _Screen(
      ShotScene(
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
    ),
  ],
};

final _scored = scoreVisits(
  _world.visits,
  wishes: _wishes,
  homeBases: _world.homeBases,
);

ScoredVisit _scoredOf(String id) =>
    _scored.firstWhere((entry) => entry.visit.id == id);

final _today = _scoredOf('today');

void main() {
  late Directory documents;
  late String photo;
  final photos = <String, ui.Image>{};
  WidgetsApp.debugAllowBannerOverride = false;

  setUpAll(() async {
    documents = createTempDirectory();
    photo = p.join(documents.path, 'camera.jpg');
    for (final name in _photoNames) {
      final bytes = File(_sourcePhoto(name)).readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      photos[name] = (await codec.getNextFrame()).image;
      if (_update) {
        File(p.join(documents.path, _photoFor(name))).writeAsBytesSync(bytes);
      }
    }
    if (!_update) {
      File(photo).writeAsBytesSync(const []);
      return;
    }
    await loadShotFonts();
    File(_sourcePhoto('iekei')).copySync(photo);
  });

  test('架空の記録は場面の案どおり（最後の一杯で三段に昇段する）', () {
    final scored = _scored;
    final history = rankHistory(scored);
    expect(history.last.rank, AdventurerRank.dan3);
    expect(history.last.visit?.visit.id, 'today');
    final today = _today;
    expect(today.points.waitBonus, greaterThan(0));
    expect(today.points.limitedBonus, greaterThan(0));
    expect(today.points.firstVisitBonus, greaterThan(0));
    final grades = {
      for (final entry in scored) shopRankFor(entry.points.total),
    };
    expect(grades, containsAll([ShopRank.s, ShopRank.a, ShopRank.b]));
  });

  test('記録の写真は、どれも系統に合った実写の写真がある', () {
    for (final bowl in _bowls) {
      expect(_stylePhotos[bowl.style], contains(bowl.photo), reason: bowl.id);
    }
    for (final name in _photoNames) {
      expect(File(_sourcePhoto(name)).existsSync(), isTrue, reason: name);
    }
  });

  test('見出しと添え書きは store-listing.md の表と同じ', () {
    final listing = File('docs/release/store-listing.md').readAsStringSync();
    for (final shot in StoreShot.values) {
      expect(
        listing,
        contains('| ${shot.caption} | ${shot.sub} |'),
        reason: shot.name,
      );
    }
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
        // 画面は、拡大して見せても粗くならないよう大きめに写す（ふだんは小さく写して流れだけ確かめる）。
        final ratio = _update
            ? device.canvas.width / device.screen.width * 1.2
            : 0.5;
        final captured = <_Captured>[];
        for (final screen in _screensFor(shot)) {
          final boundary = GlobalKey();
          await pumpShot(
            tester,
            _world,
            screen.scene,
            boundary: boundary,
            size: device.screen,
            photo: photo,
            documents: documents,
            render: _update,
            padding: device.padding,
          );
          expect(tester.takeException(), isNull);
          final zoom = screen.zoom?.call(tester);
          final image = await tester.runAsync(
            () => captureShot(boundary, ratio),
          );
          captured.add(_Captured(image!, ratio, dark: screen.dark, zoom: zoom));
        }

        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = device.canvas
          ..resetPadding()
          ..resetViewPadding();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: localizedApp(
              theme: buildAppTheme(),
              home: _Composition(
                shot: shot,
                device: device,
                screens: captured,
                photos: photos,
              ),
            ),
          ),
        );
        await settleShot(tester);
        expect(tester.takeException(), isNull);
        if (!_update) return;
        await tester.runAsync(() async {
          final image = await captureShot(boundary, 1);
          await _writeJpeg(image, shot.fileFor(device));
        });
      });
    }
  }

  testWidgets('Google Play のフィーチャー グラフィック', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _featureSize;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: localizedApp(
          theme: buildAppTheme(),
          home: _FeatureGraphic(
            photo: photos['iekei']!,
            stamps: [_today, _scoredOf('b23')],
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

/// 写した画面と、その倍率・拡大して見せる部分。
class _Captured {
  const _Captured(this.image, this.ratio, {required this.dark, this.zoom});

  final ui.Image image;
  final double ratio;
  final bool dark;
  final Rect? zoom;
}

/// 1枚の構図。大きさはすべて画像の幅[w]・高さ[h]に対する割合で決める。
class _Composition extends StatelessWidget {
  const _Composition({
    required this.shot,
    required this.device,
    required this.screens,
    required this.photos,
  });

  final StoreShot shot;
  final StoreDevice device;
  final List<_Captured> screens;
  final Map<String, ui.Image> photos;

  double get w => device.canvas.width;
  double get h => device.canvas.height;

  /// 端末の枠の高さ÷幅。
  double get _aspect => _DeviceFrame.heightFor(device, 1);

  /// 幅は画像の幅の[ofWidth]まで、高さは画像の高さの[ofHeight]まで、の小さい方。
  double _fit(double ofWidth, double ofHeight) =>
      math.min(w * ofWidth, h * ofHeight / _aspect);

  double get _captionSize => w * (device.isTablet ? 0.062 : 0.088);

  /// 見出しの行数（電話は読点で2行に分ける）。
  String get _caption =>
      device.isTablet ? shot.caption : shot.caption.replaceAll('、', '\n');

  double get _captionHeight {
    final lines = '\n'.allMatches(_caption).length + 1;
    return lines * _captionSize * 1.3 + _captionSize * 0.45 * 1.8 + w * 0.02;
  }

  @override
  Widget build(BuildContext context) {
    final top = h * 0.045;
    final below = top + _captionHeight + h * 0.025;
    return Material(
      color: Washi.desk,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: switch (shot) {
            StoreShot.inchou => _inchou(top, below),
            StoreShot.record => _record(top, below),
            StoreShot.result => _result(),
            StoreShot.shugyo => _shugyo(top, below),
            StoreShot.journey => _journey(),
            StoreShot.shop => _shop(top, below),
          },
        ),
      ),
    );
  }

  Widget _headline(double top, {Color color = Washi.ink, Color? subColor}) =>
      Positioned(
        left: w * 0.05,
        right: w * 0.05,
        top: top,
        child: _Headline(
          caption: _caption,
          sub: shot.sub,
          size: _captionSize,
          color: color,
          subColor: subColor ?? (color == Washi.ink ? Washi.inkSoft : color),
        ),
      );

  Widget _headlineAtBottom() => Positioned(
    left: w * 0.05,
    right: w * 0.05,
    bottom: h * 0.045,
    child: _Headline(
      caption: _caption,
      sub: shot.sub,
      size: _captionSize,
      color: Washi.ink,
      subColor: Washi.inkSoft,
    ),
  );

  Widget _device(
    _Captured screen, {
    required double left,
    required double top,
    required double width,
    double angle = 0,
  }) => Positioned(
    left: left,
    top: top,
    child: Transform.rotate(
      angle: angle,
      child: _DeviceFrame(device: device, screen: screen, width: width),
    ),
  );

  /// 1枚目: 大きな端末で印帳を見せ、横に大きな印を2つ浮かべる。
  List<Widget> _inchou(double top, double below) {
    final width = _fit(0.8, 0.86);
    final height = width * _aspect;
    final card = math.min(w * 0.36, h * 0.24);
    return [
      _headline(top),
      _device(
        screens.single,
        left: (w - width) / 2 - w * 0.04,
        top: below,
        width: width,
      ),
      Positioned(
        right: w * 0.03,
        top: below + height * 0.16,
        child: _StampCard(scored: _today, size: card, angle: 0.08),
      ),
      Positioned(
        right: w * 0.12,
        top: below + height * 0.16 + card * 1.08,
        child: _StampCard(
          scored: _scoredOf('b23'),
          size: card * 0.72,
          angle: -0.1,
        ),
      ),
    ];
  }

  /// 2枚目: 実写の一杯を上いっぱいに敷き、その上に記録画面を置く。
  List<Widget> _record(double top, double below) {
    final width = _fit(0.66, 0.6);
    final height = width * _aspect;
    final photoHeight = h * 0.56;
    return [
      Positioned.fill(child: Container(color: Washi.aiDeep)),
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: photoHeight,
        child: RawImage(
          image: photos['iekei'],
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: photoHeight + 2,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xD91A2536),
                Color(0x661A2536),
                Color(0x001A2536),
                Color(0xFF1A2536),
              ],
              stops: [0, 0.32, 0.6, 1],
            ),
          ),
        ),
      ),
      _headline(top, color: Washi.page, subColor: Washi.paper),
      _device(
        screens.single,
        left: (w - width) / 2 + w * 0.02,
        top: h - height - h * 0.035,
        width: width,
        angle: 0.035,
      ),
    ];
  }

  /// 3枚目: 行列の写真を上に敷き、保存直後の画面を傾けて置いて、得た点と内訳を拡大する。見出しは下。
  List<Widget> _result() {
    final screen = screens.single;
    final width = _fit(0.56, 0.58);
    final zoom = screen.zoom!;
    // iPad は画面が横に広く、内訳が細長くなるので、幅いっぱいに広げて下寄りに置く。
    final cardWidth = w * (device.isTablet ? 0.9 : 0.66);
    final cardHeight = cardWidth * zoom.height / zoom.width;
    final photoHeight = h * 0.5;
    return [
      Positioned.fill(child: Container(color: Washi.paper)),
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: photoHeight,
        child: RawImage(
          image: photos[_queuePhoto],
          fit: BoxFit.cover,
          alignment: const Alignment(0.7, 0),
          filterQuality: FilterQuality.high,
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: photoHeight * 0.55,
        height: photoHeight * 0.45 + 2,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00F3ECDF), Washi.paper],
            ),
          ),
        ),
      ),
      _device(screen, left: w * 0.03, top: h * 0.2, width: width, angle: -0.06),
      Positioned(
        right: w * (device.isTablet ? 0.05 : 0.04),
        top: h * (device.isTablet ? 0.56 : 0.5),
        child: Transform.rotate(
          angle: 0.03,
          child: _ZoomCard(
            screen: screen,
            width: cardWidth,
            height: cardHeight,
          ),
        ),
      ),
      _headlineAtBottom(),
    ];
  }

  /// 4枚目: 型と秘伝の画面を、傾けた2台で重ねる。
  List<Widget> _shugyo(double top, double below) {
    final width = _fit(0.6, 0.66);
    return [
      _headline(top),
      _device(
        screens[0],
        left: w * 0.03,
        top: below,
        width: width,
        angle: -0.07,
      ),
      _device(
        screens[1],
        left: w - width - w * 0.03,
        top: below + h * 0.1,
        width: width,
        angle: 0.06,
      ),
    ];
  }

  /// 5枚目: 旅路の地図を大きくまっすぐ見せる。見出しは下。
  List<Widget> _journey() {
    final width = _fit(0.84, 0.72);
    return [
      Positioned.fill(child: Container(color: Washi.paper)),
      _device(
        screens.single,
        left: (w - width) / 2,
        top: h * 0.045,
        width: width,
      ),
      _headlineAtBottom(),
    ];
  }

  /// 6枚目: 店のページを右に置き、その一杯の写真を左に添える。
  List<Widget> _shop(double top, double below) {
    final width = _fit(0.66, 0.72);
    final height = width * _aspect;
    final print = w * (device.isTablet ? 0.34 : 0.42);
    return [
      _headline(top),
      _device(
        screens.single,
        left: w - width - w * 0.05,
        top: below,
        width: width,
        angle: 0.035,
      ),
      Positioned(
        left: w * 0.04,
        top: below + height * 0.68,
        child: Transform.rotate(
          angle: -0.08,
          child: _Print(
            photo: photos['shoyu']!,
            width: print,
            caption: _kasumi.name,
          ),
        ),
      ),
    ];
  }
}

/// 見出し（筆文字）と、その下の添え書き（明朝）。
class _Headline extends StatelessWidget {
  const _Headline({
    required this.caption,
    required this.sub,
    required this.size,
    required this.color,
    required this.subColor,
  });

  final String caption;
  final String sub;
  final double size;
  final Color color;
  final Color subColor;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        caption,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: Washi.brush,
          fontSize: size,
          height: 1.3,
          color: color,
        ),
      ),
      SizedBox(height: size * 0.2),
      Text(
        sub,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: Washi.mincho,
          fontSize: size * 0.4,
          height: 1.6,
          color: subColor,
        ),
      ),
    ],
  );
}

/// 端末の枠。中に写した画面を入れ、上に時刻・下にホームバーを描く。
class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({
    required this.device,
    required this.screen,
    required this.width,
  });

  final StoreDevice device;
  final _Captured screen;
  final double width;

  static double bezelFor(StoreDevice device, double width) =>
      width * (device.isTablet ? 0.026 : 0.034);

  static double heightFor(StoreDevice device, double width) {
    final bezel = bezelFor(device, width);
    final inner = width - bezel * 2;
    return inner * device.screen.height / device.screen.width + bezel * 2;
  }

  @override
  Widget build(BuildContext context) {
    final bezel = bezelFor(device, width);
    final inner = width - bezel * 2;
    final unit = inner / device.screen.width;
    final radius = width * (device.isTablet ? 0.045 : 0.15);
    final ink = screen.dark ? Washi.page : Washi.ink;
    final status = device.padding.top * unit;
    return Container(
      width: width,
      height: heightFor(device, width),
      padding: EdgeInsets.all(bezel),
      decoration: BoxDecoration(
        color: const Color(0xFF15130F),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF4A453E), width: bezel * 0.18),
        boxShadow: [
          BoxShadow(
            color: Washi.ink.withValues(alpha: 0.35),
            blurRadius: width * 0.06,
            offset: Offset(0, width * 0.025),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - bezel),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RawImage(
              image: screen.image,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: status,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30 * unit),
                child: Row(
                  children: [
                    Text(
                      '19:30',
                      style: TextStyle(
                        fontFamily: Washi.mincho,
                        fontWeight: FontWeight.w700,
                        fontSize: (device.isTablet ? 14 : 16) * unit,
                        color: ink,
                      ),
                    ),
                    const Spacer(),
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 3 * unit,
                        height: (4 + i * 2.5) * unit,
                        margin: EdgeInsets.only(right: 1.6 * unit),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(unit),
                        ),
                      ),
                    SizedBox(width: 6 * unit),
                    Container(
                      width: 25 * unit,
                      height: 12 * unit,
                      padding: EdgeInsets.all(1.6 * unit),
                      decoration: BoxDecoration(
                        border: Border.all(color: ink, width: unit),
                        borderRadius: BorderRadius.circular(3.5 * unit),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(2 * unit),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (device.frame == StoreFrame.iphone)
              Positioned(
                top: 11 * unit,
                left: (inner - 122 * unit) / 2,
                child: Container(
                  width: 122 * unit,
                  height: 35 * unit,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18 * unit),
                  ),
                ),
              ),
            if (device.frame == StoreFrame.android)
              Positioned(
                top: (status - 13 * unit) / 2,
                left: (inner - 13 * unit) / 2,
                child: Container(
                  width: 13 * unit,
                  height: 13 * unit,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (device.padding.bottom > 0)
              Positioned(
                bottom: 8 * unit,
                left: (inner - 134 * unit) / 2,
                child: Container(
                  width: 134 * unit,
                  height: 5 * unit,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(3 * unit),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 和紙の小さな台紙に押した、大きな印。
class _StampCard extends StatelessWidget {
  const _StampCard({
    required this.scored,
    required this.size,
    required this.angle,
  });

  final ScoredVisit scored;
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Washi.page,
        border: Border.all(color: Washi.line, width: size * 0.008),
        boxShadow: [
          BoxShadow(
            color: Washi.ink.withValues(alpha: 0.28),
            blurRadius: size * 0.08,
            offset: Offset(0, size * 0.03),
          ),
        ],
      ),
      child: InkanStamp(scored: scored, size: size * 0.78),
    ),
  );
}

/// 写した画面の一部を、枠付きのカードにして拡大する。
class _ZoomCard extends StatelessWidget {
  const _ZoomCard({
    required this.screen,
    required this.width,
    required this.height,
  });

  final _Captured screen;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(width * 0.04),
      border: Border.all(color: Washi.ai, width: width * 0.012),
      boxShadow: [
        BoxShadow(
          color: Washi.ink.withValues(alpha: 0.4),
          blurRadius: width * 0.06,
          offset: Offset(0, width * 0.02),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(width * 0.03),
      child: CustomPaint(
        size: Size(width, height),
        painter: _CropPainter(screen.image, screen.zoom! * screen.ratio),
      ),
    ),
  );
}

extension on Rect {
  Rect operator *(double scale) =>
      Rect.fromLTRB(left * scale, top * scale, right * scale, bottom * scale);
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.image, this.source);

  final ui.Image image;
  final Rect source;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    source,
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.high,
  );

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      image != oldDelegate.image || source != oldDelegate.source;
}

/// 白い縁の付いた、紙焼きの写真。下の余白に店名を書く。
class _Print extends StatelessWidget {
  const _Print({
    required this.photo,
    required this.width,
    required this.caption,
  });

  final ui.Image photo;
  final double width;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final margin = width * 0.05;
    final inner = width - margin * 2;
    return Container(
      width: width,
      padding: EdgeInsets.fromLTRB(margin, margin, margin, margin * 0.6),
      decoration: BoxDecoration(
        color: Washi.page,
        boxShadow: [
          BoxShadow(
            color: Washi.ink.withValues(alpha: 0.35),
            blurRadius: width * 0.06,
            offset: Offset(0, width * 0.02),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: inner,
            height: inner,
            child: RawImage(
              image: photo,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(height: margin * 0.5),
          Text(
            caption,
            style: TextStyle(
              fontFamily: Washi.brush,
              fontSize: width * 0.085,
              color: Washi.ink,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
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

/// Google Play の掲載の上に出る横長の絵。左に題、右に実写の一杯と印。
class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic({required this.photo, required this.stamps});

  final ui.Image photo;
  final List<ScoredVisit> stamps;

  @override
  Widget build(BuildContext context) => Material(
    color: Washi.desk,
    child: Stack(
      children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 560,
          child: RawImage(
            image: photo,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        const Positioned(
          right: 360,
          top: 0,
          bottom: 0,
          width: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Washi.desk, Color(0x00E9E1D2)]),
            ),
          ),
        ),
        const Positioned(
          left: 64,
          top: 0,
          bottom: 0,
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
          Positioned(
            left: [590.0, 730.0][index],
            top: [260.0, 300.0][index],
            child: _StampCard(
              scored: stamp,
              size: [170.0, 140.0][index],
              angle: [-0.1, 0.08][index],
            ),
          ),
      ],
    ),
  );
}
