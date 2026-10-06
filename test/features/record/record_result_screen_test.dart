import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';
import 'package:ramen_in_cho/features/journal/journal.dart';
import 'package:ramen_in_cho/features/notifications/notification_service.dart';
import 'package:ramen_in_cho/features/prefecture/prefectures.dart';
import 'package:ramen_in_cho/features/record/record_result_screen.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/words/words.dart';
import 'package:ramen_in_cho/theme/washi.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  DateTime day(int d) => DateTime(2026, 9, d, 12);
  final prefectures = PrefectureIndex.fromJson(
    File(prefecturesAsset).readAsStringSync(),
  );
  late FakeNotificationService notifications;

  setUp(() => notifications = FakeNotificationService());

  Future<void> pumpResult(
    WidgetTester tester,
    List<VisitWithShop> visits,
    String visitId, {
    List<Wish> wishes = const [],
    bool settle = true,
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
          prefectureIndexProvider.overrideWithValue(prefectures),
        ],
        child: localizedApp(home: RecordResultScreen(visitId: visitId)),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  bool isPlainText(Widget widget, String text) =>
      widget is Text && widget.data == text;

  testWidgets('得たポイントの内訳と、累計・次のランクまでを表示する', (tester) async {
    final famous = buildShop(
      id: 'famous',
      name: '新宿の名店',
      isFamous: true,
      latitude: 35.6896,
      longitude: 139.7006,
      area: '新宿区',
    );
    // 10 + 待ち 15 + 限定 20 + 初訪問 10 + 初めての都道府県 30 + 初めての市区町村 10 + 名店 15 = 110
    final entry = buildEntry(
      shop: famous,
      eatenAt: day(1),
      waitMinutes: 35,
      isLimited: true,
    );
    await pumpResult(tester, [entry], entry.visit.id);

    expect(
      find.byWidgetPredicate(
        (widget) => widget is VerticalText && widget.text == '新宿の名店',
      ),
      findsOneWidget,
    );
    expect(find.byType(InkanStamp), findsOneWidget);
    expect(find.text(ja.pointsGained(110)), findsOneWidget);
    expect(find.text(ja.pointsBase), findsOneWidget);
    expect(find.text(ja.pointsWait(35)), findsOneWidget);
    // 待ち時間と名店が、どちらも +15。
    expect(find.text(ja.pointsGained(15)), findsNWidgets(2));
    expect(find.text(ja.isLimited), findsOneWidget);
    expect(find.text(ja.pointsFirstVisit), findsOneWidget);
    expect(find.text(ja.pointsNewPrefecture('東京都')), findsOneWidget);
    expect(find.text(ja.pointsGained(30)), findsOneWidget);
    expect(find.text(ja.pointsNewArea('新宿区')), findsOneWidget);
    expect(find.text(ja.pointsFamous), findsOneWidget);
    // 0点の項目は出さない。
    expect(find.text(ja.pointsRegular(1)), findsNothing);
    expect(find.text(ja.pointsStreak(1)), findsNothing);

    expect(find.text(ja.pointsRetry), findsNothing);

    // 110点は四級（65）を越えるが、1杯で上がるのは五級だけ。
    expect(find.text(ja.rankUpKyu), findsOneWidget);
    expect(find.text(ja.rankKyu('五')), findsWidgets);
    expect(find.text(masterWords(AdventurerRank.kyu5)), findsOneWidget);

    // スポット「はじめての着丼」の達成と、常設の Lv.1 到達
    // （35分待ち・限定・1杯で60点以上のSランク）を知らせる。
    // 名店の印の店なので、秘伝「名店の暖簾」も会得する。
    expect(find.text(ja.questAchieved), findsNWidgets(2));
    expect(find.text('はじめての着丼'), findsOneWidget);
    expect(find.text('名店の暖簾'), findsOneWidget);
    expect(find.text(ja.questLevelUp), findsNWidgets(3));
    expect(find.text(ja.questLevelReached('行列の覇者', '一')), findsOneWidget);
    expect(find.text(ja.questLevelReached('限定ハンター', '一')), findsOneWidget);
    expect(find.text(ja.questLevelReached('大物討伐', '一')), findsOneWidget);

    // 連続記録のお知らせのため、記録したときに通知の許可を尋ねる。
    expect(notifications.permissionRequests, 1);
  });

  testWidgets('ランクが上がったら知らせる', (tester) async {
    final rare = buildShop(id: 'rare', isFamous: true);
    // 10 + 初訪問 10 + 限定 20 + 待ち 50 + 名店 15 = 105
    final big = buildEntry(
      shop: rare,
      eatenAt: day(1),
      isLimited: true,
      waitMinutes: 100,
    );
    // 10 + 20 + 10 = 40 → 累計 145
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
    final rare = buildShop(id: 'rare', isFamous: true);
    // 1杯ごとに 10 + 限定 20 + 待ち 50 + 名店 15 = 95。初訪問・連続記録・常連も足して、
    // 36杯目で 3530 になり、免許皆伝（3510）に届く。
    final entries = [
      for (var d = 1; d <= 36; d++)
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
    // 願に朱の「叶」の印を押す。
    expect(find.text(ja.wishFulfilledSealChar), findsOneWidget);
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

  testWidgets('最後に、この一杯の道中記を出す（店のページと同じ文）', (tester) async {
    final shop = buildShop(id: 'shop', name: 'はやし田');
    final first = buildEntry(shop: shop, eatenAt: day(1));
    final second = buildEntry(shop: shop, eatenAt: day(8), waitMinutes: 40);
    await pumpResult(tester, [second, first], second.visit.id);

    final lines = buildJournal(
      scoreVisits([second, first])
          .firstWhere((e) => e.visit.id == second.visit.id),
      scoreVisits([second, first]),
    );
    expect(lines, isNotEmpty);
    expect(find.text(ja.journalTitle), findsOneWidget);
    for (final line in lines) {
      expect(find.text(line), findsOneWidget);
    }
  });

  testWidgets('どこかをタップすると、演出を飛ばして最後の状態になる', (tester) async {
    // 10 + 20 + 10 = 40
    final entry = buildEntry(eatenAt: day(1), isLimited: true);
    await pumpResult(tester, [entry], entry.visit.id, settle: false);
    await tester.pump(const Duration(milliseconds: 50));
    // 師匠のひとことは、段位が上がってから筆で書く。
    expect(
      find.byWidgetPredicate(
        (w) => isPlainText(w, masterWords(AdventurerRank.kyu5)),
      ),
      findsNothing,
    );

    await tester.tap(find.text(ja.pointsBase));
    await tester.pump();

    expect(find.text(ja.pointsGained(40)), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) => isPlainText(w, masterWords(AdventurerRank.kyu5)),
      ),
      findsOneWidget,
    );
    expect(find.text(ja.journalTitle), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('「動きを減らす」なら、はじめから最後の状態を見せる', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final entry = buildEntry(eatenAt: day(1));
    await pumpResult(tester, [entry], entry.visit.id, settle: false);
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (w) => isPlainText(w, masterWords(AdventurerRank.kyu5)),
      ),
      findsOneWidget,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('演出の途中でも「印帳にもどる」で戻れる', (tester) async {
    final entry = buildEntry(eatenAt: day(1));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData([entry])),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: localizedApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecordResultScreen(visitId: entry.visit.id),
                ),
              ),
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    // 画面が開くまで（演出はまだ途中）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);
    expect(find.byType(RecordResultScreen), findsOneWidget);

    await tester.tap(find.text(ja.resultOk));
    await tester.pumpAndSettle();
    expect(find.byType(RecordResultScreen), findsNothing);
  });
}
