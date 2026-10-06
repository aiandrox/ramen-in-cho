import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/checkin/checkin_banner.dart';
import 'package:ramen_in_cho/features/checkin/checkin_controller.dart';
import 'package:ramen_in_cho/features/checkin/checkin_screen.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/record/photo_metadata.dart';
import 'package:ramen_in_cho/features/record/record_draft.dart';
import 'package:ramen_in_cho/features/record/record_screen.dart';
import 'package:ramen_in_cho/theme/washi_buttons.dart';
import 'package:ramen_in_cho/features/map/map_screen.dart';
import 'package:ramen_in_cho/features/notifications/notification_service.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_store.dart';
import 'package:ramen_in_cho/features/record/photo_picker.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/settings/settings_screen.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';
import 'package:ramen_in_cho/main.dart';
import 'package:ramen_in_cho/theme/washi.dart';

import 'support/fakes.dart';
import 'support/l10n.dart';

Finder verticalText(String text) => find.byWidgetPredicate(
  (widget) => widget is VerticalText && widget.text == text,
);

void main() {
  late FakeNotificationService notifications;

  setUp(() => notifications = FakeNotificationService());

  Future<void> pumpApp(
    WidgetTester tester,
    List<VisitWithShop> visits, {
    DateTime? now,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(visits)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          activeCheckinProvider.overrideWithValue(const AsyncData(null)),
          documentsDirectoryProvider.overrideWithValue(createTempDirectory()),
          photoPickerProvider.overrideWithValue(FakePhotoPicker()),
          notificationServiceProvider.overrideWithValue(notifications),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          showOnboardingOnLaunchProvider.overrideWithValue(false),
          if (now != null) clockProvider.overrideWithValue(() => now),
        ],
        child: const RamenInChoApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('記録が無いときは最初の記録を促す', (tester) async {
    await pumpApp(tester, const []);

    expect(find.text(ja.appName), findsOneWidget);
    expect(find.text(ja.homeEmpty), findsOneWidget);
    expect(find.byTooltip(ja.addRecord), findsOneWidget);
  });

  testWidgets('通知が出ても、真ん中の判子は動かず、通知は判子の上に出る', (tester) async {
    await pumpApp(tester, const []);
    final seal = find.byType(RecordSealButton);
    final before = tester.getRect(seal);

    ScaffoldMessenger.of(tester.element(seal))
        .showSnackBar(const SnackBar(content: Text('お知らせ')));
    await tester.pumpAndSettle();

    expect(tester.getRect(seal), before);
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(before.top),
    );
  });

  testWidgets('下のタブで修行・地図に切り替えられる。地図は開いたときだけ作る', (tester) async {
    await pumpApp(tester, const []);

    await tester.tap(find.text(ja.navShugyo));
    await tester.pumpAndSettle();

    expect(find.text(ja.questStanding), findsOneWidget);
    expect(find.text('着丼の道'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(ja.statsEmpty), 300);
    expect(find.text(ja.statsEmpty), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);

    await tester.tap(find.byTooltip(ja.settingsSection));
    await tester.pumpAndSettle();
    expect(find.text(ja.backupTitle), findsOneWidget);
    expect(find.text(ja.onboardingReplay), findsOneWidget);
    expect(find.text(ja.creditsTitle), findsOneWidget);
    Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text(ja.navMap));
    await tester.pumpAndSettle();

    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.text(ja.mapEmpty), findsOneWidget);
  });

  testWidgets('記録があるときは店名と印、段位と修行点を表示する', (tester) async {
    final shop = Shop(
      id: 'shop',
      name: '麺屋テスト',
      createdAt: DateTime(2026, 9, 30),
    );
    await pumpApp(tester, [
      VisitWithShop(
        shop: shop,
        visit: Visit(
          id: 'visit',
          shopId: 'shop',
          result: VisitResult.eaten,
          eatenAt: DateTime(2026, 9, 30, 12, 34),
          rating: 4,
          isLimited: false,
          hasTicket: false,
          memo: '',
          createdAt: DateTime(2026, 9, 30, 12, 40),
        ),
      ),
    ]);

    expect(verticalText('麺屋テスト'), findsOneWidget);

    expect(find.byType(InkanStamp), findsOneWidget);
    expect(find.text(ja.rankKyu('五')), findsOneWidget);
    expect(find.text(ja.totalPoints(20)), findsOneWidget);
    expect(find.text(ja.homeEmpty), findsNothing);
  });

  testWidgets('食べてから12時間以内で★の無い記録は、一覧の上で評価を促す', (tester) async {
    final shop = Shop(
      id: 'shop',
      name: '麺屋テスト',
      createdAt: DateTime(2026, 9, 30),
    );
    Visit visit(String id, DateTime eatenAt) => Visit(
      id: id,
      shopId: 'shop',
      result: VisitResult.eaten,
      eatenAt: eatenAt,
      isLimited: false,
      hasTicket: false,
      memo: '',
      createdAt: eatenAt,
    );
    final now = DateTime.now();
    await pumpApp(tester, [
      VisitWithShop(
        shop: shop,
        visit: visit('recent', now.subtract(const Duration(hours: 1))),
      ),
    ]);

    expect(find.text(ja.ratingPrompt('麺屋テスト')), findsOneWidget);

    await pumpApp(tester, [
      VisitWithShop(
        shop: shop,
        visit: visit('old', now.subtract(const Duration(hours: 13))),
      ),
    ]);

    expect(find.text(ja.ratingPrompt('麺屋テスト')), findsNothing);
  });

  testWidgets('並んでいる間だけ通知を出し、並び終えたら消す', (tester) async {
    final checkins = StreamController<Checkin?>();
    addTearDown(checkins.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(const AsyncData([])),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          activeCheckinProvider.overrideWith((ref) => checkins.stream),
          documentsDirectoryProvider.overrideWithValue(createTempDirectory()),
          photoPickerProvider.overrideWithValue(FakePhotoPicker()),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: const RamenInChoApp(),
      ),
    );

    // 起動時に並んでいなければ、前回の通知が残っていないよう消す。
    checkins.add(null);
    await tester.pumpAndSettle();
    expect(notifications.shown, isEmpty);
    expect(notifications.cancelCount, 1);

    checkins.add(
      Checkin(name: '麺屋テスト', checkedInAt: DateTime(2026, 10, 1, 11)),
    );
    await tester.pumpAndSettle();
    expect(notifications.shown, [ja.checkinBanner('麺屋テスト')]);

    checkins.add(null);
    await tester.pumpAndSettle();
    expect(notifications.cancelCount, 2);

    checkins.addError(StateError('db'));
    await tester.pumpAndSettle();
    expect(notifications.cancelCount, 3);
  });

  group('真ん中の判子', () {
    final now = DateTime(2026, 10, 5, 12);
    final checkin = Checkin(
      osmId: 'node/9',
      name: '並んだ店',
      latitude: 35.0,
      longitude: 139.0,
      checkedInAt: now.subtract(const Duration(minutes: 35)),
    );
    late FakePhotoPicker picker;

    Future<void> pumpShell(WidgetTester tester, {Checkin? queued}) async {
      final database = createTestDatabase();
      if (queued != null) {
        await tester.runAsync(
          () => RecordRepository(database).checkIn(
            shop: ShopInput(
              osmId: queued.osmId,
              name: queued.name,
              latitude: queued.latitude,
              longitude: queued.longitude,
            ),
            at: queued.checkedInAt,
          ),
        );
      }
      picker = FakePhotoPicker();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            visitsProvider.overrideWithValue(const AsyncData([])),
            homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
            wishesProvider.overrideWithValue(const AsyncData([])),
            activeCheckinProvider.overrideWithValue(AsyncData(queued)),
            documentsDirectoryProvider.overrideWithValue(createTempDirectory()),
            photoPickerProvider.overrideWithValue(picker),
            photoMetadataReaderProvider.overrideWithValue(
              FakePhotoMetadataReader(),
            ),
            recordDraftStoreProvider.overrideWithValue(
              MemoryRecordDraftStore(),
            ),
            notificationServiceProvider.overrideWithValue(notifications),
            locationServiceProvider.overrideWithValue(FakeLocationService()),
            showOnboardingOnLaunchProvider.overrideWithValue(false),
            clockProvider.overrideWithValue(() => now),
          ],
          child: const RamenInChoApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder seal(String glyph) => find.descendant(
      of: find.byType(RecordSealButton),
      matching: find.text(glyph),
    );

    testWidgets('並んでいなければ「麺」。押すと「着丼した」と「いま並んでいる」を選べる', (tester) async {
      await pumpShell(tester);

      expect(seal('麺'), findsOneWidget);
      expect(seal('着'), findsNothing);
      expect(find.byType(CheckinBanner), findsNothing);

      await tester.tap(find.byType(RecordSealButton));
      await tester.pumpAndSettle();
      expect(find.text(ja.startEatenTitle), findsOneWidget);
      expect(find.text(ja.startEatenBody), findsOneWidget);
      expect(find.text(ja.startQueueTitle), findsOneWidget);
      expect(find.text(ja.startQueueBody), findsOneWidget);

      await tester.tap(find.text(ja.startQueueTitle));
      await tester.pumpAndSettle();
      expect(find.byType(CheckinScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(CheckinScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(RecordSealButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.startEatenTitle));
      await tester.pumpAndSettle();
      expect(find.byType(RecordScreen), findsOneWidget);
      // ふだんの記録では、カメラは自動で開かない。
      expect(picker.cameraOpens, 0);
    });

    testWidgets('並んでいる間は「着」。どのタブでも上に並びの帯を出す', (tester) async {
      await pumpShell(tester, queued: checkin);

      expect(seal('着'), findsOneWidget);
      expect(seal('麺'), findsNothing);
      expect(find.byTooltip(ja.arriveSeal), findsOneWidget);
      expect(find.text(ja.arriveSealLabel), findsOneWidget);
      expect(find.text(ja.checkinBannerHint), findsOneWidget);

      await tester.tap(find.text(ja.navShugyo));
      await tester.pumpAndSettle();
      expect(find.byType(CheckinBanner), findsOneWidget);
      expect(find.text(ja.checkinBanner('並んだ店')), findsOneWidget);
    });

    testWidgets('「着」を押すとすぐカメラを開き、並んだ店と待ち時間が決まった記録画面になる', (tester) async {
      await pumpShell(tester, queued: checkin);

      await tester.tap(find.byType(RecordSealButton));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RecordScreen), findsOneWidget);
      expect(find.text(ja.startEatenTitle), findsNothing);
      expect(picker.cameraOpens, 1);
      expect(find.textContaining(ja.waitTime(35)), findsOneWidget);
      final save = find.widgetWithText(AiFuda, ja.save);
      expect(tester.widget<AiFuda>(save).onPressed, isNotNull);
    });

    testWidgets('「麺」の窓は下のタブと判子の下に出し、タブと判子は覆わない', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.byType(RecordSealButton));
      await tester.pumpAndSettle();
      expect(find.text(ja.startEatenTitle), findsOneWidget);
      final navTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
      expect(tester.getBottomLeft(find.byType(BottomSheet)).dy, navTop);
      // 見出し（タブの画面の AppBar）にもかからない。
      expect(
        tester.getTopLeft(find.byType(BottomSheet)).dy,
        greaterThanOrEqualTo(kToolbarHeight),
      );

      // 判子をもう一度押すと閉じる。
      await tester.tap(find.byType(RecordSealButton));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      // 窓の外（暗くしたところ）を押すと閉じる。
      await tester.tap(find.byType(RecordSealButton));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(400, kToolbarHeight + 16));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      // 戻る操作でも、アプリを閉じずに窓だけを閉じる。
      await tester.tap(find.byType(RecordSealButton));
      await tester.pumpAndSettle();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.navigation.name,
        SystemChannels.navigation.codec.encodeMethodCall(
          const MethodCall('popRoute'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(RecordSealButton), findsOneWidget);

      // 窓を開いたまま下のタブを押すと、窓を閉じてタブを切り替える。
      await tester.tap(find.byType(RecordSealButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ja.navShugyo));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
    });
  });

  group('連続記録', () {
    // 2026-10-01 は木曜。
    final thursday = DateTime(2026, 10, 1, 12);
    final shop = Shop(id: 'shop', name: '麺屋テスト', createdAt: DateTime(2026));
    VisitWithShop eatenAt(DateTime at) => VisitWithShop(
      shop: shop,
      visit: Visit(
        id: at.toIso8601String(),
        shopId: 'shop',
        result: VisitResult.eaten,
        eatenAt: at,
        rating: 3,
        isLimited: false,
        hasTicket: false,
        memo: '',
        createdAt: at,
      ),
    );

    testWidgets('今週まだ食べていなければ「今週はまだ」と出し、日曜18時に知らせる', (tester) async {
      await pumpApp(tester, [
        eatenAt(DateTime(2026, 9, 22, 12)),
        eatenAt(DateTime(2026, 9, 15, 12)),
      ], now: thursday);
      await tester.tap(find.text(ja.navShugyo));
      await tester.pumpAndSettle();

      expect(find.text(ja.streakWeeks(2)), findsOneWidget);
      expect(find.text(ja.streakAtRisk), findsOneWidget);
      expect(notifications.streakReminders, [DateTime(2026, 10, 4, 18)]);
    });

    testWidgets('今週すでに食べていれば、来週の日曜18時に知らせる予約をしておく', (tester) async {
      await pumpApp(tester, [
        eatenAt(DateTime(2026, 9, 30, 12)),
        eatenAt(DateTime(2026, 9, 22, 12)),
      ], now: thursday);
      await tester.tap(find.text(ja.navShugyo));
      await tester.pumpAndSettle();

      expect(find.text(ja.streakWeeks(2)), findsOneWidget);
      expect(find.text(ja.streakAtRisk), findsNothing);
      expect(notifications.streakReminders, [DateTime(2026, 10, 11, 18)]);
    });

    testWidgets('連続記録が無ければ表示せず、知らせる予約も消す', (tester) async {
      await pumpApp(tester, [eatenAt(DateTime(2026, 9, 1, 12))], now: thursday);
      await tester.tap(find.text(ja.navShugyo));
      await tester.pumpAndSettle();

      expect(find.textContaining('週連続'), findsNothing);
      expect(notifications.streakReminders, isEmpty);
      expect(notifications.streakCancelCount, greaterThan(0));
    });
  });

  testWidgets('印帳をスクロールしている間だけ、今の月を上に浮かべる', (tester) async {
    final shop = Shop(id: 'shop', name: '麺屋', createdAt: DateTime(2026));
    await pumpApp(tester, [
      for (var i = 0; i < 40; i++)
        VisitWithShop(
          shop: shop,
          visit: Visit(
            id: 'visit-$i',
            shopId: 'shop',
            result: VisitResult.eaten,
            eatenAt: DateTime(2026, 9, 30 - i ~/ 2, 12),
            isLimited: false,
            hasTicket: false,
            memo: '',
            createdAt: DateTime(2026, 9, 30 - i ~/ 2, 12),
          ),
        ),
    ]);

    final label = ja.inchoMonth('令和', '八', '九');
    expect(find.text(label), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pump();
    expect(find.text(label), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(label), findsNothing);
  });
}
