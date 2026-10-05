import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/checkin/queue_suggestion.dart';
import 'package:ramen_in_cho/features/checkin/queue_suggestion_card.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
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
  const here = GeoPoint(35.0, 139.0);
  final now = DateTime(2026, 10, 3, 12);
  // 緯度0.0005度は約56m、0.001度は約111m。
  final near = buildShop(
    id: 'near',
    name: '近い店',
    latitude: 35.0005,
    longitude: 139.0,
  );
  final far = buildShop(
    id: 'far',
    name: '遠い店',
    latitude: 35.001,
    longitude: 139.0,
  );

  group('queueSuggestion', () {
    test('100m以内の記録済みの店を出し、100mより遠い店は出さない', () {
      expect(
        queueSuggestion(
          here: here,
          shops: [near, far],
          wishes: const [],
          visits: const [],
          now: now,
        )?.name,
        '近い店',
      );
      expect(
        queueSuggestion(
          here: here,
          shops: [far],
          wishes: const [],
          visits: const [],
          now: now,
        ),
        isNull,
      );
    });

    test('3時間以内に記録した店は出さない（食べたばかりの店で聞かない）', () {
      final recent = buildEntry(
        shop: near,
        eatenAt: now.subtract(const Duration(hours: 1)),
      );
      final old = buildEntry(
        shop: near,
        eatenAt: now.subtract(const Duration(hours: 4)),
      );

      expect(
        queueSuggestion(
          here: here,
          shops: [near],
          wishes: const [],
          visits: [recent],
          now: now,
        ),
        isNull,
      );
      expect(
        queueSuggestion(
          here: here,
          shops: [near],
          wishes: const [],
          visits: [old],
          now: now,
        )?.name,
        '近い店',
      );
    });

    test('撤退したばかりの店に当たる願も出さない', () {
      final retreat = buildEntry(
        shop: buildShop(
          id: 'shop',
          name: '願の店',
          latitude: 35.0003,
          longitude: 139.0,
          osmId: 'node/1',
        ),
        result: VisitResult.retreated,
        eatenAt: now.subtract(const Duration(minutes: 30)),
      );

      expect(
        queueSuggestion(
          here: here,
          shops: [retreat.shop],
          wishes: [
            Wish(
              id: 'wish',
              osmId: 'node/1',
              name: '願の店',
              latitude: 35.0003,
              longitude: 139.0,
              createdAt: DateTime(2026),
            ),
          ],
          visits: [retreat],
          now: now,
        ),
        isNull,
      );
    });

    test('まだ記録の無い願の店も、近ければ「願」を付けて出す', () {
      final suggestion = queueSuggestion(
        here: here,
        shops: const [],
        wishes: [
          Wish(
            id: 'wish',
            osmId: 'node/1',
            name: '願の店',
            latitude: 35.0003,
            longitude: 139.0,
            createdAt: DateTime(2026),
          ),
        ],
        visits: const [],
        now: now,
      )!;

      expect(suggestion.name, '願の店');
      expect(suggestion.wishId, 'wish');
      expect(suggestion.osmId, 'node/1');
    });
  });

  testWidgets('近くの店で開くと「並んだ？」を出し、押すと並び始める', (tester) async {
    final database = createTestDatabase();
    final repository = RecordRepository(database);
    final visit = await tester.runAsync(
      () => repository.saveEatenVisit(
        shop: const ShopInput(name: '近い店', latitude: 35.0005, longitude: 139.0),
        eatenAt: DateTime(2026, 9, 1, 12),
        now: DateTime(2026, 9, 1, 12),
      ),
    );
    final visits = await tester.runAsync(() => repository.watchVisits().first);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          visitsProvider.overrideWithValue(AsyncData(visits!)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(position: here),
          ),
          clockProvider.overrideWithValue(() => now),
        ],
        child: localizedApp(home: const Scaffold(body: QueueSuggestionCard())),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text(ja.queueSuggestion('近い店')), findsOneWidget);
    await tester.tap(find.text(ja.queueSuggestionYes));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final checkin = await tester.runAsync(repository.activeCheckin);
    expect(checkin!.shopId, visit!.shopId);
    expect(checkin.checkedInAt, now);
  });
}
