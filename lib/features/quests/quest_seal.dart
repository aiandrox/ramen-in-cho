import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inkan/inkan.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/ink_wear.dart';
import '../../theme/washi.dart';
import '../inkan/inkan_stamp.dart';
import 'quests.dart';

const _daiji = ['壱', '弐', '参', '肆', '伍', '陸', '漆', '捌', '玖', '拾'];

/// 段を大字（壱・弐・参…）で書く。範囲外は数字のまま。
String daijiNumber(int value) =>
    value >= 1 && value <= _daiji.length ? _daiji[value - 1] : '$value';

/// 型と秘伝の印。型は段を角印に、秘伝は会得を丸印に。未達成は灰色の点線。
/// 最高段まで上がった型は朱で塗りつぶす。
class QuestSeal extends StatelessWidget {
  const QuestSeal({
    super.key,
    required this.quest,
    required this.level,
    this.size = 52,
    this.achievedAt,
  });

  final Quest quest;
  final int level;
  final double size;

  /// 秘伝の印に入れる、会得した日。
  final DateTime? achievedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSpot = quest.kind == QuestKind.spot;
    final design = quest.seal;
    if (isSpot && level > 0 && design != null) {
      return Semantics(
        label: quest.title,
        child: ExcludeSemantics(
          child: Transform.rotate(
            angle: -6 * math.pi / 180,
            child: InkWear(
              seed: inkSeed('${quest.id}:$level'),
              child: SizedBox.square(
                dimension: size,
                child: CustomPaint(
                  painter: _SpotSealPainter(design.shape),
                  // 三角とにんにくは内側が下に寄っているので、字を下げる。三角は下ほど狭いので、日付を小さくする。
                  child: Align(
                    alignment: switch (design.shape) {
                      QuestSealShape.triangle => const Alignment(0, -0.02),
                      QuestSealShape.garlic => const Alignment(0, 0.18),
                      _ => Alignment.center,
                    },
                    child: Transform.scale(
                      scale: 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 2文字の字は縦に重ねて、印の中に収める。
                          for (final char in design.glyph.characters)
                            Text(
                              char,
                              style: TextStyle(
                                fontFamily: Washi.brush,
                                fontSize:
                                    size *
                                    (achievedAt == null ? 0.46 : 0.36) *
                                    (design.shape == QuestSealShape.triangle
                                        ? 0.9
                                        : 1) /
                                    (design.glyph.characters.length > 1
                                        ? 1.7
                                        : 1),
                                height: 1.0,
                                color: Washi.shu,
                              ),
                            ),
                          if (achievedAt case final at?)
                            SizedBox(
                              // 菱形と花は内側が狭いので、日付を小さくする。
                              width:
                                  size *
                                  switch (design.shape) {
                                    QuestSealShape.triangle => 0.34,
                                    QuestSealShape.diamond ||
                                    QuestSealShape.flower => 0.38,
                                    _ => 0.5,
                                  },
                              child: FittedBox(
                                child: Text(
                                  kanjiEraDate(l10n, at),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: Washi.brush,
                                    fontSize: size * 0.12,
                                    height: 0.95,
                                    color: Washi.shu,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final locked = level <= 0;
    final isMax = !isSpot && level >= quest.maxLevel;
    final color = locked ? Washi.faded : Washi.shu;
    final text = locked
        ? l10n.questLocked
        : isSpot
        ? l10n.questCleared
        : daijiNumber(level);
    final shape = isSpot
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));

    return Semantics(
      label: locked
          ? l10n.questLocked
          : isSpot
          ? l10n.questCleared
          : l10n.questLevel(kanjiNumber(level)),
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: (locked ? 0 : -6) * math.pi / 180,
          child: InkWear(
            seed: inkSeed('${quest.id}:$level'),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: isMax ? Washi.shu : Colors.transparent,
                shape: shape.copyWith(
                  side: BorderSide(
                    color: color,
                    width: locked ? 1.5 : size * 0.06,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(size * 0.12),
                child: FittedBox(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: Washi.brush,
                      fontSize: size * 0.5,
                      height: 1.1,
                      color: isMax ? Washi.page : color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 秘伝ごとの印の枠。
class _SpotSealPainter extends CustomPainter {
  const _SpotSealPainter(this.shape);

  final QuestSealShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final w = r * 0.09;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = Washi.shu.withValues(alpha: 0.92);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.5
      ..color = Washi.shu.withValues(alpha: 0.92);
    final fill = Paint()..color = Washi.shu.withValues(alpha: 0.92);

    Path polygon(int sides, double radius, {double rotate = 0}) {
      final path = Path();
      for (var i = 0; i < sides; i++) {
        final a = rotate + 2 * math.pi * i / sides - math.pi / 2;
        final p = c + Offset(math.cos(a), math.sin(a)) * radius;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    switch (shape) {
      // 8つの系統を表す、8つの小さな丸の輪。
      case QuestSealShape.eightRing:
        canvas.drawCircle(c, r - w * 3.2, line);
        for (var i = 0; i < 8; i++) {
          final a = 2 * math.pi * i / 8 - math.pi / 2;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * (r - w * 1.3),
            w * 1.1,
            fill,
          );
        }
      case QuestSealShape.doubleCircle:
        canvas.drawCircle(c, r - w, line);
        canvas.drawCircle(c, r - w * 2.8, thin);
      case QuestSealShape.square:
        final rect = Rect.fromCircle(center: c, radius: r * 0.82);
        canvas.drawRect(rect, line);
        canvas.drawRect(rect.deflate(w * 1.8), thin);
      case QuestSealShape.octagon:
        canvas.drawPath(polygon(8, r - w, rotate: math.pi / 8), line);
        canvas.drawPath(polygon(8, r - w * 2.8, rotate: math.pi / 8), thin);
      case QuestSealShape.diamond:
        canvas.drawPath(polygon(4, r - w * 0.5), line);
        canvas.drawPath(polygon(4, r - w * 2.6), thin);
      case QuestSealShape.hexagon:
        canvas.drawPath(polygon(6, r - w), line);
        canvas.drawPath(polygon(6, r - w * 2.8), thin);
      case QuestSealShape.flower:
        const petals = 8;
        final petalR = r * 0.24;
        final ringR = r - petalR - w * 0.5;
        for (var i = 0; i < petals; i++) {
          final a = 2 * math.pi * i / petals;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * ringR,
            petalR,
            thin,
          );
        }
        canvas.drawCircle(c, ringR, line);
      case QuestSealShape.dottedRing:
        canvas.drawCircle(c, r - w * 2.4, line);
        final dots = Path();
        const count = 20;
        for (var i = 0; i < count; i++) {
          final a = 2 * math.pi * i / count;
          dots.addOval(
            Rect.fromCircle(
              center: c + Offset(math.cos(a), math.sin(a)) * (r - w * 0.6),
              radius: w * 0.5,
            ),
          );
        }
        canvas.drawPath(dots, fill);
      case QuestSealShape.castle:
        // 城壁のような凸凹の上辺をもつ角印。
        final rect = Rect.fromCircle(center: c, radius: r * 0.8);
        final path = Path()..moveTo(rect.left, rect.top);
        const merlons = 5;
        final step = rect.width / (merlons * 2 - 1);
        for (var i = 0; i < merlons * 2 - 1; i++) {
          final x = rect.left + step * (i + 1);
          final y = i.isEven ? rect.top : rect.top + step * 0.8;
          path
            ..lineTo(rect.left + step * i, y)
            ..lineTo(x, y);
        }
        path
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(path, line);
        canvas.drawRect(
          Rect.fromLTRB(
            rect.left + w * 1.8,
            rect.top + step * 0.8 + w * 1.8,
            rect.right - w * 1.8,
            rect.bottom - w * 1.8,
          ),
          thin,
        );
      // 朝日のような、短い光の筋を周りにもつ丸。
      case QuestSealShape.sunburst:
        canvas.drawCircle(c, r - w * 2.6, line);
        const rays = 16;
        for (var i = 0; i < rays; i++) {
          final a = 2 * math.pi * i / rays;
          final dir = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(
            c + dir * (r - w * 1.6),
            c + dir * (r - w * 0.2),
            thin,
          );
        }
      // 三日月を左上に抱いた丸。
      case QuestSealShape.crescent:
        canvas.drawCircle(c, r - w, line);
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: r - w * 2.2)),
          Path()..addOval(
            Rect.fromCircle(
              center: c + Offset(r * 0.1, r * 0.1),
              radius: r - w * 2.4,
            ),
          ),
        );
        canvas.drawPath(moon, fill);
      case QuestSealShape.triangle:
        canvas.drawPath(polygon(3, r - w * 0.2), line);
      // 縦長の角丸の二重線。
      case QuestSealShape.pill:
        final rect = Rect.fromCenter(
          center: c,
          width: r * 1.3,
          height: r * 1.9,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(r * 0.65)),
          line,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.deflate(w * 1.8),
            Radius.circular(r * 0.65 - w * 1.8),
          ),
          thin,
        );
      // 一筋の太い輪。
      case QuestSealShape.boldRing:
        canvas.drawCircle(c, r - w * 1.4, line..strokeWidth = w * 2.4);
      case QuestSealShape.dashedRing:
        const dashes = 18;
        final rect = Rect.fromCircle(center: c, radius: r - w);
        for (var i = 0; i < dashes; i++) {
          canvas.drawArc(
            rect,
            2 * math.pi * i / dashes,
            math.pi / dashes,
            false,
            line,
          );
        }
        canvas.drawCircle(c, r - w * 2.8, thin);
      case QuestSealShape.pentagon:
        canvas.drawPath(polygon(5, r - w * 0.4), line);
        canvas.drawPath(polygon(5, r - w * 2.8), thin);
      case QuestSealShape.star:
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final a = 2 * math.pi * i / 10 - math.pi / 2;
          final radius = i.isEven ? r - w * 0.3 : r * 0.72;
          final p = c + Offset(math.cos(a), math.sin(a)) * radius;
          i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(star..close(), line);
        canvas.drawCircle(c, r * 0.58, thin);
      // にんにくの玉（下がふっくら丸く、上がとがる。縁に沿って片の筋、下に根）。
      case QuestSealShape.garlic:
        Offset at(double x, double y) => c + Offset(x * r, y * r);
        final tip = at(0, -0.98);
        final bulb = Path()
          ..moveTo(tip.dx, tip.dy)
          ..cubicTo(
            at(0.14, -0.7).dx,
            at(0.14, -0.7).dy,
            at(0.98, -0.42).dx,
            at(0.98, -0.42).dy,
            at(0.92, 0.3).dx,
            at(0.92, 0.3).dy,
          )
          ..cubicTo(
            at(0.88, 0.8).dx,
            at(0.88, 0.8).dy,
            at(0.45, 0.9).dx,
            at(0.45, 0.9).dy,
            at(0, 0.9).dx,
            at(0, 0.9).dy,
          )
          ..cubicTo(
            at(-0.45, 0.9).dx,
            at(-0.45, 0.9).dy,
            at(-0.88, 0.8).dx,
            at(-0.88, 0.8).dy,
            at(-0.92, 0.3).dx,
            at(-0.92, 0.3).dy,
          )
          ..cubicTo(
            at(-0.98, -0.42).dx,
            at(-0.98, -0.42).dy,
            at(-0.14, -0.7).dx,
            at(-0.14, -0.7).dy,
            tip.dx,
            tip.dy,
          )
          ..close();
        canvas.drawPath(bulb, line);
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(at(side * 0.08, -0.78).dx, at(side * 0.08, -0.78).dy)
              ..quadraticBezierTo(
                at(side * 0.86, -0.3).dx,
                at(side * 0.86, -0.3).dy,
                at(side * 0.72, 0.5).dx,
                at(side * 0.72, 0.5).dy,
              ),
            thin,
          );
        }
        for (final x in [-0.12, 0.0, 0.12]) {
          canvas.drawLine(at(x * 0.6, 0.92), at(x, 1.0), thin);
        }
      // 東西南北に小さな三角をもつ丸（方位磁石）。
      case QuestSealShape.compass:
        canvas.drawCircle(c, r - w * 2.4, line);
        for (var i = 0; i < 4; i++) {
          final a = math.pi / 2 * i - math.pi / 2;
          final dir = Offset(math.cos(a), math.sin(a));
          final side = Offset(-dir.dy, dir.dx);
          final tip = c + dir * r;
          final base = c + dir * (r - w * 2.6);
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo((base + side * w * 1.2).dx, (base + side * w * 1.2).dy)
              ..lineTo((base - side * w * 1.2).dx, (base - side * w * 1.2).dy)
              ..close(),
            fill,
          );
        }
      // 四隅に点を打った角丸の角印。
      case QuestSealShape.cornerDots:
        final rect = Rect.fromCircle(center: c, radius: r * 0.78);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(r * 0.2)),
          line,
        );
        for (final corner in [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight,
        ]) {
          canvas.drawCircle(corner + (c - corner) * 0.18, w * 0.9, fill);
        }
      // 波打つ縁の丸（水の流れ）。
      case QuestSealShape.wave:
        final wave = Path();
        const steps = 120;
        for (var i = 0; i <= steps; i++) {
          final a = 2 * math.pi * i / steps;
          final radius = r - w * 1.6 + math.sin(a * 10) * w * 0.9;
          final p = c + Offset(math.cos(a), math.sin(a)) * radius;
          i == 0 ? wave.moveTo(p.dx, p.dy) : wave.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(wave..close(), line);
        canvas.drawCircle(c, r - w * 3.6, thin);
    }
  }

  @override
  bool shouldRepaint(_SpotSealPainter oldDelegate) =>
      oldDelegate.shape != shape;
}
