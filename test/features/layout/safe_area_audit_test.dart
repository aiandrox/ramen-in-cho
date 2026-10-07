import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/backup/backup_screen.dart';
import 'package:ramen_in_cho/features/checkin/checkin_controller.dart';
import 'package:ramen_in_cho/features/checkin/checkin_screen.dart';
import 'package:ramen_in_cho/features/credits/credits_screen.dart';
import 'package:ramen_in_cho/features/home/app_tab.dart';
import 'package:ramen_in_cho/features/home_base/home_base_picker_screen.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/journal/shugyoroku_screen.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/map/location_picker_screen.dart';
import 'package:ramen_in_cho/features/map/washi_map.dart';
import 'package:ramen_in_cho/features/notifications/notification_service.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_screen.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_store.dart';
import 'package:ramen_in_cho/features/record/photo_metadata.dart';
import 'package:ramen_in_cho/features/record/photo_picker.dart';
import 'package:ramen_in_cho/features/record/record_draft.dart';
import 'package:ramen_in_cho/features/record/record_result_screen.dart';
import 'package:ramen_in_cho/features/record/record_screen.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/review/year_review_list_screen.dart';
import 'package:ramen_in_cho/features/review/year_review_screen.dart';
import 'package:ramen_in_cho/features/scoring/rank_history_screen.dart';
import 'package:ramen_in_cho/features/settings/settings_screen.dart';
import 'package:ramen_in_cho/features/share/share_screen.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';
import 'package:ramen_in_cho/features/shop_search/nearby_shop_finder.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/ramen_in_cho_api.dart';
import 'package:ramen_in_cho/features/shop_search/shop_candidate.dart';
import 'package:ramen_in_cho/features/shop_search/shop_search_service.dart';
import 'package:ramen_in_cho/features/visit_detail/visit_detail_screen.dart';
import 'package:ramen_in_cho/features/visit_detail/visit_edit_screen.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/main.dart';
import 'package:ramen_in_cho/theme/app_theme.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';
import 'package:ramen_in_cho/theme/washi_sheet.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

/// 端末の下の帯（Android のナビゲーションバー、iPhone のホームインジケーター）に、
/// ボタンや文字がかぶったり、ぎりぎりに寄ったりしていないかを、画面ごとに確かめる。
/// 新しい画面や下から出る窓を作ったら、[_screens] に足す。
const _margin = 8.0;

typedef _Device = ({String name, double top, double bottom});

const _devices = <_Device>[
  (name: 'Android（3ボタン）', top: 24, bottom: 48),
  (name: 'iPhone（ホームインジケーター）', top: 47, bottom: 34),
];

typedef _Audit = Future<void> Function(String where);

typedef _Screen = ({
  String name,
  Widget? home,
  AppTab? tab,
  Checkin? checkin,
  Future<void> Function(WidgetTester tester, _Audit audit)? visit,
});

final _now = DateTime(2026, 10, 5, 12);

final _shopA = buildShop(
  id: 'a',
  name: '麺屋テスト',
  latitude: 35.0,
  longitude: 139.0,
  osmId: 'node/1',
  strategyMemo: '開店前に並ぶ',
);
final _shopB = buildShop(
  id: 'b',
  name: '中華そば遠征',
  latitude: 36.0,
  longitude: 140.0,
);

List<VisitWithShop> _visits() => [
  for (var i = 0; i < 14; i++)
    VisitWithShop(
      shop: i.isEven ? _shopA : _shopB,
      visit: buildVisit(
        id: 'v$i',
        shopId: i.isEven ? 'a' : 'b',
        eatenAt: DateTime(2026, 10 - (i ~/ 3), 4 - (i % 3), 12),
        waitMinutes: 20 + i,
        style: RamenStyle.values[i % RamenStyle.values.length],
        memo: i == 0 ? 'うまかった' : '',
        result: i == 3 ? VisitResult.retreated : VisitResult.eaten,
      ),
    ),
  VisitWithShop(
    shop: _shopA,
    visit: buildVisit(id: 'old', shopId: 'a', eatenAt: DateTime(2025, 10, 5)),
  ),
  VisitWithShop(
    shop: buildShop(id: 'c', name: '場所のわからない店'),
    visit: buildVisit(id: 'vc', shopId: 'c', eatenAt: DateTime(2025, 3, 1)),
  ),
];

final _wishes = [
  Wish(
    id: 'w1',
    name: 'まだの店',
    latitude: 35.001,
    longitude: 139.001,
    trigger: '友だち',
    note: 'つけ麺',
    createdAt: DateTime(2026, 9, 1),
  ),
  Wish(
    id: 'w2',
    shopId: 'a',
    name: '麺屋テスト',
    createdAt: DateTime(2026, 8, 1),
    fulfilledVisitId: 'v0',
  ),
];

const _found = [
  FoundShop(osmId: 'node/1', name: '麺屋テスト', location: GeoPoint(35.0, 139.0)),
  FoundShop(
    osmId: 'node/2',
    name: 'らーめん二号',
    location: GeoPoint(35.0005, 139.0),
  ),
  FoundShop(osmId: 'node/3', name: '中華そば三号', location: GeoPoint(35.001, 139.0)),
];

final List<_Screen> _screens = [
  (
    name: '印帳（タブ）',
    home: null,
    tab: AppTab.records,
    checkin: null,
    visit: (tester, audit) async {
      await audit('一覧');
      // 真ん中の判子から開く窓（記録するか並ぶか）。
      await tester.tap(find.byType(RecordSealButton));
      await tester.pumpAndSettle();
      await audit('記録・並ぶの窓');
    },
  ),
  (
    name: '印帳（並んでいる最中）',
    home: null,
    tab: AppTab.records,
    checkin: Checkin(
      shopId: 'a',
      name: '麺屋テスト',
      latitude: 35.0,
      longitude: 139.0,
      checkedInAt: _now.subtract(const Duration(minutes: 20)),
    ),
    visit: null,
  ),
  (name: '願掛け（タブ）', home: null, tab: AppTab.wishes, checkin: null, visit: null),
  (
    name: '修行（タブ）',
    home: null,
    tab: AppTab.shugyo,
    checkin: null,
    visit: (tester, audit) async {
      await audit('一覧');
      final quest = find.text('着丼の道');
      await _reveal(tester, quest);
      await tester.tap(quest);
      await tester.pumpAndSettle();
      await audit('型の窓');
    },
  ),
  (
    name: '地図（タブ）',
    home: null,
    tab: AppTab.map,
    checkin: null,
    visit: (tester, audit) async {
      await audit('地図');
      await tester.tap(find.byTooltip(ja.mapSearchHere));
      await _settle(tester);
      await audit('周辺を探したあと');
      // 店が重なるとピンはまとまるので、一覧から行った店を開く。
      await tester.tap(find.byTooltip(ja.mapListButton));
      await _settle(tester);
      await audit('地図の店の一覧');
      await tester.tap(find.text('麺屋テスト'));
      await _settle(tester);
      await audit('行った店の窓');
      tester.state<ShellSheetHostState>(find.byType(ShellSheetHost)).close();
      await _settle(tester);
      await tester.tap(find.byTooltip(ja.journeyToggle));
      await _settle(tester);
      await audit('旅路');
      await tester.tap(find.text(ja.journeyExpeditions));
      await _settle(tester);
      await audit('遠征の窓');
    },
  ),
  (
    name: '記録画面',
    home: const RecordScreen(),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '並ぶ画面',
    home: const CheckinScreen(),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '保存直後の画面',
    home: const RecordResultScreen(visitId: 'v0'),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '店のページ',
    home: const VisitDetailScreen(visitId: 'v0'),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '位置のわからない店のページ',
    home: const VisitDetailScreen(visitId: 'vc'),
    tab: null,
    checkin: null,
    visit: (tester, audit) async {
      await audit('ページ');
      await _reveal(tester, find.text(ja.shopLocate));
      await tester.tap(find.text(ja.shopLocate));
      await _settle(tester);
      await audit('店名で探す窓');
    },
  ),
  (
    name: '撤退した1杯の店のページ',
    home: const VisitDetailScreen(visitId: 'v3'),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '編集画面',
    home: VisitEditScreen(
      entry: VisitWithShop(
        shop: _shopA,
        visit: buildVisit(
          id: 'v0',
          shopId: 'a',
          eatenAt: DateTime(2026, 10, 4),
        ),
      ),
    ),
    tab: null,
    checkin: null,
    visit: (tester, audit) async {
      await audit('編集');
      await _reveal(tester, find.text(ja.editShopRepick));
      await tester.tap(find.text(ja.editShopRepick));
      await _settle(tester);
      await audit('店を選び直す窓');
    },
  ),
  (
    name: '共有カード',
    home: const ShareScreen(visitId: 'v0'),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '設定',
    home: const SettingsScreen(),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: 'バックアップ',
    home: const BackupScreen(),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '出典・ライセンス',
    home: const CreditsScreen(),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '修行録',
    home: const ShugyorokuScreen(),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '昇段の記録',
    home: const RankHistoryScreen(),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '年の振り返りの一覧',
    home: const YearReviewListScreen(),
    tab: null,
    checkin: null,
    visit: null,
  ),
  (
    name: '年の振り返り',
    home: const YearReviewScreen(year: 2026),
    tab: null,
    checkin: null,
    visit: (tester, audit) async {
      final pages = find.byType(PageView);
      for (var page = 0; page < 20; page++) {
        await audit('${page + 1}枚目');
        final controller = tester.widget<PageView>(pages).controller!;
        final before = controller.page;
        await tester.fling(pages, const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        if (controller.page == before) break;
      }
    },
  ),
  (
    name: '拠点を選ぶ画面',
    home: const HomeBasePickerScreen(),
    tab: null,
    checkin: null,
    visit: (tester, audit) async {
      await audit('地図');
      await tester.tap(find.text(ja.homeBaseHistoryTitle));
      await _settle(tester);
      await audit('これまでの拠点の窓');
    },
  ),
  (
    name: '店の場所を指す画面',
    home: const LocationPickerScreen(shopName: '麺屋北'),
    tab: null,
    checkin: null,
    visit: (tester, audit) => audit('地図'),
  ),
  (
    name: 'はじめの案内',
    home: const OnboardingScreen(),
    tab: null,
    checkin: null,
    visit: (tester, audit) async {
      for (final next in [
        ja.onboardingNext,
        // この監査では拠点が決まっているので、其の二も「先へ進む」になる。
        ja.onboardingNext,
        null,
      ]) {
        await audit('${next ?? '終わり'}の前');
        if (next == null) break;
        await _reveal(tester, find.text(next));
        await tester.tap(find.text(next));
        await _settle(tester);
      }
    },
  ),
];

void main() {
  for (final device in _devices) {
    group(device.name, () {
      for (final screen in _screens) {
        testWidgets(screen.name, (tester) async {
          await _pump(tester, device, screen);
          Future<void> audit(String where) =>
              _expectClearOfSystemBar(tester, '${screen.name}／$where');
          final visit = screen.visit;
          if (visit == null) {
            await audit('最初');
          } else {
            await visit(tester, audit);
          }
        });
      }
    });
  }
}

Future<void> _pump(WidgetTester tester, _Device device, _Screen screen) async {
  const ratio = 3.0;
  tester.view.devicePixelRatio = ratio;
  tester.view.physicalSize = const Size(393 * ratio, 852 * ratio);
  final padding = FakeViewPadding(
    top: device.top * ratio,
    bottom: device.bottom * ratio,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);

  final database = createTestDatabase();
  final documents = createTempDirectory();
  final location = FakeLocationService(position: const GeoPoint(35.0, 139.0));
  final finder = FakeShopFinder(shops: _found);
  final visits = _visits();
  final tab = screen.tab;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        visitsProvider.overrideWithValue(AsyncData(visits)),
        homeBaseSettingsProvider.overrideWithValue(
          AsyncData([
            buildHomeBase(name: '横浜駅', setAt: DateTime(2026)),
            buildHomeBase(name: '札幌市', setAt: DateTime(2025)),
          ]),
        ),
        wishesProvider.overrideWithValue(AsyncData(_wishes)),
        activeCheckinProvider.overrideWithValue(AsyncData(screen.checkin)),
        documentsDirectoryProvider.overrideWithValue(documents),
        recordRepositoryProvider.overrideWithValue(_Repository()),
        wishRepositoryProvider.overrideWithValue(FakeWishRepository()),
        photoPickerProvider.overrideWithValue(FakePhotoPicker()),
        photoMetadataReaderProvider.overrideWithValue(
          FakePhotoMetadataReader(),
        ),
        recordDraftStoreProvider.overrideWithValue(MemoryRecordDraftStore()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        locationServiceProvider.overrideWithValue(location),
        nearbyShopFinderProvider.overrideWithValue(finder),
        shopSearchServiceProvider.overrideWithValue(
          FakeShopSearchService(
            const ShopSearchResult(
              here: GeoPoint(35.0, 139.0),
              candidates: [
                ShopCandidate(
                  shopId: 'a',
                  name: '麺屋テスト',
                  location: GeoPoint(35.0, 139.0),
                  distanceMeters: 10,
                ),
                ShopCandidate(
                  osmId: 'node/2',
                  name: 'らーめん二号',
                  location: GeoPoint(35.0005, 139.0),
                  distanceMeters: 55,
                ),
                ShopCandidate(
                  osmId: 'node/3',
                  name: '中華そば三号',
                  location: GeoPoint(35.002, 139.0),
                  distanceMeters: 220,
                ),
              ],
            ),
          ),
        ),
        mapTilesEnabledProvider.overrideWithValue(false),
        ramenInChoApiProvider.overrideWithValue(_Api()),
        showOnboardingOnLaunchProvider.overrideWithValue(false),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: tab == null
          ? localizedApp(home: screen.home!, theme: buildAppTheme())
          : const RamenInChoApp(),
    ),
  );
  await _settle(tester);
  if (tab != null) {
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(appTabProvider.notifier)
        .select(tab);
    await _settle(tester);
  }
}

/// いちばん上の画面のスクロールを上から順に送り、[finder] が見えるところまで出す。
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  List<ScrollPosition> positions() => [
    for (final state in tester.stateList<ScrollableState>(
      find.byType(Scrollable),
    ))
      if (state.position.axis == Axis.vertical && _isOnTopRoute(state.context))
        state.position,
  ];
  for (final position in positions()) {
    position.jumpTo(position.minScrollExtent);
  }
  await tester.pump();
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    for (final position in positions()) {
      position.jumpTo(
        (position.pixels + 300).clamp(0, position.maxScrollExtent),
      );
    }
    await tester.pump();
  }
  await tester.ensureVisible(finder);
  await _settle(tester);
}

/// 一覧の月の見出しのように、止まってから時間で消えるものがあるので、少し時間を進めてから落ち着かせる。
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

/// いちばん上の画面のスクロールをすべて下端まで送り、押せるものと文字が、
/// 端末の下の帯から [_margin] 以上離れているか、真ん中の判子に隠れていないかを確かめる。
Future<void> _expectClearOfSystemBar(WidgetTester tester, String where) async {
  // 長い一覧は下へ送るほど先が作られて伸びるので、伸びなくなるまで送る。
  for (var round = 0; round < 50; round++) {
    var moved = false;
    for (final state in tester.stateList<ScrollableState>(
      find.byType(Scrollable),
    )) {
      final position = state.position;
      if (position.axis != Axis.vertical ||
          !_isOnTopRoute(state.context) ||
          position.pixels >= position.maxScrollExtent) {
        continue;
      }
      position.jumpTo(position.maxScrollExtent);
      moved = true;
    }
    await tester.pump();
    if (!moved) break;
  }
  await _settle(tester);

  final view = tester.view;
  final height = view.physicalSize.height / view.devicePixelRatio;
  final limit = height - view.padding.bottom / view.devicePixelRatio - _margin;

  final seal = find.byType(RecordSealButton);
  final sealRect = seal.evaluate().isEmpty ? null : tester.getRect(seal);

  final problems = <String>[];
  var checked = 0;
  final targets = find.byWidgetPredicate(
    (widget) =>
        // 押せないあいだのボタンも、押せるようになれば同じ場所に出るので確かめる。
        widget is InkResponse ||
        (widget is GestureDetector && widget.onTap != null) ||
        widget is RichText ||
        widget is EditableText,
  );
  for (final element in targets.evaluate()) {
    if (!_isOnTopRoute(element) || _isInside<NavigationBar>(element)) continue;
    // InkWell の中の GestureDetector は、InkWell と同じものなので数えない。
    if (element.widget is GestureDetector && _isInside<InkResponse>(element)) {
      continue;
    }
    if (sealRect != null && _isInside<RecordSealButton>(element)) continue;
    final rect = _visibleRect(element);
    if (rect == null || rect.isEmpty || rect.top >= height) continue;
    if (rect.height < 1 || rect.width < 1) continue;
    checked++;
    final label = _describe(element);
    if (rect.bottom > limit) {
      problems.add(
        '$label: 下端 ${rect.bottom.toStringAsFixed(1)}'
        '（端末の下の帯から ${_margin.toInt()} 空けるなら ${limit.toStringAsFixed(1)} まで）',
      );
    } else if (sealRect != null &&
        rect.overlaps(sealRect) &&
        !_isBarrier(element)) {
      problems.add('$label: 真ん中の判子に隠れる（$rect）');
    }
  }
  expect(checked, isPositive, reason: '$where: 確かめるものが見つからない');
  expect(problems, isEmpty, reason: where);
}

bool _isBarrier(Element element) =>
    element.widget is GestureDetector &&
    (element.widget as GestureDetector).behavior == HitTestBehavior.opaque &&
    element.findRenderObject() is RenderBox &&
    (element.findRenderObject()! as RenderBox).size.height > 300;

bool _isOnTopRoute(BuildContext context) =>
    ModalRoute.of(context)?.isCurrent ?? true;

bool _isInside<T extends Widget>(Element element) {
  var found = element.widget is T;
  if (!found) {
    element.visitAncestorElements((ancestor) {
      found = ancestor.widget is T;
      return !found;
    });
  }
  return found;
}

/// 画面に見えている範囲。スクロールの外に出た部分は除く。
Rect? _visibleRect(Element element) {
  final box = element.renderObject;
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  var rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  for (RenderObject? node = box.parent; node != null; node = node.parent) {
    if (node is RenderViewportBase && node.hasSize) {
      final clip = MatrixUtils.transformRect(
        node.getTransformTo(null),
        Offset.zero & node.size,
      );
      rect = rect.intersect(clip);
    }
  }
  return rect;
}

String _describe(Element element) {
  final widget = element.widget;
  if (widget is RichText) return '文字「${widget.text.toPlainText()}」';
  final texts = <String>[];
  void collect(Element e) {
    if (e.widget is RichText) {
      texts.add((e.widget as RichText).text.toPlainText());
    }
    e.visitChildElements(collect);
  }

  element.visitChildElements(collect);
  final tooltip = element.findAncestorWidgetOfExactType<Tooltip>()?.message;
  return '${widget.runtimeType}'
      '「${texts.isNotEmpty ? texts.join(' ') : tooltip ?? ''}」';
}

class _Repository extends FakeRecordRepository {
  @override
  Future<Checkin?> activeCheckin() async => null;

  @override
  Future<List<Shop>> allShops() async => const [];
}

/// 店名で探すと、窓に収まらないほどの店が見つかる。
class _Api implements RamenInChoApi {
  @override
  Future<List<FoundShop>> searchByName(
    String name, {
    GeoPoint? near,
    Duration timeout = RamenInChoApi.timeout,
  }) async => [
    for (var i = 0; i < 20; i++)
      FoundShop(
        name: '$name $i号店',
        location: GeoPoint(35 + i / 100, 139),
        address: '横浜市$i丁目',
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
