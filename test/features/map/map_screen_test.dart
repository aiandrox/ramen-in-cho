import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/map/map_camera.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/map/map_screen.dart';
import 'package:ramen_in_cho/features/map/washi_map.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/nearby_shop_finder.dart';
import 'package:ramen_in_cho/features/visit_detail/visit_detail_screen.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  late FakeShopFinder overpass;
  late FakeLocationService location;

  setUp(() {
    location = FakeLocationService(position: const GeoPoint(35.0, 139.0));
    overpass = FakeShopFinder(
      shops: const [
        FoundShop(
          osmId: 'node/1',
          name: '行った店',
          location: GeoPoint(35.001, 139.0),
        ),
        FoundShop(
          osmId: 'node/2',
          name: 'まだ行っていない店',
          location: GeoPoint(35.002, 139.0),
        ),
      ],
    );
  });

  Future<void> pumpMap(WidgetTester tester, List<VisitWithShop> visits) async {
    // テストの文字は1文字が正方形で幅を取るため、出典の表示が収まるよう横を広くする。
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(visits)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          recordRepositoryProvider.overrideWithValue(FakeRecordRepository()),
          documentsDirectoryProvider.overrideWithValue(createTempDirectory()),
          mapTilesEnabledProvider.overrideWithValue(false),
          locationServiceProvider.overrideWithValue(location),
          nearbyShopFinderProvider.overrideWithValue(overpass),
        ],
        child: localizedApp(home: const MapScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  MapCamera camera(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

  // 現在地（35.0, 139.0）から遠く離れた店。
  final farShop = buildShop(
    id: 'far',
    name: '遠くの店',
    osmId: 'node/9',
    latitude: 36.0,
    longitude: 140.0,
  );

  testWidgets('行った店が無くても地図を出し、周辺を探せることを案内する', (tester) async {
    await pumpMap(tester, [buildEntry(shop: buildShop(id: 'no-location'))]);

    expect(find.text(ja.mapEmpty), findsOneWidget);
    expect(find.byTooltip(ja.mapSearchHere), findsOneWidget);
    expect(location.requests, [true]);
  });

  testWidgets('「このあたりを探す」で1km以内を探し、まだ行っていない店だけをピンで出す', (tester) async {
    final visited = buildShop(
      id: 'visited',
      name: '行った店',
      osmId: 'node/1',
      latitude: 35.001,
      longitude: 139.0,
    );
    await pumpMap(tester, [buildEntry(shop: visited)]);

    await tester.tap(find.byTooltip(ja.mapSearchHere));
    await tester.pumpAndSettle();

    expect(overpass.radii, [nearbySearchRadiusMeters]);
    expect(find.text(ja.mapNearbyFound(1)), findsOneWidget);
    expect(find.bySemanticsLabel('まだ行っていない店'), findsOneWidget);
    expect(find.text(ja.openPoiAttribution), findsOneWidget);
  });

  testWidgets('位置のわからない手入力の店や、撤退しただけの店は「まだ行っていない店」に出さない', (tester) async {
    await pumpMap(tester, [
      buildEntry(
        shop: buildShop(id: 'typed', name: '行った店'),
      ),
      buildEntry(
        shop: buildShop(
          id: 'retreated',
          name: 'まだ行っていない店',
          osmId: 'node/2',
          latitude: 35.002,
          longitude: 139.0,
        ),
        result: VisitResult.retreated,
      ),
    ]);

    await tester.tap(find.byTooltip(ja.mapSearchHere));
    await tester.pumpAndSettle();

    expect(find.text(ja.mapNearbyNone), findsOneWidget);
  });

  testWidgets('検索に失敗したら知らせる', (tester) async {
    overpass.error = StateError('offline');
    await pumpMap(tester, const []);

    await tester.tap(find.byTooltip(ja.mapSearchHere));
    await tester.pumpAndSettle();

    expect(find.text(ja.mapSearchFailed), findsOneWidget);
  });

  testWidgets('旅路を開くと、年ごとの軒数と距離を出し、再生と遠征を選べる', (tester) async {
    final a = buildShop(id: 'a', latitude: 35.0, longitude: 139.0);
    final b = buildShop(id: 'b', latitude: 35.01, longitude: 139.0);
    await pumpMap(tester, [
      buildEntry(shop: a, eatenAt: DateTime(2025, 12, 1, 12)),
      buildEntry(shop: b, eatenAt: DateTime(2026, 1, 1, 12)),
      buildEntry(shop: a, eatenAt: DateTime(2026, 1, 2, 12)),
    ]);

    await tester.tap(find.byTooltip(ja.journeyToggle));
    await tester.pumpAndSettle();
    expect(find.text(ja.journeySummary(2, '2.2')), findsOneWidget);

    await tester.tap(find.text(ja.journeyYear(2026)));
    await tester.pumpAndSettle();
    expect(find.text(ja.journeySummary(2, '1.1')), findsOneWidget);

    await tester.tap(find.text(ja.journeyReplay));
    await tester.pump();
    expect(find.text(ja.journeyStop), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(ja.journeyReplay), findsOneWidget);

    await tester.tap(find.text(ja.journeyExpeditions));
    await tester.pumpAndSettle();
    expect(find.text(ja.journeyExpeditionsNone), findsOneWidget);
  });

  testWidgets('周辺を探している間は、地図の上に「探しています」と出す', (tester) async {
    final gate = Completer<void>();
    overpass.gate = gate;
    await pumpMap(tester, [buildEntry(shop: buildShop(id: 'no-location'))]);

    await tester.tap(find.byTooltip(ja.mapSearchHere));
    await tester.pump();
    expect(find.text(ja.mapSearching), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(ja.mapSearching), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  Future<void> openShopPageFromPin(WidgetTester tester, String name) async {
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == name,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.mapOpenShopPage));
    await tester.pumpAndSettle();
  }

  testWidgets('行った店のピンから、いちばん新しい記録のページを開く', (tester) async {
    final shop = buildShop(
      id: 'eaten',
      name: '食べた店',
      latitude: 35.0,
      longitude: 139.0,
    );
    final older = buildEntry(shop: shop, eatenAt: DateTime(2026, 9, 1, 12));
    final newer = buildEntry(
      shop: shop,
      eatenAt: DateTime(2026, 9, 20, 12),
      result: VisitResult.retreated,
    );
    await pumpMap(tester, [newer, older]);

    await openShopPageFromPin(tester, '食べた店');

    expect(find.byType(BottomSheet), findsNothing);
    final detail = tester.widget<VisitDetailScreen>(
      find.byType(VisitDetailScreen),
    );
    expect(detail.visitId, newer.visit.id);
  });

  testWidgets('撤退しただけの店のピンからも、その店のページを開ける', (tester) async {
    final shop = buildShop(
      id: 'retreated',
      name: '挫折した店',
      latitude: 35.0,
      longitude: 139.0,
    );
    final retreat = buildEntry(shop: shop, result: VisitResult.retreated);
    await pumpMap(tester, [retreat]);

    await openShopPageFromPin(tester, '挫折した店');

    final detail = tester.widget<VisitDetailScreen>(
      find.byType(VisitDetailScreen),
    );
    expect(detail.visitId, retreat.visit.id);
  });

  testWidgets('開いて現在地がわかったら、行った店が遠くにあっても現在地のまわりを見せる', (tester) async {
    await pumpMap(tester, [buildEntry(shop: farShop)]);

    expect(camera(tester).center.latitude, closeTo(35.0, 1e-6));
    expect(camera(tester).center.longitude, closeTo(139.0, 1e-6));
    expect(camera(tester).zoom, neighborhoodZoom);
  });

  testWidgets('現在地がわからなければ、行った店が入る範囲を見せる', (tester) async {
    location.position = null;
    await pumpMap(tester, [buildEntry(shop: farShop)]);

    expect(camera(tester).center.latitude, closeTo(36.0, 1e-3));
    expect(camera(tester).center.longitude, closeTo(140.0, 1e-3));
  });

  testWidgets('旅路を開くと、道のり全体が入る範囲に合わせる', (tester) async {
    await pumpMap(tester, [buildEntry(shop: farShop)]);

    await tester.tap(find.byTooltip(ja.journeyToggle));
    await tester.pumpAndSettle();

    expect(camera(tester).center.latitude, closeTo(36.0, 1e-3));
    expect(camera(tester).center.longitude, closeTo(140.0, 1e-3));
  });

  test('自分で地図を動かしたあとや、旅路を見ているときは現在地へ寄せない', () {
    expect(
      shouldCenterOnArrivedLocation(userMoved: false, showingJourney: false),
      isTrue,
    );
    expect(
      shouldCenterOnArrivedLocation(userMoved: true, showingJourney: false),
      isFalse,
    );
    expect(
      shouldCenterOnArrivedLocation(userMoved: false, showingJourney: true),
      isFalse,
    );
  });
}
