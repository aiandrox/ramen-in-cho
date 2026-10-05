import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/inkan/inkan_stamp.dart';

import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/review/year_review_entry.dart';
import 'package:ramen_in_cho/features/review/year_review_list_screen.dart';
import 'package:ramen_in_cho/features/review/year_review_screen.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/words/words.dart';

import '../../support/builders.dart';
import '../../support/l10n.dart';

void main() {
  final shop = buildShop(id: 'a', name: '麺屋あさひ');
  final visits = [
    buildEntry(shop: shop, eatenAt: DateTime(2025, 5, 1, 12)),
    buildEntry(
      shop: shop,
      eatenAt: DateTime(2026, 3, 5, 12),
      style: RamenStyle.shoyu,
    ),
    buildEntry(
      shop: shop,
      eatenAt: DateTime(2026, 4, 1, 12),
      result: VisitResult.retreated,
    ),
  ];

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    DateTime? now,
    List<VisitWithShop>? entries,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData(entries ?? visits)),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          clockProvider.overrideWithValue(() => now ?? DateTime(2026, 10, 3)),
        ],
        child: localizedApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('表紙から締めのひとことまで、横にめくって見られる', (tester) async {
    await pump(tester, const YearReviewScreen(year: 2026));

    expect(find.text(ja.reviewCoverEra('令和', '八')), findsOneWidget);
    expect(find.textContaining('（'), findsNothing);
    expect(find.text(ja.reviewCoverYear(2026)), findsWidgets);
    expect(find.text(ja.reviewCoverHint), findsOneWidget);

    await next(tester);
    expect(find.text(ja.reviewCountsTitle), findsOneWidget);
    // この一年の1杯の印を押し終えてから、数字を出す。
    expect(find.byType(InkanStamp), findsOneWidget);
    expect(find.text(ja.bowls(1)), findsOneWidget);
    expect(find.text(ja.reviewRetreatCount(1)), findsOneWidget);

    // 2杯以上の店も、並んだ記録も無いので、その2枚は飛ばす。
    await next(tester);
    expect(find.text(ja.reviewBestTitle), findsOneWidget);
    expect(find.text('麺屋あさひ'), findsOneWidget);

    await next(tester);
    expect(find.text(ja.statsStyles), findsOneWidget);

    await next(tester);
    expect(find.text(ja.reviewMonthlyTitle), findsOneWidget);

    // 段位も型も届いていないので、成果の1枚は飛ばす。
    await next(tester);
    expect(find.text(ja.reviewClosingTitle), findsOneWidget);
    expect(find.text(yearClosingWords(2026)), findsOneWidget);
    expect(find.text(ja.shareButton), findsOneWidget);
  });

  group('めくったときの動き', () {
    Future<void> turn(WidgetTester tester) async {
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pump();
    }

    testWidgets('数字は初めて見えたときに数え上げ、触れると動き終えた姿にする', (tester) async {
      await pump(tester, const YearReviewScreen(year: 2026));

      await turn(tester);
      // めくり終えるまで待つ（めくっている間は、紙に触れても届かない）。
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      while (pages.page! != pages.page!.roundToDouble()) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text(ja.reviewCountsTitle), findsOneWidget);
      expect(find.text(ja.bowls(1)), findsNothing);

      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pump();
      expect(find.text(ja.bowls(1)), findsOneWidget);
      await tester.pumpAndSettle();

      // めくって戻ってきたときは、もう動かさない。
      await turn(tester);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await tester.pump();
      expect(find.text(ja.bowls(1)), findsOneWidget);
    });

    testWidgets('動きを減らす設定では、初めから動き終えた姿を見せる', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester, const YearReviewScreen(year: 2026));

      await turn(tester);
      expect(find.text(ja.bowls(1)), findsOneWidget);
      expect(find.byType(InkanStamp), findsOneWidget);
    });
  });

  testWidgets('表紙には年の切り替えを出さない', (tester) async {
    await pump(tester, const YearReviewScreen(year: 2026));

    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('記録の無い年は表紙だけ', (tester) async {
    await pump(tester, const YearReviewScreen(year: 2024));

    expect(find.text(ja.reviewCoverEmpty), findsOneWidget);
    await next(tester);
    expect(find.text(ja.reviewCoverEmpty), findsOneWidget);
  });

  testWidgets('修行タブの入口は年の一覧を開き、選んだ年をめくって、戻ると一覧に戻る', (tester) async {
    await pump(
      tester,
      Scaffold(body: ListView(children: const [YearReviewEntry()])),
    );

    await tester.tap(find.text(ja.reviewListTitle));
    await tester.pumpAndSettle();

    // 記録のある年だけを新しい順に、杯数・軒数・修行点を添えて並べる。
    final years = find.descendant(
      of: find.byType(YearReviewListScreen),
      matching: find.byType(ListTile),
    );
    expect(years, findsNWidgets(2));
    expect(
      find.descendant(
        of: years.first,
        matching: find.text(ja.reviewEntry(2026)),
      ),
      findsOneWidget,
    );
    expect(find.text(ja.reviewEntry(2025)), findsOneWidget);
    expect(find.textContaining('1杯・1軒・'), findsNWidgets(2));

    await tester.tap(find.text(ja.reviewEntry(2025)));
    await tester.pumpAndSettle();
    expect(find.text(ja.reviewCoverEra('令和', '七')), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(YearReviewScreen), findsNothing);
    expect(find.byType(YearReviewListScreen), findsOneWidget);

    await tester.tap(find.text(ja.reviewEntry(2026)));
    await tester.pumpAndSettle();
    expect(find.text(ja.reviewCoverEra('令和', '八')), findsOneWidget);
  });

  testWidgets('記録が無いうちは、修行タブに入口を出さない', (tester) async {
    await pump(
      tester,
      Scaffold(body: ListView(children: const [YearReviewEntry()])),
      entries: const [],
    );

    expect(find.byType(ListTile), findsNothing);
  });

  group('一覧の上の案内', () {
    Widget card() =>
        Scaffold(body: ListView(children: const [YearReviewInviteCard()]));

    testWidgets('12月はその年の振り返りを勧める', (tester) async {
      await pump(tester, card(), now: DateTime(2026, 12, 1));

      expect(find.text(ja.reviewInvite(2026)), findsOneWidget);

      await tester.tap(find.byTooltip(ja.reviewDismiss));
      await tester.pumpAndSettle();
      expect(find.text(ja.reviewInvite(2026)), findsNothing);
    });

    testWidgets('1月は前の年の振り返りを勧める', (tester) async {
      await pump(tester, card(), now: DateTime(2027, 1, 31));

      expect(find.text(ja.reviewInvite(2026)), findsOneWidget);
    });

    testWidgets('案内からはその年をめくり、戻ると年の一覧に戻る', (tester) async {
      await pump(tester, card(), now: DateTime(2026, 12, 1));

      await tester.tap(find.text(ja.reviewInvite(2026)));
      await tester.pumpAndSettle();
      expect(find.text(ja.reviewCoverEra('令和', '八')), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(YearReviewListScreen), findsOneWidget);
    });

    testWidgets('12月・1月のほかには出さない', (tester) async {
      await pump(tester, card(), now: DateTime(2026, 11, 30));

      expect(find.byType(Card), findsNothing);
    });

    testWidgets('記録の無い年には出さない', (tester) async {
      await pump(tester, card(), now: DateTime(2028, 1, 10));

      expect(find.byType(Card), findsNothing);
    });
  });
}
