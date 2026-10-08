import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/backup/backup_screen.dart';
import 'package:ramen_in_cho/features/checkin/checkin_screen.dart';
import 'package:ramen_in_cho/features/checkin/retreat_screen.dart';
import 'package:ramen_in_cho/features/help/help_topics.dart';
import 'package:ramen_in_cho/features/home/app_tab.dart';
import 'package:ramen_in_cho/features/home_base/home_base_picker_screen.dart';
import 'package:ramen_in_cho/features/journal/shugyoroku_screen.dart';
import 'package:ramen_in_cho/features/record/record_result_screen.dart';
import 'package:ramen_in_cho/features/record/record_screen.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/share/share_screen.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/shop_candidate.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';

import '../support/builders.dart';
import '../support/fakes.dart';
import '../support/l10n.dart';
import 'shot_kit.dart';

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

ShotScene _scene({
  Widget? home,
  AppTab? tab,
  Checkin? checkin,
  List<ShopCandidate> candidates = _candidates,
  Future<void> Function(WidgetTester tester)? act,
}) => ShotScene(
  home: home,
  tab: tab,
  checkin: checkin,
  candidates: candidates,
  act: act,
);

Future<void> _takePhoto(WidgetTester tester) async {
  await tester.tap(find.text(ja.takePhoto));
  await settleShot(tester);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder));
  await settleShot(tester);
}

ShotScene _sceneFor(HelpShot shot) => switch (shot) {
  HelpShot.recordStart => _scene(
    tab: AppTab.records,
    act: (tester) async {
      await tester.tap(find.byType(RecordSealButton));
      await settleShot(tester);
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
  HelpShot.rating => _scene(tab: AppTab.records),
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
      await settleShot(tester);
      // 見つかった軒数の知らせが消え、探すボタンが見えるまで待つ。
      await tester.pump(const Duration(seconds: 5));
      await settleShot(tester);
    },
  ),
  HelpShot.journey => _scene(
    tab: AppTab.map,
    act: (tester) async {
      await tester.tap(find.byTooltip(ja.journeyToggle));
      await settleShot(tester);
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

ShotWorld _world(HelpShot shot) => ShotWorld(
  visits: _visits(unrated: shot == HelpShot.rating),
  wishes: _wishes,
  shops: [_kasumi, _seiran, _oboro, _hoshi],
  found: _found,
  homeBases: [buildHomeBase(name: 'みどり台駅', setAt: DateTime(2026))],
  now: _now,
  here: _here,
);

void main() {
  late String photo;
  WidgetsApp.debugAllowBannerOverride = false;

  setUpAll(() async {
    photo = p.join(createTempDirectory().path, 'bowl.png');
    if (!_update) {
      File(photo).writeAsBytesSync(const []);
      return;
    }
    await loadShotFonts();
    File(photo).writeAsBytesSync(await bowlPhoto());
  });

  test('どの絵にもファイルがある', () {
    for (final shot in HelpShot.values) {
      expect(File(shot.asset).existsSync(), isTrue, reason: shot.asset);
    }
  }, skip: _update);

  for (final shot in HelpShot.values) {
    testWidgets('使い方の絵 ${shot.name}', (tester) async {
      final boundary = GlobalKey();
      await pumpShot(
        tester,
        _world(shot),
        _sceneFor(shot),
        boundary: boundary,
        size: _size,
        photo: photo,
        documents: createTempDirectory(),
        render: _update,
      );
      expect(tester.takeException(), isNull);
      if (!_update) return;
      await tester.runAsync(() async {
        final image = await captureShot(boundary, 2);
        final png = p.join(createTempDirectory().path, '${shot.name}.png');
        File(png).writeAsBytesSync(await encodePng(image));
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
