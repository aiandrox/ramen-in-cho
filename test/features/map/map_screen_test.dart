import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/map/journey.dart';
import 'package:ramen_in_cho/features/map/map_camera.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/map/map_screen.dart';
import 'package:ramen_in_cho/features/map/pin_clusters.dart';
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
          location: GeoPoint(35.006, 139.0),
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
          latitude: 35.006,
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

    // 旅路の切り替えは見出しではなく、地図の右上に浮かべる。見出しには歯車だけ。
    final toggle = find.byTooltip(ja.journeyToggle);
    expect(
      find.descendant(of: find.byType(AppBar), matching: toggle),
      findsNothing,
    );
    expect(
      tester.getTopRight(toggle).dx,
      greaterThan(tester.getTopRight(find.byType(FlutterMap)).dx - 16),
    );
    expect(
      tester.getTopLeft(toggle).dy,
      greaterThanOrEqualTo(tester.getTopLeft(find.byType(FlutterMap)).dy),
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip(ja.settingsSection),
      ),
      findsOneWidget,
    );

    await tester.tap(toggle);
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

  testWidgets('重なるピンはまとめて軒数を出し、タップで寄ると分かれる', (tester) async {
    await pumpMap(tester, [
      buildEntry(
        shop: buildShop(
          id: 'a',
          name: '一番の店',
          latitude: 35.0,
          longitude: 139.0,
        ),
      ),
      buildEntry(
        shop: buildShop(
          id: 'b',
          name: '二番の店',
          latitude: 35.0005,
          longitude: 139.0,
        ),
      ),
    ]);
    expect(camera(tester).zoom, neighborhoodZoom);
    expect(find.bySemanticsLabel(ja.mapClusterLabel(2)), findsOneWidget);
    expect(find.bySemanticsLabel('一番の店'), findsNothing);

    await tester.tap(find.bySemanticsLabel(ja.mapClusterLabel(2)));
    await tester.pumpAndSettle();

    expect(camera(tester).zoom, greaterThan(neighborhoodZoom + 1));
    expect(find.bySemanticsLabel(ja.mapClusterLabel(2)), findsNothing);
    expect(find.bySemanticsLabel('一番の店'), findsOneWidget);
    expect(find.bySemanticsLabel('二番の店'), findsOneWidget);
  });

  testWidgets('同じ場所の店は、寄りきったら中の店を一覧で見せる', (tester) async {
    await pumpMap(tester, [
      for (final id in ['a', 'b'])
        buildEntry(
          shop: buildShop(
            id: id,
            name: '同じビルの店$id',
            latitude: 35.0003,
            longitude: 139.0,
          ),
        ),
    ]);
    final cluster = find.bySemanticsLabel(ja.mapClusterLabel(2));

    await tester.tap(cluster);
    await tester.pumpAndSettle();
    expect(camera(tester).zoom, clusterFitMaxZoom);
    expect(find.text(ja.mapClusterTitle(2)), findsNothing);

    await tester.tap(cluster);
    await tester.pumpAndSettle();
    expect(find.text(ja.mapClusterTitle(2)), findsOneWidget);
    expect(find.text('同じビルの店a'), findsOneWidget);
    expect(find.text('同じビルの店b'), findsOneWidget);
  });

  testWidgets('一覧で地図の店を近い順に見て絞り込み、タップでその店へ寄って詳しく見せる', (tester) async {
    await pumpMap(tester, [
      buildEntry(
        shop: buildShop(
          id: 'v',
          name: 'ラーメン一番',
          osmId: 'node/1',
          latitude: 35.001,
          longitude: 139.0,
        ),
      ),
    ]);
    await tester.tap(find.byTooltip(ja.mapSearchHere));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(ja.mapListButton));
    await tester.pumpAndSettle();
    expect(find.text(ja.mapListTitle(2)), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('ラーメン一番')).dy,
      lessThan(tester.getTopLeft(find.text('まだ行っていない店').first).dy),
    );

    await tester.tap(find.text(ja.mapListFilterUnvisited));
    await tester.pumpAndSettle();
    expect(find.text('ラーメン一番'), findsNothing);

    // 店名と「まだ行っていない店」の札が同じ字なので、先に出る店名の行を押す。
    await tester.tap(find.text('まだ行っていない店').first);
    await tester.pumpAndSettle();

    expect(camera(tester).center.latitude, closeTo(35.006, 1e-6));
    expect(camera(tester).zoom, greaterThanOrEqualTo(17));
    expect(find.text(ja.wishMakeButton), findsOneWidget);
  });

  group('旅路の再生を止める', () {
    final a = buildShop(id: 'a', latitude: 35.0, longitude: 139.0);
    final b = buildShop(id: 'b', latitude: 35.01, longitude: 139.0);
    final c = buildShop(id: 'c', latitude: 35.02, longitude: 139.0);
    final visits = [
      buildEntry(shop: a, eatenAt: DateTime(2026, 1, 1, 12)),
      buildEntry(shop: b, eatenAt: DateTime(2026, 1, 2, 12)),
      buildEntry(shop: c, eatenAt: DateTime(2026, 1, 3, 12)),
    ];

    testWidgets('再生は1杯目の店に寄せ、倍率を変えずに次の店へ進み、終わると旅路の全体を見せる', (tester) async {
      await pumpMap(tester, visits);
      await tester.tap(find.byTooltip(ja.journeyToggle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ja.journeyReplay));
      await tester.pump();
      expect(camera(tester).zoom, journeyFollowZoom);
      expect(camera(tester).center.latitude, closeTo(35.0, 1e-6));

      final step = journeyStepDuration(1112);
      await tester.pump(Duration(milliseconds: journeyStopPauseMs) + step ~/ 2);
      expect(camera(tester).zoom, journeyFollowZoom);
      expect(camera(tester).center.latitude, closeTo(35.005, 0.0005));

      await tester.pump(step ~/ 2 + const Duration(milliseconds: 100));
      expect(camera(tester).zoom, journeyFollowZoom);
      expect(camera(tester).center.latitude, closeTo(35.01, 1e-6));

      await tester.pumpAndSettle();
      expect(find.text(ja.journeyReplay), findsOneWidget);
      expect(camera(tester).zoom, isNot(journeyFollowZoom));
      expect(camera(tester).center.latitude, closeTo(35.01, 0.005));
    });

    testWidgets('再生中に地図を指で動かすと、追うのをやめてその場にとどまる', (tester) async {
      await pumpMap(tester, visits);
      await tester.tap(find.byTooltip(ja.journeyToggle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ja.journeyReplay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.drag(
        find.byType(FlutterMap),
        const Offset(0, 200),
        warnIfMissed: false,
      );
      await tester.pump();
      final moved = camera(tester).center;
      await tester.pump(const Duration(seconds: 3));

      expect(find.text(ja.journeyReplay), findsOneWidget);
      expect(camera(tester).center, moved);
      expect(camera(tester).zoom, journeyFollowZoom);
    });

    testWidgets('「止める」で途中でやめ、引き終えた旅路に戻る', (tester) async {
      await pumpMap(tester, visits);
      await tester.tap(find.byTooltip(ja.journeyToggle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ja.journeyReplay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(ja.journeyStop));
      await tester.pump();

      expect(find.text(ja.journeyReplay), findsOneWidget);
      expect(
        tester
            .widget<PolylineLayer>(find.byType(PolylineLayer))
            .polylines
            .single
            .points,
        hasLength(3),
      );
    });

    testWidgets('再生中に地図に触れても止まる', (tester) async {
      await pumpMap(tester, visits);
      await tester.tap(find.byTooltip(ja.journeyToggle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ja.journeyReplay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(
        tester.getBottomLeft(find.byType(FlutterMap)) + const Offset(400, -400),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(ja.journeyReplay), findsOneWidget);
    });

    testWidgets('動きを減らす設定では、再生せずに引き終えた旅路を見せる', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpMap(tester, visits);
      await tester.tap(find.byTooltip(ja.journeyToggle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ja.journeyReplay));
      await tester.pump();

      expect(find.text(ja.journeyReplay), findsOneWidget);
      expect(find.text(ja.journeyStop), findsNothing);
    });
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
