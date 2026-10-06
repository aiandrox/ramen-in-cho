import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/map/location_picker_screen.dart';
import 'package:ramen_in_cho/features/map/washi_map.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  const sapporo = GeoPoint(43.0687, 141.3508);
  const fukuoka = GeoPoint(33.5902, 130.4017);

  late FakeLocationService location;
  GeoPoint? result;

  Future<void> pumpPicker(
    WidgetTester tester, {
    GeoPoint? initial,
    List<HomeBaseSetting> settings = const [],
  }) async {
    result = null;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(const AsyncData([])),
          homeBaseSettingsProvider.overrideWithValue(AsyncData(settings)),
          wishesProvider.overrideWithValue(const AsyncData([])),
          mapTilesEnabledProvider.overrideWithValue(false),
          locationServiceProvider.overrideWithValue(location),
        ],
        child: localizedApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showLocationPicker(
                  context,
                  shopName: '麺屋北',
                  initial: initial,
                );
              },
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
  }

  MapController controller(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;

  testWidgets('渡した場所から始め、動かした地図の真ん中を店の場所として返す', (tester) async {
    location = FakeLocationService(position: fukuoka);
    await pumpPicker(tester, initial: sapporo);

    expect(controller(tester).camera.center.latitude, closeTo(43.0687, 1e-6));
    expect(find.text(ja.locationPickIntro('麺屋北')), findsOneWidget);

    controller(tester).move(const LatLng(43.07, 141.36), locationPickZoom);
    await tester.pump();
    await tester.tap(find.text(ja.locationPickUseCenter));
    await tester.pumpAndSettle();

    expect(result!.latitude, closeTo(43.07, 1e-6));
    expect(result!.longitude, closeTo(141.36, 1e-6));
  });

  testWidgets('場所が無ければ、許可済みの現在地から始める（開いただけでは許可を聞かない）', (tester) async {
    location = FakeLocationService(position: fukuoka);
    await pumpPicker(tester);

    expect(location.requests, [false]);
    expect(controller(tester).camera.center.latitude, closeTo(33.5902, 1e-6));
    expect(controller(tester).camera.zoom, locationPickZoom);
  });

  testWidgets('現在地の許可が無ければ拠点から始め、許可を聞かない', (tester) async {
    location = FakeLocationService(position: fukuoka, ready: false);
    await pumpPicker(
      tester,
      settings: [
        buildHomeBase(
          id: 'sapporo',
          name: '札幌',
          latitude: sapporo.latitude,
          longitude: sapporo.longitude,
          setAt: DateTime(2026, 3, 1),
        ),
      ],
    );

    expect(location.requests, isEmpty);
    expect(controller(tester).camera.center.latitude, closeTo(43.0687, 1e-6));
  });

  testWidgets('戻ると何も返さない', (tester) async {
    location = FakeLocationService(ready: false);
    await pumpPicker(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(LocationPickerScreen), findsNothing);
    expect(result, isNull);
  });
}
