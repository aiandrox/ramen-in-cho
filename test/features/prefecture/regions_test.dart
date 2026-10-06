import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';
import 'package:ramen_in_cho/features/inkan/region_frame.dart';
import 'package:ramen_in_cho/features/prefecture/prefecture_book_screen.dart';
import 'package:ramen_in_cho/features/prefecture/regions.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/scoring_providers.dart';

import '../../support/builders.dart';
import '../../support/l10n.dart';

ScoredVisit _scored({
  required String id,
  String? prefecture,
  DateTime? eatenAt,
  VisitResult result = VisitResult.eaten,
  String shop = '麺屋',
}) => ScoredVisit(
  visit: buildVisit(id: id, result: result, eatenAt: eatenAt),
  shop: buildShop(name: shop),
  points: PointsBreakdown.zero,
  isFirstVisit: false,
  isRetrySuccess: false,
  prefecture: prefecture,
);

void main() {
  test('都道府県から地方を決める（境目の県）', () {
    expect(regionOf('北海道'), Region.hokkaido);
    expect(regionOf('福島県'), Region.tohoku);
    expect(regionOf('茨城県'), Region.kanto);
    expect(regionOf('神奈川県'), Region.kanto);
    expect(regionOf('新潟県'), Region.chubu);
    expect(regionOf('愛知県'), Region.chubu);
    expect(regionOf('三重県'), Region.kinki);
    expect(regionOf('和歌山県'), Region.kinki);
    expect(regionOf('鳥取県'), Region.chugoku);
    expect(regionOf('山口県'), Region.chugoku);
    expect(regionOf('徳島県'), Region.shikoku);
    expect(regionOf('高知県'), Region.shikoku);
    expect(regionOf('福岡県'), Region.kyushu);
    expect(regionOf('沖縄県'), Region.kyushu);
    expect(regionOf('ソウル'), isNull);
  });

  test('印に書く短い名前は「都・府・県」を落とし、北海道はそのまま', () {
    expect(shortPrefectureName('東京都'), '東京');
    expect(shortPrefectureName('大阪府'), '大阪');
    expect(shortPrefectureName('京都府'), '京都');
    expect(shortPrefectureName('神奈川県'), '神奈川');
    expect(shortPrefectureName('北海道'), '北海道');
  });

  test('地方の外枠は、どの向きでも印の箱に収まる', () {
    for (final region in Region.values) {
      for (var i = 0; i < 360; i++) {
        final angle = i * math.pi / 180;
        final r = regionFrameRadius(region, angle);
        expect(r, greaterThan(0.6), reason: '$region $i°');
        // 印の箱は四角なので、縦と横の幅で確かめる。
        expect((r * math.cos(angle)).abs(), lessThanOrEqualTo(0.95));
        expect((r * math.sin(angle)).abs(), lessThanOrEqualTo(0.95));
      }
    }
  });

  test('都道府県ごとに、初めての1杯と食べた杯数をまとめる。撤退と都道府県のわからない店は入れない', () {
    final stamps = prefectureStamps([
      _scored(id: 'r', prefecture: '東京都', result: VisitResult.retreated),
      _scored(id: 'a', prefecture: '東京都'),
      _scored(id: 'b', prefecture: '大阪府'),
      _scored(id: 'c', prefecture: '東京都'),
      _scored(id: 'd'),
    ]);

    expect(stamps.keys, unorderedEquals(['東京都', '大阪府']));
    expect(stamps['東京都']!.first.visit.id, 'a');
    expect(stamps['東京都']!.bowls.map((s) => s.visit.id), ['a', 'c']);
    expect(stamps['大阪府']!.bowls, hasLength(1));
  });

  testWidgets('都道府県のわかる1杯の印には、短い都道府県名を入れる', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: InkanStamp(
          scored: _scored(id: 'v', prefecture: '東京都'),
        ),
      ),
    );

    expect(find.text('東京'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'東京都$')), findsOneWidget);
  });

  testWidgets('都道府県の印帳は47の場所を並べ、食べた都道府県だけ印と杯数を出し、タップで一覧を開く', (tester) async {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scoredVisitsProvider.overrideWithValue([
            _scored(
              id: 'a',
              prefecture: '宮城県',
              eatenAt: DateTime(2026, 9, 1, 12),
              shop: '仙台の麺屋',
            ),
            _scored(
              id: 'b',
              prefecture: '宮城県',
              eatenAt: DateTime(2026, 9, 2, 12),
              shop: '仙台の二軒目',
            ),
          ]),
        ],
        child: localizedApp(home: const PrefectureBookScreen()),
      ),
    );

    expect(find.text(ja.prefectureBookProgress(1)), findsOneWidget);
    for (final name in prefectureNames) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    expect(find.byType(BlankPrefectureSeal), findsNWidgets(46));
    expect(find.text(ja.prefectureBookFirst('2026/9/1')), findsOneWidget);
    expect(find.text(ja.prefectureBookBowls(2)), findsOneWidget);

    await tester.tap(find.text('宮城県'));
    await tester.pumpAndSettle();

    expect(
      find.text(ja.prefectureBookEntry('2026/9/1', '仙台の麺屋')),
      findsOneWidget,
    );
    expect(
      find.text(ja.prefectureBookEntry('2026/9/2', '仙台の二軒目')),
      findsOneWidget,
    );
  });
}
