import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';
import 'package:ramen_in_cho/features/notifications/notification_service.dart';
import 'package:ramen_in_cho/features/record/record_result_screen.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/words/words.dart';
import 'package:ramen_in_cho/theme/washi.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  DateTime day(int d) => DateTime(2026, 9, d, 12);
  late FakeNotificationService notifications;

  setUp(() => notifications = FakeNotificationService());

  Future<void> pumpResult(
    WidgetTester tester,
    List<VisitWithShop> visits,
    String visitId, {
    List<Wish> wishes = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(visits)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(AsyncData(wishes)),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: localizedApp(home: RecordResultScreen(visitId: visitId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('得たポイントの内訳と、累計・次のランクまでを表示する', (tester) async {
    final lunch = buildShop(
      id: 'lunch',
      name: '不定休の店',
      hoursConditions: {HoursCondition.irregular},
    );
    // (10 + 15 + 20 + 10) × 1.5 = 82.5 → 82
    final entry = buildEntry(
      shop: lunch,
      eatenAt: day(1),
      waitMinutes: 35,
      isLimited: true,
    );
    await pumpResult(tester, [entry], entry.visit.id);

    expect(
      find.byWidgetPredicate(
        (widget) => widget is VerticalText && widget.text == '不定休の店',
      ),
      findsOneWidget,
    );
    expect(find.byType(InkanStamp), findsOneWidget);
    expect(find.text(ja.pointsGained(82)), findsOneWidget);
    expect(find.text(ja.pointsBase), findsOneWidget);
    expect(find.text(ja.pointsWait(35)), findsOneWidget);
    expect(find.text(ja.pointsGained(15)), findsOneWidget);
    expect(find.text(ja.isLimited), findsOneWidget);
    expect(find.text(ja.pointsFirstVisit), findsOneWidget);
    expect(find.text(ja.pointsHours(ja.hoursIrregular)), findsOneWidget);
    expect(find.text(ja.pointsMultiplier('1.5')), findsOneWidget);
    // 0点の項目は出さない。

    expect(find.text(ja.pointsRetry), findsNothing);

    // 82点は三級（70）まで届くが、1杯で上がるのは五級だけ。
    expect(find.text(ja.rankUpKyu), findsOneWidget);
    expect(find.text(ja.rankKyu('五')), findsWidgets);
    expect(find.text(masterWords(AdventurerRank.kyu5)), findsOneWidget);

    // スポット「はじめての着丼」の達成と、常設の Lv.1 到達
    // （35分待ち・限定・1杯で60点以上のSランク）を知らせる。
    expect(find.text(ja.questAchieved), findsOneWidget);
    expect(find.text('はじめての着丼'), findsOneWidget);
    expect(find.text(ja.questLevelUp), findsNWidgets(3));
    expect(find.text(ja.questLevelReached('行列の覇者', '一')), findsOneWidget);
    expect(find.text(ja.questLevelReached('限定ハンター', '一')), findsOneWidget);
    expect(find.text(ja.questLevelReached('大物討伐', '一')), findsOneWidget);

    // 連続記録のお知らせのため、記録したときに通知の許可を尋ねる。
    expect(notifications.permissionRequests, 1);
  });

  testWidgets('ランクが上がったら知らせる', (tester) async {
    final rare = buildShop(
      id: 'rare',
      hoursConditions: {HoursCondition.weekdaysOnly, HoursCondition.fewDays},
    );
    // (10 + 10 + 20 + 50) × 2 = 180
    final big = buildEntry(
      shop: rare,
      eatenAt: day(1),
      isLimited: true,
      waitMinutes: 100,
    );
    // 10 + 20 + 10 = 40 → 累計 220
    final reaches = buildEntry(
      shop: buildShop(id: 'shop'),
      eatenAt: day(2),
      isLimited: true,
    );
    await pumpResult(tester, [reaches, big], reaches.visit.id);

    // 1杯目で五級、2杯目で四級に1つだけ上がる。
    expect(find.text(ja.rankUpKyu), findsOneWidget);
    expect(find.text(ja.rankKyu('四')), findsOneWidget);
  });

  testWidgets('最高ランクでは、次のランクの代わりに到達を表示する', (tester) async {
    final rare = buildShop(
      id: 'rare',
      hoursConditions: {HoursCondition.weekdaysOnly, HoursCondition.fewDays},
    );
    // 1杯目 180、以降 (10 + 20 + 50) × 2 = 160 ずつ。22杯目で 3540 になり、免許皆伝（3510）に届く
    final entries = [
      for (var d = 1; d <= 22; d++)
        buildEntry(
          shop: rare,
          eatenAt: day(d),
          isLimited: true,
          waitMinutes: 100,
        ),
    ];
    await pumpResult(tester, entries, entries.last.visit.id);

    // この1杯で最高ランクに上がるため、お知らせとランク表示の両方に出る。
    expect(find.text(ja.rankGrandmaster), findsOneWidget);
  });

  testWidgets('記録がまだ読み込まれていなければ待つ', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(const AsyncData([])),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: localizedApp(home: const RecordResultScreen(visitId: 'v')),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(ja.resultOk), findsOneWidget);
  });

  testWidgets('願を掛けた店で食べたら「願成就」と日数・きっかけを出す', (tester) async {
    final shop = buildShop(id: 'shop', name: 'はやし田');
    final entry = buildEntry(shop: shop, eatenAt: day(30));
    await pumpResult(
      tester,
      [entry],
      entry.visit.id,
      wishes: [
        Wish(
          id: 'wish',
          shopId: 'shop',
          name: 'はやし田',
          trigger: '同僚に聞いた',
          createdAt: day(1),
          fulfilledVisitId: entry.visit.id,
        ),
      ],
    );

    expect(find.text(ja.wishFulfilled), findsOneWidget);
    expect(find.text(ja.wishFulfilledAfter('二十九')), findsOneWidget);
    expect(find.text(ja.wishTriggerLine('同僚に聞いた')), findsOneWidget);
  });

  testWidgets('願を掛けていない店では「願成就」を出さない', (tester) async {
    final entry = buildEntry(eatenAt: day(30));
    await pumpResult(tester, [entry], entry.visit.id);

    expect(find.text(ja.wishFulfilled), findsNothing);
  });

  testWidgets('下に固定した「共有する」から、この一杯の共有の画面を開ける', (tester) async {
    final entry = buildEntry(eatenAt: day(1));
    await pumpResult(tester, [entry], entry.visit.id);

    expect(find.text(ja.resultOk), findsOneWidget);
    await tester.tap(find.text(ja.resultShare));
    await tester.pumpAndSettle();

    expect(find.text(ja.shareTitle), findsOneWidget);
    expect(find.text(ja.shareButton), findsOneWidget);
  });
}
