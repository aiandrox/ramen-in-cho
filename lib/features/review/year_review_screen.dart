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
import '../scoring/points.dart';
import '../scoring/rank_labels.dart';
import '../scoring/scoring_providers.dart';
import '../stats/stats.dart';
import '../stats/stats_screen.dart';
import '../words/words.dart';
import 'year_review.dart';
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

    final pages = <Widget>[
      _CoverPage(review: review),
      if (!review.isEmpty) _CountsPage(review: review),
      if (review.favoriteShop case final favorite?)
        _FavoritePage(favorite: favorite),
      if (review.highestPoints case final best?)
        _BestBowlPage(
          title: l10n.reviewBestTitle,
          best: best,
          value: l10n.points(best.value),
          showStamp: true,
        ),
      if (review.longestWait case final best?)
        _BestBowlPage(
          title: l10n.reviewWaitTitle,
          best: best,
          value: l10n.minutes(best.value),
          showStamp: false,
        ),
      if (review.styles.isNotEmpty)
        _Page(
          title: l10n.statsStyles,
          children: [StyleBreakdown(shares: review.styles)],
        ),
      if (review.bowls > 0) _MonthlyPage(monthly: review.monthlyBowls),
      if (review.hasAchievements) _AchievementsPage(review: review),
      if (!review.isEmpty)
        _ClosingPage(
          review: review,
          cardKey: _cardKey,
          buttonKey: _buttonKey,
          onShare: _isSharing ? null : _share,
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
                  for (final child in pages)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Washi.page,
                          border: Border.all(color: Washi.line),
                        ),
                        child: child,
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

/// この一年で食べた1杯の印を、ポン、ポン、と順に押していき、押し終えたら数字を出す。
class _CountsPage extends StatefulWidget {
  const _CountsPage({required this.review});

  final YearReview review;

  @override
  State<_CountsPage> createState() => _CountsPageState();
}

class _CountsPageState extends State<_CountsPage>
    with SingleTickerProviderStateMixin {
  late final int _count = widget.review.stamps.length;

  // めくり終えてから一呼吸おいて押し始める（ページはめくり始めた時点で作られるため）。
  static const _lead = 900;

  // 1つあたり0.15秒、多いときは全部で3秒に収める。押し終えたら0.4秒で数字を出す。
  late final _perStamp = _count == 0 ? 0 : (3000 / _count).clamp(40, 150);
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (_lead + _perStamp * _count + 600).round(),
    ),
  )..forward();

  /// 押し始めてからの時間（ミリ秒）。押し始める前は負。
  double get _elapsed =>
      _controller.value * _controller.duration!.inMilliseconds - _lead;
  int _pressed = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final elapsed = _elapsed;
      final pressed = _perStamp == 0 || elapsed < 0
          ? 0
          : (elapsed / _perStamp).floor().clamp(0, _count);
      if (pressed > _pressed) {
        HapticFeedback.selectionClick();
        _pressed = pressed;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    return _Page(
      title: l10n.reviewCountsTitle,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final elapsed = _elapsed;
            return Column(
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
                          scored: stamp,
                          size: size,
                          progress: _perStamp == 0
                              ? 1
                              : ((elapsed - i * _perStamp) / _perStamp).clamp(
                                  0.0,
                                  1.0,
                                ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedOpacity(
                  opacity: _controller.isCompleted ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    children: [
                      _Figure(
                        label: l10n.reviewBowls,
                        value: l10n.bowls(review.bowls),
                      ),
                      _Figure(
                        label: l10n.reviewShops,
                        value: l10n.reviewShopCount(review.shops),
                      ),
                      _Figure(
                        label: l10n.reviewPoints,
                        value: l10n.points(review.points),
                      ),
                      if (review.retreats > 0)
                        _Figure(
                          label: l10n.reviewRetreats,
                          value: l10n.reviewRetreatCount(review.retreats),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 押される途中の印。上から大きく落ちてきて、[progress]が1で紙に着く。
class _PressedStamp extends StatelessWidget {
  const _PressedStamp({
    required this.scored,
    required this.size,
    required this.progress,
  });

  final ScoredVisit scored;
  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();
    final drop = Curves.easeInCubic.transform(progress);
    return Opacity(
      opacity: 0.3 + 0.7 * drop,
      child: Transform.scale(
        scale: 1.8 - 0.8 * drop,
        child: InkanStamp(scored: scored, size: size),
      ),
    );
  }
}

class _FavoritePage extends StatelessWidget {
  const _FavoritePage({required this.favorite});

  final FrequentShop favorite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Page(
      title: l10n.reviewFavoriteTitle,
      children: [
        Text(
          favorite.shop.name,
          textAlign: TextAlign.center,
          style: _bigBrush.copyWith(fontSize: 34),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.reviewFavoriteLine(favorite.count),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _BestBowlPage extends StatelessWidget {
  const _BestBowlPage({
    required this.title,
    required this.best,
    required this.value,
    required this.showStamp,
  });

  final String title;
  final PersonalBest best;
  final String value;
  final bool showStamp;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _Page(
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
          value,
          textAlign: TextAlign.center,
          style: _bigBrush.copyWith(color: Washi.ai),
        ),
      ],
    );
  }
}

class _MonthlyPage extends StatelessWidget {
  const _MonthlyPage({required this.monthly});

  final List<int> monthly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final most = monthly.reduce(math.max);
    const barHeight = 160.0;
    return _Page(
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          count == 0 ? '' : '$count',
                          style: textTheme.bodySmall,
                        ),
                        Container(
                          height: math.max(2, barHeight * count / most),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          color: count == 0 ? Washi.line : Washi.ai,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${i + 1}',
                          style: textTheme.bodySmall?.copyWith(
                            color: Washi.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AchievementsPage extends StatelessWidget {
  const _AchievementsPage({required this.review});

  final YearReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return _Page(
      title: l10n.reviewAchievementsTitle,
      children: [
        if (review.ranks.isNotEmpty) ...[
          SectionTitle(l10n.reviewRanks),
          for (final attained in review.ranks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                adventurerRankLabel(l10n, attained.rank),
                style: const TextStyle(fontFamily: Washi.brush, fontSize: 20),
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
              leading: QuestSeal(
                quest: reached.quest,
                level: reached.level,
                size: 36,
              ),
              title: Text(reached.quest.title),
              trailing: reached.quest.kind == QuestKind.standing
                  ? Text(
                      l10n.questLevel(reached.level),
                      style: textTheme.bodyMedium,
                    )
                  : null,
            ),
          const SizedBox(height: 16),
        ],
        if (review.wishesFulfilled > 0)
          _Figure(
            label: l10n.reviewWishes,
            value: l10n.reviewWishCount(review.wishesFulfilled),
          ),
        if (review.expeditions.isNotEmpty)
          _Figure(
            label: l10n.reviewExpeditions,
            value: l10n.reviewExpeditionCount(review.expeditions.length),
          ),
      ],
    );
  }
}

class _ClosingPage extends StatelessWidget {
  const _ClosingPage({
    required this.review,
    required this.cardKey,
    required this.buttonKey,
    required this.onShare,
  });

  final YearReview review;
  final GlobalKey cardKey;
  final GlobalKey buttonKey;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
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
                Text(
                  yearClosingWords(review.year),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: Washi.brush,
                    fontSize: 16,
                    color: Washi.ink,
                    height: 1.5,
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
