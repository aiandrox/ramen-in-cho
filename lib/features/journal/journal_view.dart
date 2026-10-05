import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/motion.dart';
import '../../theme/washi.dart';

/// 道中記の文。見出しは筆文字、本文は明朝で1文ずつ並べる。
class JournalView extends StatelessWidget {
  const JournalView({
    super.key,
    required this.lines,
    this.color,
    this.revealAt,
  });

  final List<String> lines;
  final Color? color;

  /// 指定すると、このときから1文ずつ浮かび上がらせる（着丼直後の画面の余韻）。
  final Duration? revealAt;

  /// 1文ずつ出す間隔と、1文が浮かび上がる長さ。
  static const revealStagger = Duration(milliseconds: 220);
  static const revealDuration = Duration(milliseconds: 420);

  /// [revealAt]から、[lines]をすべて出し終えるまで（見出しとその下の間も1つずつに数える）。
  static Duration revealLength(int lines) => StaggeredReveal.lengthOf(
    lines + 2,
    stagger: revealStagger,
    duration: revealDuration,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = this.color ?? Washi.ink;
    final children = [
      Text(
        l10n.journalTitle,
        style: TextStyle(fontFamily: Washi.brush, fontSize: 20, color: color),
      ),
      const SizedBox(height: 6),
      for (final line in lines)
        Text(
          line,
          style: TextStyle(
            fontFamily: Washi.mincho,
            fontSize: 15,
            height: 1.8,
            color: color,
          ),
        ),
    ];
    return switch (revealAt) {
      final at? => StaggeredReveal(
        delay: at,
        stagger: revealStagger,
        duration: revealDuration,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
      null => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    };
  }
}
