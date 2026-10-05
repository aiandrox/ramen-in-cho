import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/motion.dart';
import '../records/labels.dart';
import '../records/models.dart';
import '../records/wait_time.dart';
import 'points.dart';

/// 1件の記録で得たポイントの内訳。0点の項目は出さない。
class PointsBreakdownView extends StatelessWidget {
  const PointsBreakdownView({super.key, required this.scored, this.revealAt});

  final ScoredVisit scored;

  /// 指定すると、このときから1行ずつ浮かび上がらせる（着丼直後の画面だけ）。
  final Duration? revealAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    if (scored.visit.result != VisitResult.eaten) {
      final text = Text(l10n.pointsRetreat, style: textTheme.bodyMedium);
      return switch (revealAt) {
        final at? => RiseIn(delay: at, child: text),
        null => text,
      };
    }
    final points = scored.points;
    final rows = [
      (l10n.pointsBase, points.base),
      (l10n.pointsWait(waitMinutes(scored.visit) ?? 0), points.waitBonus),
      (l10n.isLimited, points.limitedBonus),
      (l10n.pointsFirstVisit, points.firstVisitBonus),
      (l10n.pointsRetry, points.retryBonus),
      (l10n.pointsExpedition, points.expeditionBonus),
      (l10n.pointsEarly, points.earlyBonus),
      (l10n.pointsLateNight, points.lateNightBonus),
    ];

    return _reveal([
      for (final (label, value) in rows)
        if (value > 0) _Row(label: label, value: l10n.pointsGained(value)),
      if (points.hoursConditions.isNotEmpty)
        _Row(
          label: l10n.pointsHours(
            hoursConditionsLabel(l10n, points.hoursConditions),
          ),
          value: l10n.pointsMultiplier(
            _format(hoursMultiplier(points.hoursConditions)),
          ),
        ),
    ]);
  }

  Widget _reveal(List<Widget> children) => switch (revealAt) {
    final at? => StaggeredReveal(delay: at, children: children),
    null => Column(children: children),
  };

  String _format(double multiplier) => multiplier == multiplier.roundToDouble()
      ? multiplier.toStringAsFixed(0)
      : multiplier.toString();
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          Text(value, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
