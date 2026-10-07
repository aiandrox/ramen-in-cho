import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/analytics/analytics.dart';
import 'package:ramen_in_cho/features/analytics/analytics_events.dart';
import 'package:ramen_in_cho/features/analytics/analytics_user_properties.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/prefecture/regions.dart';
import 'package:ramen_in_cho/features/quests/quests.dart';
import 'package:ramen_in_cho/features/record/photo_metadata.dart';
import 'package:ramen_in_cho/features/record/photo_picker.dart';
import 'package:ramen_in_cho/features/record/record_controller.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/rank_history.dart';
import 'package:ramen_in_cho/features/scoring/record_outcome.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';
import 'package:ramen_in_cho/features/shop_search/nearby_shop_finder.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/ramen_in_cho_api.dart';
import 'package:ramen_in_cho/features/shop_search/shop_candidate.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';

const _here = GeoPoint(35.0, 139.0);
final _now = DateTime(2026, 9, 30, 12);

/// 送ってよい値は、種類（英小文字・数字・_ と記号だけ）・数・1/0 だけ。
void expectSafe(AnalyticsEvent event) {
  expect(event.name, matches(RegExp(r'^[a-z][a-z0-9_]{0,39}$')));
  expect(event.parameters.length, lessThanOrEqualTo(25));
  for (final MapEntry(:key, :value) in event.parameters.entries) {
    expect(key, matches(RegExp(r'^[a-z][a-z0-9_]{0,39}$')));
    if (value is String) {
      expect(value, matches(RegExp(r'^[a-z0-9_+\-]{1,36}$')), reason: key);
    } else {
      expect(value, isA<num>(), reason: key);
    }
  }
}

void main() {
  group('幅にまとめる', () {
    test('杯数の幅', () {
      expect([0, 1, 2, 4, 5, 9, 10, 19, 20, 49, 50, 99, 100, 500].map(bucket), [
        '0',
        '1',
        '2-4',
        '2-4',
        '5-9',
        '5-9',
        '10-19',
        '10-19',
        '20-49',
        '20-49',
        '50-99',
        '50-99',
        '100+',
        '100+',
      ]);
    });

    test('着丼までの時間・修行点・日数の幅', () {
      expect(elapsedBucket(const Duration(seconds: 14)), '0-14s');
      expect(elapsedBucket(const Duration(seconds: 15)), '15-29s');
      expect(elapsedBucket(const Duration(minutes: 90)), '60m+');
      expect(pointsBucket(19), '0-19');
      expect(pointsBucket(20), '20-29');
      expect(pointsBucket(54), '40-54');
      expect(pointsBucket(55), '55-79');
      expect(daysBucket(0), '0');
      expect(daysBucket(6), '1-6');
      expect(daysBucket(7), '7-29');
      expect(daysBucket(365), '365-729');
    });
  });

  test('何もしない送り先と、Firebase の準備が無いときの送り先は例外を出さない', () async {
    const noop = NoopAnalyticsService();
    await noop.log(const AnalyticsEvent('test_event'));
    await noop.logScreen('records');
    await noop.setUserProperties({'total_bowls': '1'});

    final firebase = FirebaseAnalyticsService();
    await firebase.log(const AnalyticsEvent('test_event'));
    await firebase.logScreen('records');
    await firebase.setUserProperties({'total_bowls': '1'});
  });

  test('選んだ候補の検索元', () {
    expect(shopSourceOf(null), ShopSourceKind.manual);
    expect(
      shopSourceOf(const ShopCandidate(name: 'a', osmId: 'node/1')),
      ShopSourceKind.osm,
    );
    expect(
      shopSourceOf(const ShopCandidate(name: 'a', shopId: 's')),
      ShopSourceKind.known,
    );
    expect(
      shopSourceOf(const ShopCandidate(name: 'a', shopId: 's', wishId: 'w')),
      ShopSourceKind.wish,
    );
    expect(
      shopSourceOf(const ShopCandidate(name: 'a')),
      ShopSourceKind.curated,
    );
    expect(
      shopSourceOf(
        const ShopCandidate(
          name: 'a',
          dataSource: ShopSource(
            attributions: ['Web Services by Yahoo! JAPAN'],
          ),
        ),
      ),
      ShopSourceKind.yahoo,
    );
    expect(
      shopSourceOf(
        const ShopCandidate(
          name: 'a',
          dataSource: ShopSource(licenses: ['CC-BY-4.0']),
        ),
      ),
      ShopSourceKind.openpoi,
    );
  });

  test('保存したあとのイベントは、昇段・型と秘伝を含め、名前や位置を入れない', () {
    final shop = buildShop(
      id: 's1',
      name: '麺屋テスト',
      latitude: 35.0,
      longitude: 139.0,
    );
    final visit = buildVisit(
      id: 'v1',
      shopId: 's1',
      eatenAt: _now,
      waitMinutes: 30,
      isLimited: true,
      memo: 'ひみつのメモ',
    );
    final all = [VisitWithShop(visit: visit, shop: shop)];
    final outcome = computeRecordOutcome(all, 'v1')!;
    const summary = RecordSaveSummary(
      entry: RecordEntry.plain,
      photoSource: PhotoSource.camera,
      shopSource: ShopSourceKind.osm,
      usedNameSearch: false,
      hasRating: true,
      hasStyle: false,
      isLimited: true,
      hasManualWait: false,
      hasMemo: true,
      shopMemoEdited: false,
      famousChanged: false,
      photoRotated: false,
      pinnedLocation: false,
      resumedDraft: false,
      atCheckinShop: true,
      elapsed: Duration(seconds: 40),
    );

    final events = recordOutcomeEvents(
      outcome,
      summary: summary,
      totalBowls: 1,
      firstRecordAt: _now,
    );

    final names = events.map((e) => e.name).toList();
    expect(names, containsAll(['record_saved', 'record_bonuses', 'rank_up']));
    expect(
      events.where((e) => e.name == 'quest_achieved').map((e) => e.parameters),
      contains(
        allOf(
          containsPair('quest_id', 'first_bowl'),
          containsPair('kind', 'hiden'),
        ),
      ),
    );
    final saved = events.firstWhere((e) => e.name == 'record_saved');
    expect(saved.parameters, containsPair('has_memo', 1));
    expect(saved.parameters, containsPair('has_style', 0));
    expect(saved.parameters, containsPair('has_wait', 1));
    expect(saved.parameters, containsPair('elapsed', '30-59s'));
    expect(saved.parameters, containsPair('total_bowls', '1'));
    final bonuses = events.firstWhere((e) => e.name == 'record_bonuses');
    expect(bonuses.parameters, containsPair('wait', 1));
    expect(bonuses.parameters, containsPair('limited', 1));
    expect(bonuses.parameters, containsPair('first_visit', 1));
    expect(bonuses.parameters, containsPair('morning', 0));
    for (final event in events) {
      expectSafe(event);
      final text = event.parameters.values.join(' ');
      expect(text, isNot(contains('麺屋テスト')));
      expect(text, isNot(contains('メモ')));
      expect(text, isNot(contains('35.0')));
    }
  });

  test('案内を閉じたときは、選んだ始め方と段階だけを送る', () {
    final chosen = AnalyticsEvents.onboardingFinished(
      start: 'record',
      step: 'start',
    );
    final closed = AnalyticsEvents.onboardingFinished(
      start: null,
      step: snake('homeBase'),
    );
    expectSafe(chosen);
    expectSafe(closed);
    expect(chosen.parameters, {'start': 'record', 'step': 'start'});
    expect(closed.parameters, {'start': 'closed', 'step': 'home_base'});
    expectSafe(AnalyticsEvents.homeBaseSet(via: 'first'));
  });

  test('利用者ごとの様子は幅にまとめた値だけ', () {
    final shop = buildShop(id: 's1', latitude: 35.0, longitude: 139.0);
    final scored = scoreVisits([
      VisitWithShop(
        visit: buildVisit(id: 'v1', shopId: 's1', eatenAt: _now),
        shop: shop,
      ),
    ]);
    final properties = analyticsUserProperties(
      scored: scored,
      quests: evaluateQuests(scored),
      homeBase: null,
      rank: currentRank(scored),
      prefectureCount: prefectureStamps(scored).length,
    );
    expect(properties, {
      'current_rank': 'kyu5',
      'total_bowls': '1',
      'hiden_count': '1',
      'kata_levels_sum': '0',
      'prefectures_count': '0',
      'has_home_base': '0',
    });
    for (final MapEntry(:key, :value) in properties.entries) {
      expect(key.length, lessThanOrEqualTo(24));
      expect(value.length, lessThanOrEqualTo(36));
    }
  });

  group('記録の画面から送る数', () {
    late FakeAnalyticsService analytics;
    late FakeShopFinder finder;
    late ProviderContainer container;

    setUp(() {
      final documents = createTempDirectory();
      final photo = File(p.join(createTempDirectory().path, 'camera.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      analytics = FakeAnalyticsService();
      finder = FakeShopFinder(
        shops: const [
          FoundShop(
            osmId: 'node/1',
            name: '麺屋テスト',
            location: GeoPoint(35.001, 139.0),
          ),
        ],
      );
      container = ProviderContainer(
        overrides: [
          analyticsProvider.overrideWithValue(analytics),
          appDatabaseProvider.overrideWithValue(createTestDatabase()),
          documentsDirectoryProvider.overrideWithValue(documents),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(position: _here),
          ),
          nearbyShopFinderProvider.overrideWithValue(finder),
          photoPickerProvider.overrideWithValue(
            FakePhotoPicker(cameraPath: photo.path, galleryPath: photo.path),
          ),
          photoMetadataReaderProvider.overrideWithValue(
            FakePhotoMetadataReader(),
          ),
          clockProvider.overrideWithValue(() => _now),
          addressGeocoderProvider.overrideWithValue((_) async => null),
        ],
      );
      addTearDown(container.dispose);
      container.listen(recordControllerProvider, (_, _) {});
    });

    RecordController controller() =>
        container.read(recordControllerProvider.notifier);

    test('写真を撮って候補を選んで保存すると、入れた項目だけが 1 になる', () async {
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      final state = container.read(recordControllerProvider);
      controller().selectShop(state.candidates.single);
      controller().setRating(4);
      controller().setMemo('ひみつのメモ');

      expect(await controller().save(), isNotNull);

      expect(
        analytics.named('record_started').single.parameters,
        containsPair('entry', 'plain'),
      );
      expect(
        analytics.named('shop_search').single.parameters,
        allOf(
          containsPair('purpose', 'record'),
          containsPair('result', 'found'),
          containsPair('count', '1'),
        ),
      );
      final summary = controller().lastSaveSummary!;
      expect(summary.photoSource, PhotoSource.camera);
      expect(summary.shopSource, ShopSourceKind.osm);
      expect(summary.hasRating, isTrue);
      expect(summary.hasMemo, isTrue);
      expect(summary.hasStyle, isFalse);
      expect(summary.isLimited, isFalse);
      expect(summary.usedNameSearch, isFalse);
      for (final event in analytics.events) {
        expectSafe(event);
      }
    });

    test('店の検索に失敗したことを送る', () async {
      finder.error = const SocketException('offline');
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();

      expect(
        analytics.named('shop_search').single.parameters,
        allOf(containsPair('result', 'failed'), containsPair('count', '0')),
      );
    });
  });
}
