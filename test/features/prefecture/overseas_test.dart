import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';
import 'package:ramen_in_cho/features/inkan/region_frame.dart';
import 'package:ramen_in_cho/features/prefecture/overseas.dart';
import 'package:ramen_in_cho/features/prefecture/prefecture_book_screen.dart';
import 'package:ramen_in_cho/features/prefecture/prefectures.dart';
import 'package:ramen_in_cho/features/prefecture/regions.dart';
import 'package:ramen_in_cho/features/quests/quests.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/scoring_providers.dart';

import '../../support/builders.dart';
import '../../support/l10n.dart';

const _japan = {
  '東京': (35.6812, 139.7671),
  '那覇': (26.2124, 127.6809),
  '石垣': (24.3448, 124.1572),
  '稚内': (45.4156, 141.6731),
  '与那国': (24.4675, 123.0045),
  '対馬': (34.2030, 129.2875),
  '父島': (27.0945, 142.1918),
  '根室': (43.3300, 145.5828),
};

const _abroad = {
  'ソウル': (37.5665, 126.9780),
  '釜山': (35.1796, 129.0756),
  '台北': (25.0330, 121.5654),
  'ニューヨーク': (40.7128, -74.0060),
  'ウラジオストク': (43.1155, 131.8855),
  '上海': (31.2304, 121.4737),
};

ScoredVisit _scored(
  String id, {
  double? latitude,
  double? longitude,
  String? prefecture,
  VisitResult result = VisitResult.eaten,
  DateTime? eatenAt,
}) => ScoredVisit(
  visit: buildVisit(id: id, result: result, eatenAt: eatenAt),
  shop: buildShop(name: '麺屋$id', latitude: latitude, longitude: longitude),
  points: PointsBreakdown.zero,
  isFirstVisit: false,
  isRetrySuccess: false,
  prefecture: prefecture,
);

QuestProgress _progress(String id, List<ScoredVisit> scored) =>
    evaluateQuests(scored).firstWhere((p) => p.quest.id == id);

void main() {
  test('日本の島々（沖縄・八重山・稚内・離島）は日本、近くの国や遠い国は海外', () {
    for (final MapEntry(key: name, value: (lat, lng)) in _japan.entries) {
      expect(isInJapan(lat, lng), isTrue, reason: name);
    }
    for (final MapEntry(key: name, value: (lat, lng)) in _abroad.entries) {
      expect(isInJapan(lat, lng), isFalse, reason: name);
    }
  });

  test('位置のわからない店は海外にしない', () {
    expect(isOverseasShop(buildShop()), isFalse);
    expect(isOverseasShop(buildShop(latitude: 37.5665)), isFalse);
    expect(_scored('a').isOverseas, isFalse);
  });

  test('都道府県のわかる店は海外にしない。同梱の境界でも海外の街は都道府県なし', () {
    final index = PrefectureIndex.fromJson(
      File(prefecturesAsset).readAsStringSync(),
    );
    for (final MapEntry(key: name, value: (lat, lng)) in _japan.entries) {
      expect(index.prefectureAt(lat, lng), isNotNull, reason: name);
    }
    for (final MapEntry(key: name, value: (lat, lng)) in _abroad.entries) {
      expect(index.prefectureAt(lat, lng), isNull, reason: name);
    }
    final (lat, lng) = _abroad['ソウル']!;
    expect(_scored('a', latitude: lat, longitude: lng).isOverseas, isTrue);
    expect(
      _scored('b', latitude: lat, longitude: lng, prefecture: '東京都').isOverseas,
      isFalse,
    );
  });

  testWidgets('海外の1杯の印は羅針盤の外枠に「海外」と入れる', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: InkanStamp(
          scored: _scored('v', latitude: 25.033, longitude: 121.5654),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('${ja.inkanOverseas}\$')),
      findsOneWidget,
    );
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<RegionalInkanPainter>()
        .single;
    expect(painter.frame, SealFrame.overseas);
  });

  test('羅針盤の外枠は東西南北に長い針、そのあいだに短い針を出し、印の箱に収まる', () {
    final north = sealFrameRadius(SealFrame.overseas, 1.5707963);
    final northEast = sealFrameRadius(SealFrame.overseas, 0.7853982);
    final between = sealFrameRadius(SealFrame.overseas, 1.1780972);
    expect(north, closeTo(0.95, 0.001));
    expect(northEast, greaterThan(between));
    expect(north, greaterThan(northEast));
  });

  test('海外の記録は、食べたものだけを古い順に集める', () {
    final bowls = overseasBowls([
      _scored('a', latitude: 37.5, longitude: 127),
      _scored('b', latitude: 35.68, longitude: 139.76, prefecture: '東京都'),
      _scored(
        'c',
        latitude: 37.5,
        longitude: 127,
        result: VisitResult.retreated,
      ),
      _scored('d', latitude: 40.7, longitude: -74),
    ]);
    expect(bowls.map((s) => s.visit.id), ['a', 'd']);
  });

  Future<void> pumpBook(WidgetTester tester, List<ScoredVisit> scored) async {
    tester.view.physicalSize = const Size(1080, 14000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [scoredVisitsProvider.overrideWithValue(scored)],
        child: localizedApp(home: const PrefectureBookScreen()),
      ),
    );
  }

  testWidgets('都道府県の印帳は、海外で食べるまで海外の場所を出さない（灰色の「まだ」も出さない）', (tester) async {
    await pumpBook(tester, [
      _scored('a', prefecture: '東京都', latitude: 35.68, longitude: 139.76),
      _scored(
        'b',
        latitude: 37.5,
        longitude: 127,
        result: VisitResult.retreated,
      ),
    ]);

    expect(find.text(ja.prefectureBookOverseas), findsNothing);
    expect(find.byType(BlankPrefectureSeal), findsNWidgets(46));
  });

  testWidgets('海外で食べると、印帳の最後に海外の場所が現れ、タップで一覧を開く', (tester) async {
    await pumpBook(tester, [
      _scored(
        'a',
        latitude: 37.5665,
        longitude: 126.978,
        eatenAt: DateTime(2026, 9, 1, 12),
      ),
      _scored(
        'b',
        latitude: 25.033,
        longitude: 121.5654,
        eatenAt: DateTime(2026, 9, 3, 12),
      ),
    ]);

    expect(find.text(ja.prefectureBookProgress(0)), findsOneWidget);
    expect(find.text(ja.prefectureBookFirst('2026/9/1')), findsOneWidget);
    expect(find.text(ja.prefectureBookBowls(2)), findsOneWidget);
    expect(find.byType(BlankPrefectureSeal), findsNWidgets(47));

    await tester.tap(find.text(ja.prefectureBookOverseas).last);
    await tester.pumpAndSettle();

    expect(
      find.text(ja.prefectureBookEntry('2026/9/1', '麺屋a')),
      findsOneWidget,
    );
    expect(
      find.text(ja.prefectureBookEntry('2026/9/3', '麺屋b')),
      findsOneWidget,
    );
  });

  test('秘伝「全国行脚」は47都道府県目を食べた1杯で会得する', () {
    final entries = [
      for (final (i, name) in prefectureNames.indexed)
        buildEntry(
          shop: buildShop(id: name),
          eatenAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        ),
    ];
    // 46都道府県目までに同じ県で何杯食べても数は増えない。
    final repeat = buildEntry(
      shop: buildShop(id: prefectureNames.first),
      eatenAt: DateTime(2026, 1, 1, 18),
    );
    String? prefectureOf(Shop shop) => shop.id;

    final partial = _progress(
      'all_prefectures',
      scoreVisits([...entries.take(46), repeat], prefectureOf: prefectureOf),
    );
    expect(partial.isAchieved, isFalse);
    expect(partial.current, 46);

    final done = _progress(
      'all_prefectures',
      scoreVisits([...entries, repeat], prefectureOf: prefectureOf),
    );
    expect(done.isAchieved, isTrue);
    expect(
      done.levelAchievedAt.single,
      DateTime(2026, 1, 1).add(const Duration(days: 46)),
    );
    expect(done.levelAchievedBy.single.shop.id, '沖縄県');
  });

  test('秘伝「麺の道は海を越えて」は海外で初めて食べた1杯で会得する（撤退・位置不明・日本では会得しない）', () {
    final notYet = scoreVisits([
      buildEntry(
        shop: buildShop(id: 'tokyo', latitude: 35.68, longitude: 139.76),
        eatenAt: DateTime(2026, 5, 1, 12),
      ),
      buildEntry(shop: buildShop(id: 'unknown')),
      buildEntry(
        shop: buildShop(id: 'seoul', latitude: 37.5665, longitude: 126.978),
        result: VisitResult.retreated,
        eatenAt: DateTime(2026, 5, 2, 12),
      ),
    ]);
    expect(_progress('overseas', notYet).isAchieved, isFalse);

    final achieved = scoreVisits([
      buildEntry(
        shop: buildShop(id: 'tokyo', latitude: 35.68, longitude: 139.76),
        eatenAt: DateTime(2026, 5, 1, 12),
      ),
      buildEntry(
        shop: buildShop(id: 'taipei', latitude: 25.033, longitude: 121.5654),
        eatenAt: DateTime(2026, 5, 3, 12),
      ),
      buildEntry(
        shop: buildShop(id: 'seoul', latitude: 37.5665, longitude: 126.978),
        eatenAt: DateTime(2026, 5, 4, 12),
      ),
    ]);
    final progress = _progress('overseas', achieved);
    expect(progress.isAchieved, isTrue);
    expect(progress.levelAchievedAt.single, DateTime(2026, 5, 3, 12));
    expect(progress.levelAchievedBy.single.shop.id, 'taipei');
  });
}
