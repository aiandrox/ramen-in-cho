import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/home_base/home_base_picker_screen.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/map/washi_map.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
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
  final now = DateTime(2026, 10, 5, 12);

  late AppDatabase database;
  late FakeLocationService location;
  bool? result;

  Future<void> pumpPicker(
    WidgetTester tester, {
    List<HomeBaseSetting> settings = const [],
  }) async {
    database = createTestDatabase();
    for (final setting in settings) {
      await database
          .into(database.homeBaseSettings)
          .insert(setting.toCompanion());
    }
    result = null;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          // driftの監視はテストの偽の時間の中で止まってしまうため、一覧は固定の値にする。
          visitsProvider.overrideWithValue(const AsyncData([])),
          homeBaseSettingsProvider.overrideWithValue(AsyncData(settings)),
          wishesProvider.overrideWithValue(const AsyncData([])),
          mapTilesEnabledProvider.overrideWithValue(false),
          locationServiceProvider.overrideWithValue(location),
          clockProvider.overrideWithValue(() => now),
        ],
        child: localizedApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const HomeBasePickerScreen(),
                  ),
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

  MapCamera camera(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

  Future<void> nameAndDecide(WidgetTester tester, String name) async {
    expect(find.text(ja.homeBaseNameTitle), findsOneWidget);
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text(ja.homeBaseDecide));
    await tester.pumpAndSettle();
  }

  testWidgets('許可があれば現在地から始め、地図の真ん中を名前を付けて拠点にする', (tester) async {
    location = FakeLocationService(position: sapporo);
    await pumpPicker(tester);

    expect(location.requests, [false]);
    expect(camera(tester).center.latitude, closeTo(sapporo.latitude, 1e-6));
    expect(camera(tester).center.longitude, closeTo(sapporo.longitude, 1e-6));

    await tester.tap(find.text(ja.homeBaseUseCenter));
    await tester.pumpAndSettle();
    await nameAndDecide(tester, '札幌');

    // 初めて決めたので、秘伝「拠点を構える」を知らせる。
    expect(find.text(ja.homeBaseHidenGained), findsOneWidget);
    await tester.tap(find.text(ja.homeBaseHidenOk));
    await tester.pumpAndSettle();

    final saved = await database.select(database.homeBaseSettings).get();
    expect(saved, hasLength(1));
    expect(saved.single.name, '札幌');
    expect(saved.single.latitude, closeTo(sapporo.latitude, 1e-6));
    expect(saved.single.longitude, closeTo(sapporo.longitude, 1e-6));
    expect(saved.single.setAt, now);
    expect(result, isTrue);
  });

  testWidgets('拠点があればそこから始め、開いただけでは位置の許可を聞かない', (tester) async {
    location = FakeLocationService(position: sapporo, ready: false);
    final shinjuku = buildHomeBase(
      id: 'shinjuku',
      name: '新宿',
      latitude: 35.6909,
      longitude: 139.7003,
      setAt: DateTime(2026, 3, 1),
    );
    await pumpPicker(tester, settings: [shinjuku]);

    expect(location.requests, isEmpty);
    expect(camera(tester).center.latitude, closeTo(35.6909, 1e-6));
    expect(camera(tester).center.longitude, closeTo(139.7003, 1e-6));
    expect(find.text(ja.homeBaseLine('新宿')), findsOneWidget);

    // 呼び名を打たなければ「このあたり」になる。2回目なので秘伝は知らせない。
    await tester.tap(find.text(ja.homeBaseUseCenter));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.homeBaseDecide));
    await tester.pumpAndSettle();

    expect(find.text(ja.homeBaseHidenGained), findsNothing);
    final saved = await (database.select(
      database.homeBaseSettings,
    )..where((s) => s.id.equals('shinjuku').not())).get();
    expect(saved.single.name, ja.homeBaseNameDefault);
    expect(saved.single.latitude, closeTo(35.6909, 1e-6));
  });

  testWidgets('地図が出なくても、現在地を拠点にできる', (tester) async {
    location = FakeLocationService(position: sapporo, ready: false);
    await pumpPicker(tester);

    await tester.tap(find.text(ja.homeBaseUseHere));
    await tester.pumpAndSettle();
    expect(location.requests, [true]);
    await nameAndDecide(tester, '札幌駅');
    await tester.tap(find.text(ja.homeBaseHidenOk));
    await tester.pumpAndSettle();

    final saved = await database.select(database.homeBaseSettings).get();
    expect(saved.single.name, '札幌駅');
    expect(saved.single.latitude, sapporo.latitude);
    expect(saved.single.longitude, sapporo.longitude);
  });

  testWidgets('呼び名の窓を閉じたら保存しない', (tester) async {
    location = FakeLocationService(position: sapporo);
    await pumpPicker(tester);

    await tester.tap(find.text(ja.homeBaseUseCenter));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.cancel));
    await tester.pumpAndSettle();

    expect(await database.select(database.homeBaseSettings).get(), isEmpty);
    expect(find.byType(HomeBasePickerScreen), findsOneWidget);
  });
}
