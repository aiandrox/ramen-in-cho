import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/ink_wear.dart';
import '../../theme/washi.dart';
import '../prefecture/regions.dart';
import '../records/models.dart';
import '../scoring/rank_labels.dart';
import '../scoring/ranks.dart';
import '../scoring/points.dart';
import 'inkan.dart';
import 'region_frame.dart';

/// 印の真ん中に書く、系統を表す漢字1〜2文字。系統をつけていない記録は「拉麺」。
String inkanStyleName(AppLocalizations l10n, RamenStyle? style) =>
    switch (style) {
      RamenStyle.shoyu => l10n.inkanStyleShoyu,
      RamenStyle.miso => l10n.inkanStyleMiso,
      RamenStyle.shio => l10n.inkanStyleShio,
      RamenStyle.tonkotsu => l10n.inkanStyleTonkotsu,
      RamenStyle.iekei => l10n.inkanStyleIekei,
      RamenStyle.jiro => l10n.inkanStyleJiro,
      RamenStyle.tsukemen => l10n.inkanStyleTsukemen,
      RamenStyle.shirunashi => l10n.inkanStyleShirunashi,
      RamenStyle.other => l10n.inkanStyleOther,
      null => l10n.inkanNoStyle,
    };

/// 「令和八年」「十月一日」の2行。元年は「元」と書く。
String kanjiEraDate(AppLocalizations l10n, DateTime date) {
  final (era, year) = japaneseEra(date);
  return l10n.kanjiEraDate(
    switch (era) {
      Era.heisei => l10n.eraHeisei,
      Era.reiwa => l10n.eraReiwa,
    },
    year == 1 ? l10n.eraFirstYear : kanjiNumber(year),
    kanjiNumber(date.month),
    kanjiNumber(date.day),
  );
}

/// 1杯ごとの印。上に格（再挑戦成功なら「雪辱」も）、真ん中に系統の漢字、下に日付。
/// 都道府県のわかる店は外枠の形を地方ごとに、海外の店は羅針盤の形に変える（格の飾りはその上に重ねる）。
class InkanStamp extends StatelessWidget {
  const InkanStamp({super.key, required this.scored, this.size = 84});

  final ScoredVisit scored;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visit = scored.visit;
    final shape = inkanShapeFor(scored);
    final date = kanjiEraDate(l10n, visit.eatenAt);
    final isRetreat = shape == InkanShape.retreat;
    final prefecture = scored.prefecture;
    final frame = scored.isOverseas
        ? SealFrame.overseas
        : prefecture == null
        ? null
        : sealFrameFor(prefecture);
    final color = switch (shape) {
      InkanShape.retreat => Washi.faded,
      InkanShape.filled => Washi.page,
      _ => Washi.shu,
    };
    // 上に格（良・秀・妙・極）。再挑戦成功なら「雪辱」も添える。
    final rank = shopRankLabel(l10n, shopRankFor(scored.points.total));
    final top = isRetreat
        ? null
        : scored.isRetrySuccess
        ? l10n.inkanTop(rank, l10n.inkanRetry)
        : rank;
    final center = isRetreat
        ? l10n.inkanRetreat
        : inkanStyleName(l10n, visit.style);
    // 撤退の印は灰色の地に文字を透明に抜く（下の紙が見える）。
    final knockout = isRetreat ? (Paint()..blendMode = BlendMode.dstOut) : null;
    final small = TextStyle(
      fontFamily: Washi.brush,
      fontSize: math.max(8, size * 0.13),
      color: knockout == null ? color : null,
      foreground: knockout,
      height: 0.95,
    );

    // 印の中の文字どうしは詰めて組む。
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (top != null)
          _fit(
            size * 0.5,
            Text(
              top,
              maxLines: 1,
              style: small.copyWith(
                fontSize: size * 0.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        // 円の真ん中がいちばん広いので、系統名はほかより幅を広くとる。
        if (!isRetreat && visit.style == RamenStyle.tsukemen)
          // かなと漢字を同じ大きさで並べると釣り合わないので、小さな「つけ」を縦に組んで「麺」の左に添える。
          _fit(
            size * 0.7,
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 細いかなが「麺」に負けないよう、太くして少し横長に潰す。
                    for (final kana in l10n.inkanStyleTsukemenKana.characters)
                      Transform.scale(
                        scaleX: 1.2,
                        scaleY: 0.86,
                        child: Text(
                          kana,
                          style: small.copyWith(
                            fontSize: size * 0.15,
                            fontWeight: FontWeight.w700,
                            height: 0.92,
                            // 合成の太字だけでは細いので、同じ色を少しずらして重ねて太らせる。
                            shadows: [
                              for (final dx in [-1.0, 1.0])
                                Shadow(
                                  color: color,
                                  offset: Offset(dx * size * 0.005, 0),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: size * 0.025),
                Text(
                  l10n.inkanStyleTsukemenMain,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: Washi.brush,
                    fontSize: size * 0.34,
                    color: knockout == null ? color : null,
                    foreground: knockout,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          )
        else
          _fit(
            size * 0.7,
            Text(
              center,
              maxLines: 1,
              style: TextStyle(
                fontFamily: Washi.brush,
                fontSize: size * 0.34,
                color: knockout == null ? color : null,
                foreground: knockout,
                height: 1.0,
              ),
            ),
          ),
        // 丸い印は下ほど狭いので、日付の幅を角印より狭くする。
        _fit(
          size * (shape == InkanShape.square ? 0.6 : 0.5),
          Text(date, style: small, maxLines: 2, textAlign: TextAlign.center),
        ),
      ],
    );

    return Semantics(
      label: [
        center,
        date,
        ?(scored.isOverseas ? l10n.inkanOverseas : prefecture),
      ].join(' '),
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: inkanAngle(visit.id),
          child: InkWear(
            seed: inkSeed(visit.id),
            // 極は朱で塗りつぶすので、かすれが強いと白い日付が読みにくい。
            strength: shape == InkanShape.filled ? 0.5 : 1,
            child: SizedBox.square(
              dimension: size,
              child: CustomPaint(
                painter: frame == null
                    ? _InkanPainter(shape)
                    : RegionalInkanPainter(frame, shape),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    // 丸い印は上下に余裕があるので、格の字を足しても他の字は小さくしない。
                    padding: EdgeInsets.symmetric(
                      horizontal: size * (frame == null ? 0.08 : 0.16),
                      vertical: size * (frame == null ? 0.04 : 0.18),
                    ),
                    child: content,
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

Widget _fit(double width, Widget child) => SizedBox(
  width: width,
  child: FittedBox(fit: BoxFit.scaleDown, child: child),
);

class _InkanPainter extends CustomPainter {
  const _InkanPainter(this.shape);

  final InkanShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final stroke = radius * 0.07;
    Paint line(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color.withValues(alpha: 0.92);

    final ink = Washi.shu.withValues(alpha: 0.92);
    Paint fill([Color? color]) => Paint()..color = color ?? ink;

    switch (shape) {
      // 良: 細い丸だけ。
      case InkanShape.circle:
        canvas.drawCircle(
          center,
          radius - stroke * 1.3,
          line(Washi.shu, stroke * 1.7),
        );
      // 上: 二重丸のあいだに、小さな点を一周並べる。
      case InkanShape.doubleCircle:
        canvas.drawCircle(center, radius - stroke, line(Washi.shu, stroke));
        canvas.drawCircle(
          center,
          radius - stroke * 3.2,
          line(Washi.shu, stroke * 0.6),
        );
        final dots = Path();
        const count = 28;
        for (var i = 0; i < count; i++) {
          final a = 2 * math.pi * i / count;
          dots.addOval(
            Rect.fromCircle(
              center:
                  center +
                  Offset(math.cos(a), math.sin(a)) * (radius - stroke * 2.1),
              radius: stroke * 0.38,
            ),
          );
        }
        canvas.drawPath(dots, fill());
      // 特: 角の二重枠に、四隅の菱形と、内側の細い点線を足す。
      case InkanShape.square:
        final outer = Rect.fromCircle(center: center, radius: radius * 0.86);
        final corner = Radius.circular(radius * 0.08);
        canvas.drawRRect(
          RRect.fromRectAndRadius(outer, corner),
          line(Washi.shu, stroke * 1.2),
        );
        final inner = outer.deflate(stroke * 2);
        canvas.drawRect(inner, line(Washi.shu, stroke * 0.55));
        final dashed = Path();
        final dash = inner.deflate(stroke * 1.2);
        const steps = 14;
        for (var i = 0; i < steps; i++) {
          final t0 = i / steps;
          final t1 = (i + 0.5) / steps;
          for (final (from, to) in [
            (dash.topLeft, dash.topRight),
            (dash.topRight, dash.bottomRight),
            (dash.bottomRight, dash.bottomLeft),
            (dash.bottomLeft, dash.topLeft),
          ]) {
            dashed
              ..moveTo(
                from.dx + (to.dx - from.dx) * t0,
                from.dy + (to.dy - from.dy) * t0,
              )
              ..lineTo(
                from.dx + (to.dx - from.dx) * t1,
                from.dy + (to.dy - from.dy) * t1,
              );
          }
        }
        canvas.drawPath(dashed, line(Washi.shu, stroke * 0.35));
        final diamonds = Path();
        final d = stroke * 1.6;
        for (final c in [
          outer.topLeft,
          outer.topRight,
          outer.bottomLeft,
          outer.bottomRight,
        ]) {
          diamonds
            ..moveTo(c.dx, c.dy - d)
            ..lineTo(c.dx + d, c.dy)
            ..lineTo(c.dx, c.dy + d)
            ..lineTo(c.dx - d, c.dy)
            ..close();
        }
        canvas.drawPath(diamonds, fill());
      // 極: 菊の花びらのような縁取りの中を朱で塗り、金色の細い輪を重ねる。
      case InkanShape.filled:
        const petals = 16;
        final flower = Path();
        final petalR = radius * 0.15;
        // 外側に点の輪を散らすぶん、花びらを少し内側に。
        final ringR = radius * 0.86 - petalR;
        for (var i = 0; i < petals; i++) {
          final a = 2 * math.pi * i / petals;
          flower.addOval(
            Rect.fromCircle(
              center: center + Offset(math.cos(a), math.sin(a)) * ringR,
              radius: petalR,
            ),
          );
        }
        flower.addOval(Rect.fromCircle(center: center, radius: ringR));
        canvas.drawPath(flower, fill());
        canvas.drawCircle(
          center,
          ringR - stroke * 0.6,
          line(const Color(0xFFE8C77A), stroke * 0.45),
        );
        canvas.drawCircle(
          center,
          ringR - stroke * 1.8,
          line(Washi.page, stroke * 0.3),
        );
        final dots = Path();
        const count = 32;
        for (var i = 0; i < count; i++) {
          final a = 2 * math.pi * (i + 0.5) / count;
          dots.addOval(
            Rect.fromCircle(
              center:
                  center +
                  Offset(math.cos(a), math.sin(a)) * (radius - stroke * 0.6),
              radius: stroke * 0.38,
            ),
          );
        }
        canvas.drawPath(dots, fill());
      case InkanShape.retreat:
        canvas.drawCircle(
          center,
          radius - stroke * 0.6,
          fill(Washi.faded.withValues(alpha: 0.85)),
        );
    }
  }

  @override
  bool shouldRepaint(_InkanPainter oldDelegate) => oldDelegate.shape != shape;
}

/// 地方の外枠に、格の飾り（良＝細い枠・秀＝二重枠と点の輪・妙＝三重枠と点線と四隅の菱形・極＝朱塗りと金の輪）を重ねる。
class RegionalInkanPainter extends CustomPainter {
  const RegionalInkanPainter(this.frame, this.shape);

  final SealFrame frame;
  final InkanShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final stroke = radius * 0.07;
    Path outline(double scale) =>
        sealFramePath(frame, center, radius, scale: scale);
    Paint line(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.92);
    final ink = Washi.shu.withValues(alpha: 0.92);
    Paint fill([Color? color]) => Paint()..color = color ?? ink;
    // 外枠に沿って、[count]個の点を等しい間隔で並べる。
    Path dotsAlong(double scale, int count, double dotRadius) {
      final dots = Path();
      final metric = outline(scale).computeMetrics().first;
      for (var i = 0; i < count; i++) {
        final tangent = metric.getTangentForOffset(
          metric.length * (i + 0.5) / count,
        );
        if (tangent == null) continue;
        dots.addOval(
          Rect.fromCircle(center: tangent.position, radius: dotRadius),
        );
      }
      return dots;
    }

    switch (shape) {
      case InkanShape.circle:
        canvas.drawPath(outline(0.97), line(Washi.shu, stroke * 1.7));
      case InkanShape.doubleCircle:
        canvas.drawPath(outline(0.99), line(Washi.shu, stroke));
        canvas.drawPath(outline(0.83), line(Washi.shu, stroke * 0.6));
        canvas.drawPath(dotsAlong(0.91, 28, stroke * 0.38), fill());
      case InkanShape.square:
        canvas.drawPath(outline(0.99), line(Washi.shu, stroke * 1.2));
        canvas.drawPath(outline(0.88), line(Washi.shu, stroke * 0.55));
        final dashes = Path();
        final metric = outline(0.8).computeMetrics().first;
        const steps = 48;
        for (var i = 0; i < steps; i++) {
          dashes.addPath(
            metric.extractPath(
              metric.length * i / steps,
              metric.length * (i + 0.5) / steps,
            ),
            Offset.zero,
          );
        }
        canvas.drawPath(dashes, line(Washi.shu, stroke * 0.35));
        final diamonds = Path();
        final d = stroke * 1.4;
        for (final turn in [0.125, 0.375, 0.625, 0.875]) {
          final c = sealFramePoint(frame, center, radius, turn, 0.99);
          diamonds
            ..moveTo(c.dx, c.dy - d)
            ..lineTo(c.dx + d, c.dy)
            ..lineTo(c.dx, c.dy + d)
            ..lineTo(c.dx - d, c.dy)
            ..close();
        }
        canvas.drawPath(diamonds, fill());
      case InkanShape.filled:
        canvas.drawPath(outline(0.95), fill());
        canvas.drawPath(
          outline(0.88),
          line(const Color(0xFFE8C77A), stroke * 0.45),
        );
        canvas.drawPath(outline(0.81), line(Washi.page, stroke * 0.3));
        canvas.drawPath(dotsAlong(1.04, 32, stroke * 0.34), fill());
      case InkanShape.retreat:
        canvas.drawPath(
          outline(0.99),
          fill(Washi.faded.withValues(alpha: 0.85)),
        );
    }
  }

  @override
  bool shouldRepaint(RegionalInkanPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.shape != shape;
}

/// まだ食べていない都道府県の印の場所（薄い外枠に短い名前）。
class BlankPrefectureSeal extends StatelessWidget {
  const BlankPrefectureSeal({
    super.key,
    required this.prefecture,
    this.size = 64,
  });

  final String prefecture;
  final double size;

  @override
  Widget build(BuildContext context) {
    final frame = sealFrameFor(prefecture);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: frame == null ? null : _BlankFramePainter(frame),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(size * 0.18),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                shortPrefectureName(prefecture),
                style: TextStyle(
                  fontFamily: Washi.brush,
                  fontSize: size * 0.2,
                  color: Washi.faded,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlankFramePainter extends CustomPainter {
  const _BlankFramePainter(this.frame);

  final SealFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    canvas.drawPath(
      sealFramePath(frame, size.center(Offset.zero), radius, scale: 0.97),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.05
        ..color = Washi.faded.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_BlankFramePainter oldDelegate) =>
      oldDelegate.frame != frame;
}

/// 段位の印（四角い朱の枠に段位の名前）。
class RankSeal extends StatelessWidget {
  const RankSeal({
    super.key,
    required this.label,
    this.fontSize = 16,
    this.color = Washi.shu,
  });

  final String label;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -5 * math.pi / 180,
      child: InkWear(
        seed: inkSeed(label),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: fontSize * 0.45,
              vertical: fontSize * 0.25,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: Washi.brush,
                fontSize: fontSize,
                color: color,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
