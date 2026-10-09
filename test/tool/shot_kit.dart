import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/checkin/checkin_controller.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/home/app_tab.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/map/washi_map.dart';
import 'package:ramen_in_cho/features/notifications/notification_service.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_store.dart';
import 'package:ramen_in_cho/features/record/photo_metadata.dart';
import 'package:ramen_in_cho/features/record/photo_picker.dart';
import 'package:ramen_in_cho/features/record/record_draft.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
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

import '../support/fakes.dart';
import '../support/l10n.dart';

/// 使い方の絵（help_shots_test.dart）とストアのスクリーンショット（store_shots_test.dart）で
/// 共通の、架空のデータで実際の画面を描く仕組み。

/// 画面に出す架空の記録と、その場面。
class ShotWorld {
  const ShotWorld({
    required this.visits,
    required this.wishes,
    required this.shops,
    required this.found,
    required this.homeBases,
    required this.now,
    required this.here,
  });

  final List<VisitWithShop> visits;
  final List<Wish> wishes;
  final List<Shop> shops;
  final List<FoundShop> found;
  final List<HomeBaseSetting> homeBases;
  final DateTime now;
  final GeoPoint here;
}

class ShotScene {
  const ShotScene({
    this.home,
    this.tab,
    this.checkin,
    this.candidates = const [],
    this.act,
  }) : assert((home == null) != (tab == null));

  final Widget? home;
  final AppTab? tab;
  final Checkin? checkin;
  final List<ShopCandidate> candidates;
  final Future<void> Function(WidgetTester tester)? act;
}

/// 筆文字・本文・アイコンのフォントを読み込む（読まないと、文字が四角で描かれる）。
Future<void> loadShotFonts() async {
  await _loadFont('YujiSyuku', 'assets/fonts/YujiSyuku-Regular.ttf');
  await _loadFont('ShipporiMincho', 'assets/fonts/ShipporiMincho-Regular.ttf');
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    await _loadFont(
      'MaterialIcons',
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
  }
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync()))))
      .load();
}

/// [scene]を論理サイズ[size]の画面に描く。[render]なら写真も読み込んでから描く。
/// [padding]は画面の上下の、時刻やホームバーに使われる余白（論理サイズ）。
Future<void> pumpShot(
  WidgetTester tester,
  ShotWorld world,
  ShotScene scene, {
  required GlobalKey boundary,
  required Size size,
  required String photo,
  required Directory documents,
  required bool render,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  if (padding != EdgeInsets.zero) {
    // 時刻やホームバーの分の余白（ストアの画像で端末の枠を描くとき）。
    final fake = FakeViewPadding(
      left: padding.left * 2,
      top: padding.top * 2,
      right: padding.right * 2,
      bottom: padding.bottom * 2,
    );
    tester.view
      ..padding = fake
      ..viewPadding = fake;
  }
  addTearDown(tester.view.reset);

  final database = createTestDatabase();
  Future<void> build() async {
    await tester.pumpWidget(
      _app(
        world,
        scene,
        boundary,
        database: database,
        photo: photo,
        documents: documents,
      ),
    );
    await settleShot(tester);
    if (scene.tab case final tab?) {
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(appTabProvider.notifier)
          .select(tab);
      await settleShot(tester);
    }
    if (scene.act case final act?) await act(tester);
  }

  await build();
  if (!render) return;
  // 偽の時計の中では写真が読み終わらないので、本物の時計で読んでおき、描き直す。
  final images = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .toList();
  final configuration = createLocalImageConfiguration(
    tester.element(find.byKey(boundary)),
  );
  // 読みかけの写真を手放してから読み直す（使われている写真は、キャッシュを消しても残るため）。
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(() async {
    imageCache
      ..clear()
      ..clearLiveImages();
    await Future.wait([
      for (final image in images) _load(image, configuration),
    ]);
  });
  await build();
}

Future<void> _load(ImageProvider image, ImageConfiguration configuration) {
  final done = Completer<void>();
  final stream = image.resolve(configuration);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return done.future;
}

Widget _app(
  ShotWorld world,
  ShotScene scene,
  GlobalKey boundary, {
  required AppDatabase database,
  required String photo,
  required Directory documents,
}) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(database),
    visitsProvider.overrideWithValue(AsyncData(world.visits)),
    homeBaseSettingsProvider.overrideWithValue(AsyncData(world.homeBases)),
    wishesProvider.overrideWithValue(AsyncData(world.wishes)),
    activeCheckinProvider.overrideWithValue(AsyncData(scene.checkin)),
    documentsDirectoryProvider.overrideWithValue(documents),
    recordRepositoryProvider.overrideWithValue(
      _Repository(scene.checkin, world.shops),
    ),
    wishRepositoryProvider.overrideWithValue(FakeWishRepository()),
    photoPickerProvider.overrideWithValue(FakePhotoPicker(cameraPath: photo)),
    photoMetadataReaderProvider.overrideWithValue(FakePhotoMetadataReader()),
    recordDraftStoreProvider.overrideWithValue(MemoryRecordDraftStore()),
    notificationServiceProvider.overrideWithValue(FakeNotificationService()),
    locationServiceProvider.overrideWithValue(
      FakeLocationService(position: world.here),
    ),
    nearbyShopFinderProvider.overrideWithValue(
      FakeShopFinder(shops: world.found),
    ),
    shopSearchServiceProvider.overrideWithValue(
      FakeShopSearchService(
        ShopSearchResult(here: world.here, candidates: scene.candidates),
      ),
    ),
    mapTilesEnabledProvider.overrideWithValue(false),
    ramenInChoApiProvider.overrideWithValue(_Api()),
    showOnboardingOnLaunchProvider.overrideWithValue(false),
    clockProvider.overrideWithValue(() => world.now),
  ],
  child: RepaintBoundary(
    key: boundary,
    child: scene.home == null
        ? const RamenInChoApp()
        : localizedApp(home: scene.home!, theme: buildAppTheme()),
  ),
);

Future<void> settleShot(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// [boundary]の中を、[pixelRatio]倍の画像にする。
Future<ui.Image> captureShot(GlobalKey boundary, double pixelRatio) {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return render.toImage(pixelRatio: pixelRatio);
}

Future<List<int>> encodePng(ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// 記録の写真の代わりに、上から見た丼の絵を描く。[soup]でスープの色を変える。
Future<List<int>> bowlPhoto({
  Color soup = const Color(0xFFC98A3D),
  Color rim = const Color(0xFF8A2C1D),
}) async {
  const size = 800.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()..color = const Color(0xFF6B4A33),
  );
  const center = Offset(size / 2, size / 2);
  canvas.drawCircle(center, 330, Paint()..color = Washi.page);
  canvas.drawCircle(center, 300, Paint()..color = rim);
  canvas.drawCircle(center, 270, Paint()..color = soup);
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
  return encodePng(image);
}

class _Repository extends FakeRecordRepository {
  _Repository(this.checkin, this.shops);

  final Checkin? checkin;
  final List<Shop> shops;

  @override
  Future<Checkin?> activeCheckin() async => checkin;

  @override
  Future<List<Shop>> allShops() async => shops;
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
