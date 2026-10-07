import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/motion.dart';
import '../../theme/safe_bottom.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';
import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';
import '../home/app_tab.dart';
import '../home_base/home_base_repository.dart';
import '../inkan/inkan.dart';
import '../inkan/inkan_stamp.dart';
import '../notifications/notification_service.dart';
import '../prefecture/prefectures.dart';
import '../records/models.dart';
import '../records/record_repository.dart';
import '../scoring/batch_outcome.dart';
import '../scoring/rank_labels.dart';
import '../wishes/wish_repository.dart';
import 'exp_bar.dart';
import 'record_result_screen.dart';

/// 何枚もの写真をまとめて記録したあとに、印を並べて杯数と合計の修行点を1回だけ見せる。
class BatchResultScreen extends ConsumerStatefulWidget {
  const BatchResultScreen({
    super.key,
    required this.visitIds,
    this.saveSummaries = const [],
  });

  final List<String> visitIds;

  /// 記録の画面で入れた様子（統計に送る）。[visitIds]と同じ順。
  final List<RecordSaveSummary> saveSummaries;

  @override
  ConsumerState<BatchResultScreen> createState() => _BatchResultScreenState();
}

class _BatchResultScreenState extends ConsumerState<BatchResultScreen> {
  BatchOutcome? _outcome;
  bool _logged = false;

  late final NotificationService _notifications;
  late final AppTabNotifier _tabs;
  late final LedgerTopRequest _ledgerTop;

  @override
  void initState() {
    super.initState();
    _notifications = ref.read(notificationServiceProvider);
    _tabs = ref.read(appTabProvider.notifier);
    _ledgerTop = ref.read(ledgerTopRequestProvider.notifier);
  }

  void _log(BatchOutcome outcome, List<VisitWithShop> visits) {
    final analytics = ref.read(analyticsProvider);
    final summaries = {
      for (final (i, id) in widget.visitIds.indexed)
        if (i < widget.saveSummaries.length) id: widget.saveSummaries[i],
    };
    final firstRecordAt = visits
        .map((e) => e.visit.eatenAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final totalBowls = visits
        .where((e) => e.visit.result == VisitResult.eaten)
        .length;
    for (final event in batchOutcomeEvents(
      outcome,
      summaries: summaries,
      totalBowls: totalBowls,
      firstRecordAt: firstRecordAt,
    )) {
      unawaited(analytics.log(event));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visitsState = ref.watch(visitsProvider);
    final visits = visitsState.value;
    final wishesState = ref.watch(wishesProvider);
    final wishes =
        wishesState.value ?? (wishesState.hasError ? const <Wish>[] : null);
    final homeBasesState = ref.watch(homeBaseSettingsProvider);
    final homeBases =
        homeBasesState.value ??
        (homeBasesState.hasError ? const <HomeBaseSetting>[] : null);
    _outcome ??= visits == null || wishes == null || homeBases == null
        ? null
        : computeBatchOutcome(
            visits,
            widget.visitIds,
            wishes: wishes,
            homeBases: homeBases,
            prefectureOf: ref.watch(prefectureIndexProvider).prefectureOf,
          );
    final outcome = _outcome;
    if (outcome != null && !_logged && visits != null) {
      _logged = true;
      _log(outcome, visits);
    }

    // 1杯ずつの結果の画面と同じく、閉じるときに通知の許可を尋ね、印帳のいちばん上に戻す。
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _notifications.requestPermission();
        _tabs.select(AppTab.records);
        _ledgerTop.request();
      },
      child: Theme(
        data: resultNightTheme(Theme.of(context)),
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(l10n.resultTitle),
          ),
          body: switch (outcome) {
            final outcome? => _BatchBody(outcome: outcome),
            null when visitsState.hasError => Center(
              child: Text(l10n.homeLoadFailed),
            ),
            null => const Center(child: CircularProgressIndicator()),
          },
          bottomNavigationBar: SafeBottomBar(
            child: SumiFuda(
              night: true,
              expand: true,
              height: 56,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.resultOk),
            ),
          ),
        ),
      ),
    );
  }
}

/// 印を1つずつ押し、杯数と合計の点を出し、修行点の帯を伸ばし、知らせをまとめて出す。
abstract final class _Beat {
  static const stampWait = Duration(milliseconds: 200);
  static const stampStagger = Duration(milliseconds: 120);
  static const stampDrop = Duration(milliseconds: 400);
  static const afterStamps = Duration(milliseconds: 200);
  static const countLength = Duration(milliseconds: 500);
  static const expBarAfterCount = Duration(milliseconds: 200);
  static const expBarLength = Duration(milliseconds: 700);
  static const noticeGap = Duration(milliseconds: 300);
  static const noticeStagger = Duration(milliseconds: 150);
  static const noticeLength = Duration(milliseconds: 600);

  /// 印が多いときも待たせすぎないよう、押す間隔の合計に上限を付ける。
  static Duration stampAt(int i, int count) {
    const total = Duration(milliseconds: 1500);
    final stagger = count > 1 && stampStagger * (count - 1) > total
        ? total ~/ (count - 1)
        : stampStagger;
    return stampWait + stagger * i;
  }
}

class _BatchBody extends StatelessWidget {
  const _BatchBody({required this.outcome});

  final BatchOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final scored = outcome.scored;

    final stampsEnd =
        _Beat.stampAt(scored.length - 1, scored.length) + _Beat.stampDrop;
    final countAt = stampsEnd + _Beat.afterStamps;
    final expBar = ExpBar(
      before: outcome.totalBefore,
      after: outcome.totalAfter,
      rankBefore: outcome.rankBefore,
      rankAfter: outcome.rankAfter,
      delay: countAt + _Beat.countLength + _Beat.expBarAfterCount,
      duration: _Beat.expBarLength,
    );

    final notices = <Widget Function(Duration at)>[
      for (final entry in outcome.wishFulfillments)
        (at) => WishFulfilledBanner(
          wish: entry.fulfilledWish!,
          eatenAt: entry.visit.eatenAt,
          revealAt: at,
        ),
      if (outcome.revealsHealthyLife)
        (at) => HealthyLifeRevealBanner(revealAt: at),
      for (final levelUp in outcome.questLevelUps)
        (at) => QuestAchievedBanner(levelUp: levelUp, revealAt: at),
    ];
    final barEnd = outcome.isRankUp
        ? expBar.end
        : expBar.delay + expBar.duration;
    final noticesAt = barEnd + _Beat.noticeGap;
    Duration noticeAt(int i) => noticesAt + _Beat.noticeStagger * i;
    final end = notices.isEmpty
        ? barEnd
        : noticeAt(notices.length - 1) + _Beat.noticeLength;

    return MotionTimeline(
      duration: end,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: const BoxDecoration(color: Washi.page),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final (i, entry) in scored.indexed)
                    StampPress(
                      delay: _Beat.stampAt(i, scored.length),
                      duration: _Beat.stampDrop,
                      haptic: i == scored.length - 1,
                      child: InkanStamp(scored: entry, size: 84),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              l10n.batchBowls(proseNumber(scored.length)),
              style: textTheme.titleLarge,
            ),
          ),
          Center(
            child: MotionBuilder(
              delay: countAt,
              duration: _Beat.countLength,
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Text(
                l10n.batchPointsGained((outcome.points * t).round()),
                style: TextStyle(
                  fontFamily: Washi.brush,
                  fontSize: 40,
                  color: colors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          expBar,
          if (outcome.rankSteps > 1) ...[
            const SizedBox(height: 8),
            RiseIn(
              delay: expBar.rankStampedAt,
              child: Text(
                l10n.batchRankSteps(
                  kanjiNumber(outcome.rankSteps),
                  adventurerRankLabel(l10n, outcome.rankBefore),
                  adventurerRankLabel(l10n, outcome.rankAfter),
                ),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
            ),
          ],
          for (final (i, notice) in notices.indexed) ...[
            const SizedBox(height: 12),
            notice(noticeAt(i)),
          ],
        ],
      ),
    );
  }
}
