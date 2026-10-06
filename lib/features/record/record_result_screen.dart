import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../inkan/inkan.dart';
import '../../l10n/app_localizations.dart';
import '../home_base/home_base_repository.dart';
import '../notifications/notification_service.dart';
import '../quests/quest_seal.dart';
import '../quests/quests.dart';
import '../prefecture/prefectures.dart';
import '../records/record_repository.dart';
import '../scoring/points_breakdown_view.dart';
import '../records/models.dart';
import '../scoring/record_outcome.dart';
import 'exp_bar.dart';
import '../share/share_screen.dart';
import '../wishes/wish_repository.dart';
import '../wishes/wishes.dart';
import '../inkan/inkan_stamp.dart';
import '../records/visit_photo.dart';
import '../scoring/points.dart';
import '../../theme/ink_wear.dart';
import '../../theme/motion.dart';
import '../../theme/safe_bottom.dart';
import '../journal/journal_view.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';

/// 保存した記録で得たポイントの内訳と、累計・ランクの変化を見せる。
class RecordResultScreen extends ConsumerStatefulWidget {
  const RecordResultScreen({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<RecordResultScreen> createState() => _RecordResultScreenState();
}

class _RecordResultScreenState extends ConsumerState<RecordResultScreen> {
  /// 最初に求めた結果を持ち続ける。表示中に記録が変わっても、演出をやり直さないため。
  RecordOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    // 連続記録が途切れそうなときに知らせるため、記録したこのときに通知の許可を尋ねる。
    ref.read(notificationServiceProvider).requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visitsState = ref.watch(visitsProvider);
    final visits = visitsState.value;
    // 願は「願成就」を出すためだけに使うので、読めなかったときは願なしで結果を出す。
    final wishesState = ref.watch(wishesProvider);
    final wishes =
        wishesState.value ?? (wishesState.hasError ? const <Wish>[] : null);
    final homeBasesState = ref.watch(homeBaseSettingsProvider);
    final homeBases =
        homeBasesState.value ??
        (homeBasesState.hasError ? const <HomeBaseSetting>[] : null);
    _outcome ??= visits == null || wishes == null || homeBases == null
        ? null
        : computeRecordOutcome(
            visits,
            widget.visitId,
            wishes: wishes,
            homeBases: homeBases,
            prefectureOf: ref.watch(prefectureIndexProvider).prefectureOf,
          );
    final outcome = _outcome;

    final base = Theme.of(context);
    final night = base.copyWith(
      scaffoldBackgroundColor: Washi.ink,
      colorScheme: base.colorScheme.copyWith(
        primary: Washi.aiLight,
        onPrimary: Washi.ink,
        surface: Washi.ink,
        onSurface: Washi.paper,
        onSurfaceVariant: Washi.nightSoft,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Washi.paper,
        displayColor: Washi.paper,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Washi.ink,
        foregroundColor: Washi.paper,
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          color: Washi.paper,
        ),
      ),
    );

    return Theme(
      data: night,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.resultTitle),
        ),
        body: switch (outcome) {
          final outcome? => _ResultBody(outcome: outcome),
          null when visitsState.hasError => Center(
            child: Text(l10n.homeLoadFailed),
          ),
          null => const Center(child: CircularProgressIndicator()),
        },
        // 共有は、結果を見ているどの時点でも押せるよう、下に固定して「印帳にもどる」と並べる。
        bottomNavigationBar: SafeBottomBar(
          child: Row(
            children: [
              if (outcome != null) ...[
                Expanded(
                  child: AiFuda(
                    night: true,
                    expand: true,
                    height: 56,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ShareScreen(visitId: outcome.scored.visit.id),
                      ),
                    ),
                    icon: const Icon(Icons.ios_share),
                    child: Text(l10n.resultShare),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SumiFuda(
                  night: true,
                  expand: true,
                  height: 56,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.resultOk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 着丼直後の演出の段取り（演出の始まりから数える）。印を押し、点を数え、内訳を1行ずつ出し、
/// 修行点の帯を伸ばし、知らせを順に出し、最後に道中記を1文ずつ出して余韻にする。
/// どこをタップしても最後の状態まで飛ばせる。下の「印帳にもどる」はいつでも押せる。
abstract final class _Beat {
  static const stampWait = Duration(milliseconds: 245);
  static const stampDrop = Duration(milliseconds: 455);
  static const count = Duration(milliseconds: 700);
  static const countLength = Duration(milliseconds: 500);
  static const breakdown = Duration(milliseconds: 700);
  static const expBar = Duration(milliseconds: 900);
  static const expBarLength = Duration(milliseconds: 600);
  static const notices = Duration(milliseconds: 1200);
  static const noticeStagger = Duration(milliseconds: 150);

  /// 1つの知らせを出し終えるまで（印がにじみ、名前が浮かぶ／叶の印を押す）。
  static const noticeLength = Duration(milliseconds: 600);
  static const journalAfterNotices = Duration(milliseconds: 200);
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.outcome});

  final RecordOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final scored = outcome.scored;
    final wish = scored.fulfilledWish;

    final expBar = ExpBar(
      before: outcome.totalBefore,
      after: outcome.totalAfter,
      rankBefore: outcome.rankBefore,
      rankAfter: outcome.rankAfter,
      delay: _Beat.expBar,
      duration: _Beat.expBarLength,
    );

    final notices = <Widget Function(Duration at)>[
      if (wish != null)
        (at) => _WishFulfilledBanner(
          wish: wish,
          eatenAt: scored.visit.eatenAt,
          revealAt: at,
        ),
      if (outcome.revealsHealthyLife)
        (at) => _HealthyLifeRevealBanner(revealAt: at),
      for (final levelUp in outcome.questLevelUps)
        (at) => _QuestAchievedBanner(levelUp: levelUp, revealAt: at),
    ];
    Duration later(Duration a, Duration b) => a > b ? a : b;
    // 段位が上がるときは、段位の印を押し終えてから知らせを出す（震えが重ならないように）。
    final noticesAt = outcome.isRankUp
        ? later(_Beat.notices, expBar.rankStampedAt)
        : _Beat.notices;
    Duration noticeAt(int i) => noticesAt + _Beat.noticeStagger * i;
    final noticesEnd = notices.isEmpty
        ? _Beat.expBar + _Beat.expBarLength
        : noticeAt(notices.length - 1) + _Beat.noticeLength;
    // 道中記は、知らせと師匠のひとことを出し終えてから。
    final journalAt = later(noticesEnd, expBar.end) + _Beat.journalAfterNotices;
    final journal = outcome.journal;
    final ends = [
      expBar.end,
      noticesEnd,
      if (journal.isNotEmpty)
        journalAt + JournalView.revealLength(journal.length),
    ];

    return MotionTimeline(
      duration: ends.reduce((a, b) => a > b ? a : b),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const SizedBox(height: 8),
          _StampedPage(scored: scored),
          const SizedBox(height: 16),
          // 主役は得た点。内訳はその下に控えめに。段位は上がったときだけ知らせる。
          Center(
            child: MotionBuilder(
              delay: _Beat.count,
              duration: _Beat.countLength,
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Text(
                l10n.pointsGained((scored.points.total * t).round()),
                style: TextStyle(
                  fontFamily: Washi.brush,
                  fontSize: 44,
                  color: colors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Opacity(
            opacity: 0.75,
            child: PointsBreakdownView(
              scored: scored,
              revealAt: _Beat.breakdown,
            ),
          ),
          const SizedBox(height: 20),
          // 修行点の帯が伸び、段位が上がればその場で新しい段位の印を押す。
          expBar,
          for (final (i, notice) in notices.indexed) ...[
            const SizedBox(height: 12),
            notice(noticeAt(i)),
          ],
          if (journal.isNotEmpty) ...[
            const SizedBox(height: 24),
            JournalView(
              lines: journal,
              color: colors.onSurface,
              revealAt: journalAt,
            ),
          ],
        ],
      ),
    );
  }
}

/// 白いページに、印が上からポンと押される。
class _StampedPage extends StatelessWidget {
  const _StampedPage({required this.scored});

  final ScoredVisit scored;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Washi.page),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VerticalText(
              scored.shop.name,
              maxChars: 9,
              style: const TextStyle(
                fontFamily: Washi.brush,
                fontSize: 26,
                color: Washi.ink,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PastedPhoto(
                  angle: -2 * math.pi / 180,
                  border: 5,
                  child: SizedBox(
                    width: 150,
                    height: 112,
                    child: VisitPhoto(
                      photoPath: scored.visit.photoPath,
                      cacheWidth: 400,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: StampPress(
                    delay: _Beat.stampWait,
                    duration: _Beat.stampDrop,
                    child: InkanStamp(scored: scored, size: 136),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestAchievedBanner extends StatelessWidget {
  const _QuestAchievedBanner({required this.levelUp, required this.revealAt});

  final QuestLevelUp levelUp;
  final Duration revealAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final quest = levelUp.quest;
    final isSpot = quest.kind == QuestKind.spot;

    // 地が浮かび、印のインクがにじみ、少しおくれて名前が出る。
    return RiseIn(
      delay: revealAt,
      child: Card(
        elevation: 0,
        color: colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              InkBleed(
                delay: revealAt + const Duration(milliseconds: 60),
                child: QuestSeal(quest: quest, level: levelUp.level, size: 56),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RiseIn(
                  delay: revealAt + const Duration(milliseconds: 260),
                  offset: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSpot ? l10n.questAchieved : l10n.questLevelUp,
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        isSpot
                            ? quest.title
                            : l10n.questLevelReached(
                                quest.title,
                                kanjiNumber(levelUp.level),
                              ),
                        style: textTheme.titleMedium?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishFulfilledBanner extends StatelessWidget {
  const _WishFulfilledBanner({
    required this.wish,
    required this.eatenAt,
    required this.revealAt,
  });

  final Wish wish;
  final DateTime eatenAt;
  final Duration revealAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final days = daysToFulfill(wish, eatenAt);
    // 枠が浮かび、願に朱の「叶」の印を押す。
    return RiseIn(
      delay: revealAt,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: Washi.aiLight)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    l10n.wishFulfilled,
                    style: const TextStyle(
                      fontFamily: Washi.brush,
                      fontSize: 32,
                      color: Washi.aiLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    days == 0
                        ? l10n.wishFulfilledSameDay
                        : l10n.wishFulfilledAfter(proseNumber(days)),
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (wish.trigger.isNotEmpty)
                    Text(
                      l10n.wishTriggerLine(wish.trigger),
                      style: textTheme.bodySmall?.copyWith(
                        color: Washi.nightSoft,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
          // 枠の角にかかるように押す。
          Positioned(
            top: -14,
            right: -6,
            child: StampPress(
              delay: revealAt + const Duration(milliseconds: 220),
              duration: const Duration(milliseconds: 380),
              child: _KanaiSeal(wishId: wish.id),
            ),
          ),
        ],
      ),
    );
  }
}

/// 叶った願に押す、朱の「叶」の丸印。
class _KanaiSeal extends StatelessWidget {
  const _KanaiSeal({required this.wishId});

  final String wishId;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -8 * math.pi / 180,
      child: InkWear(
        seed: inkSeed('kanai:$wishId'),
        strength: 0.6,
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Washi.shuLight,
          ),
          child: Text(
            AppLocalizations.of(context).wishFulfilledSealChar,
            style: const TextStyle(
              fontFamily: Washi.brush,
              fontSize: 32,
              height: 1,
              color: Washi.page,
            ),
          ),
        ),
      ),
    );
  }
}

/// 隠し要素「毎日ラーメン健康生活」が出現したときの知らせ。
class _HealthyLifeRevealBanner extends StatelessWidget {
  const _HealthyLifeRevealBanner({required this.revealAt});

  final Duration revealAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return RiseIn(
      delay: revealAt,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: Washi.aiLight)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                l10n.healthyLifeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: Washi.brush,
                  fontSize: 24,
                  color: Washi.aiLight,
                ),
              ),
              Text(l10n.healthyLifeRevealNote, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
