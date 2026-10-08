import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/backup/backup_screen.dart';
import 'package:ramen_in_cho/features/checkin/checkin_controller.dart';
import 'package:ramen_in_cho/features/checkin/checkin_screen.dart';
import 'package:ramen_in_cho/features/checkin/retreat_screen.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/help/help_topics.dart';
import 'package:ramen_in_cho/features/home/app_tab.dart';
import 'package:ramen_in_cho/features/home_base/home_base_picker_screen.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/journal/shugyoroku_screen.dart';
import 'package:ramen_in_cho/features/map/washi_map.dart';
import 'package:ramen_in_cho/features/notifications/notification_service.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_store.dart';
import 'package:ramen_in_cho/features/record/photo_metadata.dart';
import 'package:ramen_in_cho/features/record/photo_picker.dart';
import 'package:ramen_in_cho/features/record/record_draft.dart';
import 'package:ramen_in_cho/features/record/record_result_screen.dart';
import 'package:ramen_in_cho/features/record/record_screen.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/share/share_screen.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';
import 'package:ramen_in_cho/features/shop_search/nearby_shop_finder.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/ramen_in_cho_api.dart';
import 'package:ramen_in_cho/features/shop_search/shop_candidate.dart';
import 'package:ramen_in_cho/features/shop_search/shop_search_service.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/main.dart';
import 'package:ramen_in_cho/theme/app_theme.dart';
import 'package:ramen_in_cho/theme/washi.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';

import '../support/builders.dart';
import '../support/fakes.dart';
import '../support/l10n.dart';

/// 使い方（設定の「使い方」）の絵を、架空のデータで実際の画面を描いて `assets/help/` に作る。
///
/// ふだんは、どの絵も描けることと、絵のファイルがそろっていることを確かめる。画面を変えたら
/// `flutter test --dart-define=UPDATE_HELP_SHOTS=true test/tool/help_shots_test.dart`
/// で作り直す（WebP にするので `cwebp` が要る。`brew install webp`）。
/// 店名・地名・座標はすべて架空のもの。実在の人や、利用者の住まいの近くの地名・座標は使わない。
const _update = bool.fromEnvironment('UPDATE_HELP_SHOTS');
const _dir = 'assets/help';
const _size = Size(393, 852);
const _webpWidth = 480;
const _webpQuality = 70;

final _now = DateTime(2026, 10, 5, 19, 30);
const _here = GeoPoint(35.0, 139.0);

final _kasumi = buildShop(
  id: 'kasumi',
  name: '麺屋 かすみ',
  latitude: 35.0025,
  longitude: 139.0,
  osmId: 'node/1',
);
final _seiran = buildShop(
  id: 'seiran',
  name: '中華そば 青嵐',
  latitude: 35.012,
  longitude: 139.018,
);
final _oboro = buildShop(
  id: 'oboro',
  name: 'つけ麺 朧',
  latitude: 35.03,
  longitude: 138.98,
);
final _hoshi = buildShop(
  id: 'hoshi',
  name: '豚骨 星見屋',
  latitude: 35.06,
  longitude: 139.04,
);
final _kogarashi = buildShop(
  id: 'kogarashi',
  name: '味噌らーめん 木枯',
  latitude: 34.98,
  longitude: 139.05,
);

List<VisitWithShop> _visits({bool unrated = false}) {
  final shops = [_kasumi, _seiran, _oboro, _hoshi, _kogarashi];
  const styles = [
    RamenStyle.shoyu,
    RamenStyle.shio,
    RamenStyle.tsukemen,
    RamenStyle.tonkotsu,
    RamenStyle.miso,
  ];
  // 一覧と同じく新しい順。
  return [
    VisitWithShop(
      shop: _kasumi,
      visit: buildVisit(
        id: 'today',
        shopId: _kasumi.id,
        eatenAt: unrated
            ? DateTime(2026, 10, 5, 18, 40)
            : DateTime(2026, 10, 3, 12, 30),
        waitMinutes: 35,
        style: RamenStyle.shoyu,
        rating: unrated ? null : 5,
      ),
    ),
    for (var i = 0; i < 12; i++)
      VisitWithShop(
        shop: shops[i % shops.length],
        visit: buildVisit(
          id: 'v$i',
          shopId: shops[i % shops.length].id,
          eatenAt: DateTime(2026, 9 - i ~/ 2, 26 - (i % 2) * 11, 12, 10),
          waitMinutes: [15, 40, 5, 65, 25][i % 5],
          style: styles[i % styles.length],
          rating: 3 + i % 3,
          isLimited: i == 4,
          result: i == 7 ? VisitResult.retreated : VisitResult.eaten,
          memo: i == 0 ? '煮干しが香る一杯' : '',
        ),
      ),
  ];
}

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
    shopId: _seiran.id,
    name: _seiran.name,
    createdAt: DateTime(2026, 7, 1),
    fulfilledVisitId: 'v1',
  ),
];

const _found = [
  FoundShop(
    osmId: 'node/1',
    name: '麺屋 かすみ',
    location: GeoPoint(35.0025, 139.0),
  ),
  FoundShop(
    osmId: 'node/21',
    name: '中華そば 白露',
    location: GeoPoint(35.0025, 138.996),
  ),
  FoundShop(
    osmId: 'node/22',
    name: 'らーめん 夕凪',
    location: GeoPoint(34.996, 139.004),
  ),
  FoundShop(
    osmId: 'node/23',
    name: '油そば 小春',
    location: GeoPoint(35.005, 139.006),
  ),
];

const _candidates = [
  ShopCandidate(
    osmId: 'node/21',
    name: '中華そば 白露',
    location: GeoPoint(35.0025, 138.996),
    distanceMeters: 140,
  ),
  ShopCandidate(
    osmId: 'node/22',
    name: 'らーめん 夕凪',
    location: GeoPoint(34.996, 139.004),
    distanceMeters: 260,
  ),
  ShopCandidate(
    shopId: 'kasumi',
    name: '麺屋 かすみ',
    location: GeoPoint(35.0025, 139.0),
    distanceMeters: 280,
  ),
];

const _wishCandidate = ShopCandidate(
  name: 'らぁめん 月見坂',
  location: GeoPoint(35.004, 139.004),
  distanceMeters: 30,
  wishId: 'w1',
);

typedef _Scene = ({
  Widget? home,
  AppTab? tab,
  Checkin? checkin,
  bool unrated,
  List<ShopCandidate> candidates,
  Future<void> Function(WidgetTester tester)? act,
});

_Scene _scene({
  Widget? home,
  AppTab? tab,
  Checkin? checkin,
  bool unrated = false,
  List<ShopCandidate> candidates = _candidates,
  Future<void> Function(WidgetTester tester)? act,
}) => (
  home: home,
  tab: tab,
  checkin: checkin,
  unrated: unrated,
  candidates: candidates,
  act: act,
);

Future<void> _takePhoto(WidgetTester tester) async {
  await tester.tap(find.text(ja.takePhoto));
  await _settle(tester);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder));
  await _settle(tester);
}

_Scene _sceneFor(HelpShot shot) => switch (shot) {
  HelpShot.recordStart => _scene(
    tab: AppTab.records,
    act: (tester) async {
      await tester.tap(find.byType(RecordSealButton));
      await _settle(tester);
    },
  ),
  HelpShot.recordPhoto => _scene(home: const RecordScreen()),
  HelpShot.recordShop => _scene(home: const RecordScreen(), act: _takePhoto),
  HelpShot.recordResult => _scene(
    home: const RecordResultScreen(visitId: 'today'),
  ),
  HelpShot.queueStart => _scene(
    home: const CheckinScreen(),
    candidates: const [
      ShopCandidate(
        osmId: 'node/24',
        name: '煮干しそば 灯',
        location: GeoPoint(35.0003, 139.0),
        distanceMeters: 35,
      ),
      ShopCandidate(
        osmId: 'node/21',
        name: '中華そば 白露',
        location: GeoPoint(35.0025, 138.996),
        distanceMeters: 140,
      ),
    ],
  ),
  HelpShot.queueWaiting => _scene(
    tab: AppTab.records,
    checkin: Checkin(
      shopId: _kasumi.id,
      name: _kasumi.name,
      latitude: 35.0025,
      longitude: 139.0,
      checkedInAt: _now.subtract(const Duration(minutes: 25)),
    ),
  ),
  HelpShot.retreat => _scene(home: const RetreatScreen()),
  HelpShot.rating => _scene(tab: AppTab.records, unrated: true),
  HelpShot.wishList => _scene(tab: AppTab.wishes),
  HelpShot.wishCandidate => _scene(
    home: const RecordScreen(),
    candidates: [_wishCandidate, ..._candidates.take(2)],
    act: _takePhoto,
  ),
  HelpShot.mapSearch => _scene(
    tab: AppTab.map,
    act: (tester) async {
      await tester.tap(find.byTooltip(ja.mapSearchHere));
      await _settle(tester);
      // 見つかった軒数の知らせが消え、探すボタンが見えるまで待つ。
      await tester.pump(const Duration(seconds: 5));
      await _settle(tester);
    },
  ),
  HelpShot.journey => _scene(
    tab: AppTab.map,
    act: (tester) async {
      await tester.tap(find.byTooltip(ja.journeyToggle));
      await _settle(tester);
    },
  ),
  HelpShot.homeBase => _scene(home: const HomeBasePickerScreen()),
  HelpShot.shugyoRank => _scene(tab: AppTab.shugyo),
  HelpShot.shugyoQuests => _scene(
    tab: AppTab.shugyo,
    act: (tester) => _scrollTo(tester, find.text(ja.questStanding)),
  ),
  HelpShot.shugyoroku => _scene(home: const ShugyorokuScreen()),
  HelpShot.share => _scene(home: const ShareScreen(visitId: 'today')),
  HelpShot.backup => _scene(home: const BackupScreen()),
};

void main() {
  late String photo;
  WidgetsApp.debugAllowBannerOverride = false;

  setUpAll(() async {
    photo = p.join(createTempDirectory().path, 'bowl.png');
    if (!_update) {
      File(photo).writeAsBytesSync(const []);
      return;
    }
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
    File(photo).writeAsBytesSync(await _bowlPhoto());
  });

  test('どの絵にもファイルがある', () {
    for (final shot in HelpShot.values) {
      expect(File(shot.asset).existsSync(), isTrue, reason: shot.asset);
    }
  }, skip: _update);

  for (final shot in HelpShot.values) {
    testWidgets('使い方の絵 ${shot.name}', (tester) async {
      final boundary = GlobalKey();
      await _pump(tester, _sceneFor(shot), boundary: boundary, photo: photo);
      expect(tester.takeException(), isNull);
      if (!_update) return;
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final png = p.join(createTempDirectory().path, '${shot.name}.png');
        File(png).writeAsBytesSync(bytes!.buffer.asUint8List());
        Directory(_dir).createSync(recursive: true);
        final result = await Process.run('cwebp', [
          '-quiet',
          '-q',
          '$_webpQuality',
          '-resize',
          '$_webpWidth',
          '0',
          png,
          '-o',
          shot.asset,
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
      });
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Scene scene, {
  required GlobalKey boundary,
  required String photo,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = _size * 2;
  addTearDown(tester.view.reset);

  // 写真は先に読んでおく（偽の時計の中で読み始めると、読み終わらないため）。
  if (_update) {
    await tester.runAsync(() async {
      final loaded = Completer<void>();
      FileImage(File(photo))
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (_, _) => loaded.isCompleted ? null : loaded.complete(),
              onError: (e, _) =>
                  loaded.isCompleted ? null : loaded.completeError(e),
            ),
          );
      await loaded.future;
    });
  }
  final tab = scene.tab;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(createTestDatabase()),
        visitsProvider.overrideWithValue(
          AsyncData(_visits(unrated: scene.unrated)),
        ),
        homeBaseSettingsProvider.overrideWithValue(
          AsyncData([buildHomeBase(name: 'みどり台駅', setAt: DateTime(2026))]),
        ),
        wishesProvider.overrideWithValue(AsyncData(_wishes)),
        activeCheckinProvider.overrideWithValue(AsyncData(scene.checkin)),
        documentsDirectoryProvider.overrideWithValue(createTempDirectory()),
        recordRepositoryProvider.overrideWithValue(_Repository(scene.checkin)),
        wishRepositoryProvider.overrideWithValue(FakeWishRepository()),
        photoPickerProvider.overrideWithValue(
          FakePhotoPicker(cameraPath: photo),
        ),
        photoMetadataReaderProvider.overrideWithValue(
          FakePhotoMetadataReader(),
        ),
        recordDraftStoreProvider.overrideWithValue(MemoryRecordDraftStore()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(position: _here),
        ),
        nearbyShopFinderProvider.overrideWithValue(
          FakeShopFinder(shops: _found),
        ),
        shopSearchServiceProvider.overrideWithValue(
          FakeShopSearchService(
            ShopSearchResult(here: _here, candidates: scene.candidates),
          ),
        ),
        mapTilesEnabledProvider.overrideWithValue(false),
        ramenInChoApiProvider.overrideWithValue(_Api()),
        showOnboardingOnLaunchProvider.overrideWithValue(false),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: tab == null
            ? localizedApp(home: scene.home!, theme: buildAppTheme())
            : const RamenInChoApp(),
      ),
    ),
  );
  await _settle(tester);
  if (tab != null) {
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(appTabProvider.notifier)
        .select(tab);
    await _settle(tester);
  }
  if (scene.act case final act?) await act(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync()))))
      .load();
}

/// 記録の写真の代わりに、上から見た丼の絵を描く。
Future<List<int>> _bowlPhoto() async {
  const size = 800.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()..color = const Color(0xFF6B4A33),
  );
  const center = Offset(size / 2, size / 2);
  canvas.drawCircle(center, 330, Paint()..color = Washi.page);
  canvas.drawCircle(center, 300, Paint()..color = const Color(0xFF8A2C1D));
  canvas.drawCircle(center, 270, Paint()..color = const Color(0xFFC98A3D));
  final noodle = Paint()
    ..color = const Color(0xFFF1D58A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;
  for (var i = 0; i < 9; i++) {
    final y = 300.0 + i * 18;
    final path = Path()..moveTo(220, y);
    for (var x = 220.0; x <= 520; x += 20) {
      path.lineTo(x, y + math.sin(x / 18 + i) * 8);
    }
    canvas.drawPath(path, noodle);
  }
  canvas.drawCircle(
    const Offset(500, 300),
    70,
    Paint()..color = const Color(0xFFE9C9A9),
  );
  canvas.drawCircle(
    const Offset(320, 520),
    50,
    Paint()..color = const Color(0xFFF7F1E1),
  );
  canvas.drawCircle(
    const Offset(320, 520),
    24,
    Paint()..color = const Color(0xFFF2A93B),
  );
  final nori = Paint()..color = const Color(0xFF1F2A22);
  canvas.drawRect(const Rect.fromLTWH(520, 380, 80, 140), nori);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

class _Repository extends FakeRecordRepository {
  _Repository(this.checkin);

  final Checkin? checkin;

  @override
  Future<Checkin?> activeCheckin() async => checkin;

  @override
  Future<List<Shop>> allShops() async => [_kasumi, _seiran, _oboro, _hoshi];
}

class _Api implements RamenInChoApi {
  @override
  Future<List<FoundShop>> searchByName(
    String name, {
    GeoPoint? near,
    Duration timeout = RamenInChoApi.timeout,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
