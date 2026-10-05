import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/motion.dart';
import '../../theme/washi.dart';
import '../inkan/inkan_stamp.dart';
import '../scoring/rank_labels.dart';
import '../scoring/ranks.dart';
import '../words/words.dart';

/// 着丼の直後に、修行点の帯を前の累計から今の累計まで伸ばす。
/// 段位が上がるときは、帯が新しい段位の必要点に届いたところ（すでに届いていれば伸ばし終えたところ）で、
/// 新しい段位の印を押し、師匠のひとことを筆で書くように出す。1杯で上がるのは1つだけ。
/// 時間は [MotionTimeline] の時計で数える（無ければ自分で持つ）。
class ExpBar extends StatelessWidget {
  const ExpBar({
    super.key,
    required this.before,
    required this.after,
    required this.rankBefore,
    required this.rankAfter,
    this.delay = const Duration(milliseconds: 900),
    this.duration = const Duration(milliseconds: 600),
  });

  final int before;
  final int after;
  final AdventurerRank rankBefore;
  final AdventurerRank rankAfter;

  /// 印を押し終えるのを待ってから伸ばしはじめる。
  final Duration delay;
  final Duration duration;

  static const _curve = Curves.easeOutCubic;

  /// 段位の印を押す長さと、押しはじめてからひとことを書きはじめるまで。
  static const _press = Duration(milliseconds: 350);
  static const _wordsAfter = Duration(milliseconds: 300);

  bool get _ranksUp => rankAfter.index > rankBefore.index;

  /// 帯を伸ばす間のどこ（0〜1）で新しい段位に届くか。
  double get _rankUpAt {
    final gain = after - before;
    if (gain <= 0) return 1;
    final fraction = (rankAfter.requiredPoints - before) / gain;
    if (fraction > 1) return 1;
    for (var i = 1; i <= 100; i++) {
      if (_curve.transform(i / 100) >= fraction) return i / 100;
    }
    return 1;
  }

  /// 段位が上がるときまで（演出の始まりから数える）。
  Duration get rankUpDelay => delay + duration * _rankUpAt;

  /// 段位の印を押し終えるまで（演出の始まりから数える）。
  Duration get rankStampedAt => rankUpDelay + _press;

  /// 帯を伸ばし終え、段位が上がるときは師匠のひとことを書き終えるまで。
  Duration get end {
    final grown = delay + duration;
    if (!_ranksUp) return grown;
    final written =
        rankUpDelay +
        _wordsAfter +
        Motion.brushDuration(masterWords(rankAfter));
    return written > grown ? written : grown;
  }

  @override
  Widget build(BuildContext context) {
    if (MotionTimeline.maybeOf(context) == null) {
      return MotionTimeline(
        duration: end,
        child: Builder(builder: _build),
      );
    }
    return _build(context);
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final rankUpAt = _rankUpAt;

    return MotionBuilder(
      delay: delay,
      duration: duration,
      builder: (context, s, _) {
        final points = (before + (after - before) * _curve.transform(s))
            .floor();
        final rankedUp = _ranksUp && s >= rankUpAt;
        final rank = rankedUp ? rankAfter : rankBefore;
        final next = rank.next;
        final progress = next == null
            ? 1.0
            : ((points - rank.requiredPoints) /
                      (next.requiredPoints - rank.requiredPoints))
                  .clamp(0.0, 1.0);
        final seal = RankSeal(
          label: adventurerRankLabel(l10n, rank),
          fontSize: 18,
          color: Washi.shuLight,
        );

        return Row(
          children: [
            SizedBox(
              width: 76,
              height: 52,
              child: Center(
                child: rankedUp
                    ? StampPress(
                        delay: rankUpDelay,
                        duration: _press,
                        child: seal,
                      )
                    : seal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.totalPoints(points),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      if (rankedUp)
                        RiseIn(
                          delay: rankUpDelay + _press,
                          child: Text(
                            rank.isKyu ? l10n.rankUpKyu : l10n.rankUp,
                            style: textTheme.titleSmall?.copyWith(
                              fontFamily: Washi.brush,
                              color: colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: colors.primary,
                    backgroundColor: Washi.line.withValues(alpha: 0.4),
                  ),
                  if (rankedUp) ...[
                    const SizedBox(height: 6),
                    BrushText(
                      masterWords(rank),
                      delay: rankUpDelay + _wordsAfter,
                      // 夜の色の結果画面でも読めるよう、背景に合わせた文字の色にする。
                      style: textTheme.bodyLarge?.copyWith(
                        fontFamily: Washi.brush,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
