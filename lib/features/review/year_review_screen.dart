import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../inkan/inkan.dart';
import '../inkan/inkan_stamp.dart';
import '../quests/quest_seal.dart';
import '../quests/quests.dart';
import '../records/date_format.dart';
import '../scoring/rank_labels.dart';
import '../scoring/scoring_providers.dart';
import '../stats/stats.dart';
import '../stats/stats_screen.dart';
import '../words/words.dart';
import 'year_review.dart';
import 'year_review_seen.dart';
import '../notifications/notification_calendar.dart';
import '../records/clock.dart';
import '../../theme/washi_buttons.dart';

/// 1年の振り返り。紙芝居のように、横にめくって1枚ずつ見る。数字の無いページは飛ばす。
class YearReviewScreen extends ConsumerStatefulWidget {
  const YearReviewScreen({super.key, required this.year});

  final int year;

  @override
  ConsumerState<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends ConsumerState<YearReviewScreen> {
  final _pageController = PageController();
  final _cardKey = GlobalKey();
  final _buttonKey = GlobalKey();
  int _page = 0;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    // 年末に開いた年には、振り返りを勧める通知をもう出さない。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          closesYearReview(widget.year, ref.read(currentTimeProvider))) {
        ref.read(yearReviewSeenProvider.notifier).markSeen(widget.year);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final button = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    // iPadでは共有の画面の出どころを指定しないと落ちるため、ボタンの位置を渡す。
    final origin = button == null
        ? null
        : button.localToGlobal(Offset.zero) & button.size;
    if (boundary == null) return;
    setState(() => _isSharing = true);
    try {
      // 締めのひとことを書いている途中で押されても、書き終えた絵を切り取る。
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('画像を作れませんでした');
      final directory = await getTemporaryDirectory();
      final file = File(
        p.join(directory.path, 'ramen-in-cho-${widget.year}.png'),
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('Share failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scored = ref.watch(scoredVisitsProvider);
    final review = yearReview(
      scored,
      widget.year,
      questProgress: ref.watch(questProgressProvider),
    );

    final pages = <Widget Function(bool active)>[
      (_) => _CoverPage(review: review),
      if (!review.isEmpty)
        (active) => _CountsPage(review: review, active: active),
      if (review.favoriteShop case final favorite?)
        (active) => _FavoritePage(favorite: favorite, active: active),
      if (review.highestPoints case final best?)
        (active) => _BestBowlPage(
          title: l10n.reviewBestTitle,
          best: best,
          value: l10n.points,
          showStamp: true,
          active: active,
        ),
      if (review.longestWait case final best?)
        (active) => _BestBowlPage(
          title: l10n.reviewWaitTitle,
          best: best,
          value: l10n.minutes,
          showStamp: false,
          active: active,
        ),
      if (review.styles.isNotEmpty)
        (_) => _Page(
          title: l10n.statsStyles,
          children: [StyleBreakdown(shares: review.styles)],
        ),
      if (review.bowls > 0)
        (active) => _MonthlyPage(monthly: review.monthlyBowls, active: active),
      if (review.hasAchievements)
        (active) => _AchievementsPage(review: review, active: active),
      if (!review.isEmpty)
        (active) => _ClosingPage(
          review: review,
          cardKey: _cardKey,
          buttonKey: _buttonKey,
          onShare: _isSharing ? null : _share,
          active: active,
        ),
    ];
    final page = math.min(_page, pages.length - 1);

    return Scaffold(
      backgroundColor: Washi.desk,
      appBar: AppBar(
        backgroundColor: Washi.desk,
        title: Text(l10n.reviewEntry(widget.year)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  for (final (i, build) in pages.indexed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _PaperTurn(
                        controller: _pageController,
                        index: i,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Washi.page,
                            border: Border.all(color: Washi.line),
                          ),
                          child: build(i == page),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == page ? Washi.ai : Washi.line,
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

/// めくっている紙。めくる途中だけ、綴じ目の側を軸にわずかに浮かせ、影を落とす。
class _PaperTurn extends StatelessWidget {
  const _PaperTurn({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final position =
            controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? index.toDouble()
            : index.toDouble();
        final delta = (position - index).clamp(-1.0, 1.0);
        // 止まっているときも同じ形にする（形が変わると中身が作り直され、動きが最初からになる）。
        final lift = math.sin(delta.abs() * math.pi);
        return Transform(
          alignment: delta > 0 ? Alignment.centerLeft : Alignment.centerRight,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(delta * 0.12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Washi.ink.withValues(alpha: 0.16 * lift),
                  blurRadius: 14 * lift,
                  offset: Offset(-6 * delta, 4 * lift),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// 1枚が初めて見えたときだけ、[lead]の間をおいて[duration]かけて動かす。
/// 同じ画面の中でもう一度めくって戻ってきたときは、動き終えた姿のまま。
/// 触れると動きを飛ばし、動きを減らす設定のときは初めから動き終えた姿を見せる。
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.active,
    required this.duration,
    required this.builder,
    this.onProgress,
  });

  final bool active;
  final Duration duration;

  /// [t]は0〜1。
  final Widget Function(BuildContext context, double t) builder;
  final void Function(double t)? onProgress;

  static const lead = Duration(milliseconds: 300);

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _Reveal.lead + widget.duration,
  )..addListener(() => widget.onProgress?.call(_t));

  double get _t {
    final total = _controller.duration!.inMicroseconds;
    final lead = _Reveal.lead.inMicroseconds;
    return ((_controller.value * total - lead) / (total - lead)).clamp(
      0.0,
      1.0,
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (widget.active) {
      _start();
    }
  }

  @override
  void didUpdateWidget(_Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _start();
  }

  void _start() {
    if (_controller.isDismissed) _controller.forward();
  }

  void _skip() {
    if (!_controller.isCompleted) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => _skip(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(context, _t),
      ),
    );
  }
}

/// 0から[value]まで数え上げる途中の数。
int _countUp(int value, double t) =>
    (value * Curves.easeOutCubic.transform(t)).round();

/// [count]個のものを順に動かすとき、[i]番目の進み具合。1つずつ[overlap]だけ重ねる。
double _staggered(double t, int i, int count, {double overlap = 0.5}) {
  if (count <= 1) return t;
  final step = 1 / (count - 1 + 1 / (1 - overlap));
  final span = step / (1 - overlap);
  return ((t - i * step) / span).clamp(0.0, 1.0);
}

/// 1枚の中身。見出しを上に、中身を真ん中に寄せる。画面が低いときはスクロールする。
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 48),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: Washi.brush,
                  fontSize: 26,
                  color: Washi.ai,
                ),
              ),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

const _bigBrush = TextStyle(
  fontFamily: Washi.brush,
  fontSize: 40,
  color: Washi.ink,
  height: 1.2,
);

String _eraYear(AppLocalizations l10n, int year) {
  final (era, eraYear) = japaneseEra(DateTime(year, 12, 31));
  return l10n.reviewCoverEra(switch (era) {
    Era.heisei => l10n.eraHeisei,
    Era.reiwa => l10n.eraReiwa,
  }, eraYear == 1 ? l10n.eraFirstYear : kanjiNumber(eraYear));
}

class _CoverPage extends StatelessWidget {
  const _CoverPage({required this.review});

  final YearReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return _Page(
      title: _eraYear(l10n, review.year),
      children: [
        Text(
          l10n.reviewCoverYear(review.year),
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(color: Washi.inkSoft),
        ),
        const SizedBox(height: 32),
        Text(
          review.isEmpty ? l10n.reviewCoverEmpty : l10n.reviewCoverHint,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: Washi.inkSoft),
        ),
      ],
    );
  }
}

/// 名前と大きな数字の1組。
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            label,
            style: textTheme.titleMedium?.copyWith(color: Washi.inkSoft),
          ),
          Text(value, style: _bigBrush),
        ],
      ),
    );
  }
}

/// この一年で食べた1杯の印を、ポン、ポン、と順に押していき、押し終えたら数字を数え上げる。
class _CountsPage extends StatefulWidget {
  const _CountsPage({required this.review, required this.active});

  final YearReview review;
  final bool active;

  @override
  State<_CountsPage> createState() => _CountsPageState();
}

class _CountsPageState extends State<_CountsPage> {
  late final int _count = widget.review.stamps.length;

  // 1つあたり0.15秒、多いときは全部で3秒に収める。押し終えたら0.8秒で数字を数え上げる。
  late final double _perStamp = _count == 0
      ? 0
      : (3000 / _count).clamp(40, 150).toDouble();
  static const _countUpMs = 800;
  late final double _total = _perStamp * _count + _countUpMs;

  int _pressed = 0;

  void _onProgress(double t) {
    if (_perStamp == 0) return;
    final pressed = (t * _total / _perStamp).floor().clamp(0, _count);
    if (pressed > _pressed) {
      HapticFeedback.selectionClick();
      _pressed = pressed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final review = widget.review;
    final size = _count <= 12
        ? 64.0
        : _count <= 30
        ? 48.0
        : 36.0;
    return _Reveal(
      active: widget.active,
      duration: Duration(milliseconds: _total.round()),
      onProgress: _onProgress,
      builder: (context, t) {
        final elapsed = t * _total;
        final counted = ((elapsed - _perStamp * _count) / _countUpMs).clamp(
          0.0,
          1.0,
        );
        return _Page(
          title: l10n.reviewCountsTitle,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final (i, stamp) in review.stamps.indexed)
                  SizedBox.square(
                    dimension: size,
                    child: _PressedStamp(
                      progress: _perStamp == 0
                          ? 1
                          : ((elapsed - i * _perStamp) / _perStamp).clamp(
                              0.0,
                              1.0,
                            ),
                      child: InkanStamp(scored: stamp, size: size),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: math.min(1, counted * 3),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                children: [
                  _Figure(
                    label: l10n.reviewBowls,
                    value: l10n.bowls(_countUp(review.bowls, counted)),
                  ),
                  _Figure(
                    label: l10n.reviewShops,
                    value: l10n.reviewShopCount(
                      _countUp(review.shops, counted),
                    ),
                  ),
                  _Figure(
                    label: l10n.reviewPoints,
                    value: l10n.points(_countUp(review.points, counted)),
                  ),
                  if (review.retreats > 0)
                    _Figure(
                      label: l10n.reviewRetreats,
                      value: l10n.reviewRetreatCount(
                        _countUp(review.retreats, counted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 押される途中の印。上から大きく落ちてきて、[progress]が1で紙に着く。
/// 押す前も場所はとっておき、押している間に並びが動かないようにする。
class _PressedStamp extends StatelessWidget {
  const _PressedStamp({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress >= 1) return child;
    if (progress <= 0) return Opacity(opacity: 0, child: child);
    final drop = Curves.easeInCubic.transform(progress);
    return Opacity(
      opacity: 0.3 + 0.7 * drop,
      child: Transform.scale(scale: 1.8 - 0.8 * drop, child: child),
    );
  }
}

class _FavoritePage extends StatelessWidget {
  const _FavoritePage({required this.favorite, required this.active});

  final FrequentShop favorite;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Reveal(
      active: active,
      duration: const Duration(milliseconds: 700),
      builder: (context, t) => _Page(
        title: l10n.reviewFavoriteTitle,
        children: [
          Text(
            favorite.shop.name,
            textAlign: TextAlign.center,
            style: _bigBrush.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.reviewFavoriteLine(_countUp(favorite.count, t)),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _BestBowlPage extends StatelessWidget {
  const _BestBowlPage({
    required this.title,
    required this.best,
    required this.value,
    required this.showStamp,
    required this.active,
  });

  final String title;
  final PersonalBest best;

  /// 数を言葉にする（「〇点」「〇分」）。
  final String Function(int) value;
  final bool showStamp;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _Reveal(
      active: active,
      duration: const Duration(milliseconds: 800),
      builder: (context, t) => _Page(
        title: title,
        children: [
          if (showStamp) ...[
            Center(child: InkanStamp(scored: best.entry, size: 120)),
            const SizedBox(height: 16),
          ],
          Text(
            best.entry.shop.name,
            textAlign: TextAlign.center,
            style: _bigBrush.copyWith(fontSize: 30),
          ),
          Text(
            formatDate(best.entry.visit.eatenAt),
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(color: Washi.inkSoft),
          ),
          const SizedBox(height: 16),
          Text(
            value(_countUp(best.value, t)),
            textAlign: TextAlign.center,
            style: _bigBrush.copyWith(color: Washi.ai),
          ),
        ],
      ),
    );
  }
}

/// 月ごとの杯数。1月から順に、棒を1本ずつのばす。
class _MonthlyPage extends StatelessWidget {
  const _MonthlyPage({required this.monthly, required this.active});

  final List<int> monthly;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final most = monthly.reduce(math.max);
    const barHeight = 160.0;
    return _Reveal(
      active: active,
      duration: const Duration(milliseconds: 900),
      builder: (context, t) => _Page(
        title: l10n.reviewMonthlyTitle,
        children: [
          Semantics(
            label: [
              for (final (i, count) in monthly.indexed)
                l10n.reviewMonthBowls(i + 1, count),
            ].join('、'),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, count) in monthly.indexed)
                    Expanded(
                      child: _MonthBar(
                        month: i + 1,
                        count: count,
                        height: barHeight * count / most,
                        grown: Curves.easeOutCubic.transform(
                          _staggered(t, i, monthly.length, overlap: 0.7),
                        ),
                        style: textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.count,
    required this.height,
    required this.grown,
    required this.style,
  });

  final int month;
  final int count;
  final double height;

  /// 棒がのびた割合（0〜1）。
  final double grown;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Opacity(
        opacity: grown,
        child: Text(count == 0 ? '' : '$count', style: style),
      ),
      Container(
        height: math.max(2, height * grown),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        color: count == 0 ? Washi.line : Washi.ai,
      ),
      const SizedBox(height: 4),
      Text('$month', style: style?.copyWith(color: Washi.inkSoft)),
    ],
  );
}

/// 段位と型・秘伝。上から順に、1つずつ印を押すように出す。
class _AchievementsPage extends StatelessWidget {
  const _AchievementsPage({required this.review, required this.active});

  final YearReview review;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final hasFigures =
        review.wishesFulfilled > 0 || review.expeditions.isNotEmpty;
    final slots =
        review.ranks.length + review.quests.length + (hasFigures ? 1 : 0);
    return _Reveal(
      active: active,
      duration: Duration(milliseconds: (slots * 220).clamp(600, 1800).toInt()),
      builder: (context, t) {
        var slot = 0;
        double next() => _staggered(t, slot++, slots, overlap: 0.4);
        final counted = hasFigures
            ? _staggered(t, slots - 1, slots, overlap: 0.4)
            : 1.0;
        return _Page(
          title: l10n.reviewAchievementsTitle,
          children: [
            if (review.ranks.isNotEmpty) ...[
              SectionTitle(l10n.reviewRanks),
              for (final attained in review.ranks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Align(
                    alignment: Alignment.centerLeft,
                    child: _PressedStamp(
                      progress: next(),
                      child: Text(
                        adventurerRankLabel(l10n, attained.rank),
                        style: const TextStyle(
                          fontFamily: Washi.brush,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  trailing: Text(
                    formatDate(attained.reachedAt!),
                    style: textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 16),
            ],
            if (review.quests.isNotEmpty) ...[
              SectionTitle(l10n.reviewQuests),
              for (final reached in review.quests)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: _PressedStamp(
                    progress: next(),
                    child: QuestSeal(
                      quest: reached.quest,
                      level: reached.level,
                      size: 36,
                    ),
                  ),
                  title: Text(reached.quest.title),
                  trailing: reached.quest.kind == QuestKind.standing
                      ? Text(
                          l10n.questLevel(kanjiNumber(reached.level)),
                          style: textTheme.bodyMedium,
                        )
                      : null,
                ),
              const SizedBox(height: 16),
            ],
            if (hasFigures)
              Opacity(
                opacity: math.min(1, counted * 3),
                child: Column(
                  children: [
                    if (review.wishesFulfilled > 0)
                      _Figure(
                        label: l10n.reviewWishes,
                        value: l10n.reviewWishCount(
                          _countUp(review.wishesFulfilled, counted),
                        ),
                      ),
                    if (review.expeditions.isNotEmpty)
                      _Figure(
                        label: l10n.reviewExpeditions,
                        value: l10n.reviewExpeditionCount(
                          _countUp(review.expeditions.length, counted),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ClosingPage extends StatelessWidget {
  const _ClosingPage({
    required this.review,
    required this.cardKey,
    required this.buttonKey,
    required this.onShare,
    required this.active,
  });

  final YearReview review;
  final GlobalKey cardKey;
  final GlobalKey buttonKey;
  final VoidCallback? onShare;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final words = yearClosingWords(review.year);
    final characters = words.characters.toList();
    return _Page(
      title: l10n.reviewClosingTitle,
      children: [
        // 共有する絵は、このカードだけを切り取る。
        RepaintBoundary(
          key: cardKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Washi.paper,
              border: Border.all(color: Washi.ai, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  _eraYear(l10n, review.year),
                  style: const TextStyle(
                    fontFamily: Washi.brush,
                    fontSize: 22,
                    color: Washi.ai,
                  ),
                ),
                Text(
                  l10n.reviewCoverYear(review.year),
                  style: textTheme.bodyMedium?.copyWith(color: Washi.inkSoft),
                ),
                const SizedBox(height: 12),
                // 共有する絵は、この一年の印の一覧を主役にする。
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    for (final stamp in review.stamps)
                      InkanStamp(
                        scored: stamp,
                        size: review.stamps.length <= 20
                            ? 56
                            : review.stamps.length <= 60
                            ? 40
                            : 30,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.reviewSummaryLine(
                    review.bowls,
                    review.shops,
                    review.points,
                  ),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                // 締めのひとことは、筆で書くように1文字ずつ墨をのせる。
                // 文字の場所は初めから決めておき、書いている途中で行が動かないようにする。
                _Reveal(
                  active: active,
                  duration: Duration(
                    milliseconds: (characters.length * 70)
                        .clamp(600, 2000)
                        .toInt(),
                  ),
                  builder: (context, t) => Text.rich(
                    TextSpan(
                      children: [
                        for (final (i, char) in characters.indexed)
                          TextSpan(
                            text: char,
                            style: TextStyle(
                              color: Washi.ink.withValues(
                                alpha: _staggered(
                                  t,
                                  i,
                                  characters.length,
                                  overlap: 0.8,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    semanticsLabel: words,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: Washi.brush,
                      fontSize: 16,
                      color: Washi.ink,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.appName,
                  style: textTheme.bodySmall?.copyWith(color: Washi.inkSoft),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: AiFuda(
            key: buttonKey,
            onPressed: onShare,
            icon: const Icon(Icons.ios_share),
            child: Text(l10n.shareButton),
          ),
        ),
      ],
    );
  }
}
