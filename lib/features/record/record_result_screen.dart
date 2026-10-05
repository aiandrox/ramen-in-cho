import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../inkan/inkan.dart';
import '../../l10n/app_localizations.dart';
import '../home_base/home_base_repository.dart';
import '../notifications/notification_service.dart';
import '../quests/quest_seal.dart';
import '../quests/quests.dart';
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
import '../../theme/safe_bottom.dart';
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

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.outcome});

  final RecordOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final scored = outcome.scored;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const SizedBox(height: 8),
        _StampedPage(scored: scored),
        if (scored.fulfilledWish case final wish?) ...[
          const SizedBox(height: 16),
          _WishFulfilledBanner(wish: wish, eatenAt: scored.visit.eatenAt),
        ],
        const SizedBox(height: 16),
        // 主役は得た点。内訳はその下に控えめに。段位は上がったときだけ知らせる。
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: scored.points.total.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              l10n.pointsGained(value.round()),
              style: TextStyle(
                fontFamily: Washi.brush,
                fontSize: 44,
                color: colors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Opacity(opacity: 0.75, child: PointsBreakdownView(scored: scored)),
        const SizedBox(height: 20),
        // 印を押したあとに修行点の帯が伸び、段位が上がればその場で光って替わる。
        ExpBar(
          before: outcome.totalBefore,
          after: outcome.totalAfter,
          rankBefore: outcome.rankBefore,
          rankAfter: outcome.rankAfter,
        ),
        if (outcome.revealsHealthyLife) ...[
          const SizedBox(height: 12),
          const _HealthyLifeRevealBanner(),
        ],
        for (final levelUp in outcome.questLevelUps) ...[
          const SizedBox(height: 12),
          _QuestAchievedBanner(levelUp: levelUp),
        ],
      ],
    );
  }
}

/// 白いページに、印が上からポンと押される。
class _StampedPage extends StatefulWidget {
  const _StampedPage({required this.scored});

  final ScoredVisit scored;

  @override
  State<_StampedPage> createState() => _StampedPageState();
}

/// 印を「ポンッ」と押す。上から落ちてきて、紙に当たったところでぴたりと止まり、強めに震わせる。
class _StampedPageState extends State<_StampedPage>
    with SingleTickerProviderStateMixin {
  /// 0〜この割合までは待ち、そこから当たるまで落ちる（最後に当たる）。
  static const _wait = 0.35;

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) HapticFeedback.heavyImpact();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static double _phase(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final scored = widget.scored;
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
                  child: AnimatedBuilder(
                    animation: _controller,
                    child: InkanStamp(scored: scored, size: 136),
                    builder: (context, stamp) {
                      final t = _controller.value;
                      if (t < _wait) return Opacity(opacity: 0, child: stamp);
                      final drop = Curves.easeInCubic.transform(
                        _phase(t, _wait, 1),
                      );
                      return Opacity(
                        opacity: 0.3 + 0.7 * drop,
                        child: Transform.scale(
                          scale: 1.9 - 0.9 * drop,
                          child: stamp,
                        ),
                      );
                    },
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
  const _QuestAchievedBanner({required this.levelUp});

  final QuestLevelUp levelUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final quest = levelUp.quest;
    final isSpot = quest.kind == QuestKind.spot;

    return Card(
      elevation: 0,
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            QuestSeal(quest: quest, level: levelUp.level, size: 56),
            const SizedBox(width: 12),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}

class _WishFulfilledBanner extends StatelessWidget {
  const _WishFulfilledBanner({required this.wish, required this.eatenAt});

  final Wish wish;
  final DateTime eatenAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final days = daysToFulfill(wish, eatenAt);
    return DecoratedBox(
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
                style: textTheme.bodySmall?.copyWith(color: Washi.nightSoft),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

/// 隠し要素「毎日ラーメン健康生活」が出現したときの知らせ。
class _HealthyLifeRevealBanner extends StatelessWidget {
  const _HealthyLifeRevealBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
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
    );
  }
}
