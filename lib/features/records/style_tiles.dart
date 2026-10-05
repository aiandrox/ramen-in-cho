import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import 'labels.dart';
import 'models.dart';

/// 系統を、椀の絵と名前の札から1つ選ぶ。選んだ札をもう一度押すと外れる。
class RamenStyleTiles extends StatelessWidget {
  const RamenStyleTiles({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final RamenStyle? selected;
  final ValueChanged<RamenStyle?> onChanged;

  static const _gap = 6.0;
  static const _minTileWidth = 56.0;

  /// 1行に並べる数。行ごとの数がそろうように、入る数の中で行数が同じなら少ない方にする。
  static int columnsFor(double width, int count) {
    final fit = math.max(1, ((width + _gap) / (_minTileWidth + _gap)).floor());
    final rows = (count / math.min(fit, count)).ceil();
    return (count / rows).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const styles = RamenStyle.values;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth, styles.length);
        final tileWidth =
            (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final style in styles)
              SizedBox(
                width: tileWidth,
                child: _StyleTile(
                  style: style,
                  label: styleLabel(l10n, style),
                  selected: selected == style,
                  onTap: () => onChanged(selected == style ? null : style),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.style,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final RamenStyle style;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Washi.page,
        clipBehavior: Clip.antiAlias,
        shape: BeveledRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(5)),
          side: BorderSide(
            color: selected ? Washi.ai : Washi.line,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                child: SizedBox.square(
                  dimension: 38,
                  child: CustomPaint(painter: StyleBowlPainter(style)),
                ),
              ),
              // 選んだ札は、名前の帯を藍で塗る（絵は和紙の地のまま見せる）。
              Container(
                width: double.infinity,
                color: selected ? Washi.ai : null,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: Washi.mincho,
                      fontSize: 13,
                      height: 1.2,
                      color: selected ? Washi.page : Washi.ink,
                    ),
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

/// 系統ごとの椀の絵。墨の線で輪郭を描き、汁や具を色で塗る。
class StyleBowlPainter extends CustomPainter {
  const StyleBowlPainter(this.style);

  final RamenStyle style;

  static const _bowl = Color(0xFFFFFDF8);
  static const _noodle = Color(0xFFE2BF55);
  static const _negi = Color(0xFF6E8F3A);
  static const _chashu = Color(0xFFA8643A);
  static const _noriColor = Color(0xFF26302A);

  static const _soups = {
    RamenStyle.shoyu: Color(0xFF7E2E16),
    RamenStyle.miso: Color(0xFFC07A33),
    RamenStyle.shio: Color(0xFFEFDDA2),
    RamenStyle.tonkotsu: Color(0xFFF3EBD8),
    RamenStyle.iekei: Color(0xFFA9692F),
    RamenStyle.jiro: Color(0xFF8A4A22),
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    // 上に何も載らない椀は、少し大きくして上の余白を詰める。
    if (style != RamenStyle.tsukemen &&
        style != RamenStyle.iekei &&
        style != RamenStyle.jiro) {
      canvas
        ..translate(0.5, 0.5)
        ..scale(1.1)
        ..translate(-0.5, -0.56);
    }
    switch (style) {
      case RamenStyle.tsukemen:
        _tsukemen(canvas);
      case RamenStyle.shirunashi:
        _bowlBody(canvas);
        _rim(canvas, fill: _noodle);
        _noodleMound(canvas, const Rect.fromLTRB(0.18, 0.34, 0.82, 0.54));
        _dot(canvas, const Offset(0.6, 0.45), 0.075, const Color(0xFFF2A62B));
        _dot(canvas, const Offset(0.36, 0.45), 0.03, _negi);
        _dot(canvas, const Offset(0.44, 0.40), 0.03, _negi);
        _dot(canvas, const Offset(0.40, 0.49), 0.03, _negi);
      case RamenStyle.other:
        _bowlBody(canvas);
        _rim(canvas, fill: Washi.desk);
        _line(canvas, const Offset(0.30, 0.16), const Offset(0.80, 0.50));
        _line(canvas, const Offset(0.40, 0.14), const Offset(0.86, 0.46));
      case RamenStyle.iekei:
        _bowlBody(canvas);
        for (var i = 0; i < 3; i++) {
          _noriSheet(canvas, 0.17 + i * 0.15, -0.20 + i * 0.16);
        }
        _rim(canvas, fill: _soups[style]!);
        _noodles(canvas, thick: true);
        _dot(canvas, const Offset(0.68, 0.47), 0.07, const Color(0xFF3F6B2A));
      case RamenStyle.jiro:
        _bowlBody(canvas);
        _rim(canvas, fill: _soups[style]!);
        _vegetableMound(canvas);
      case RamenStyle.shoyu ||
          RamenStyle.miso ||
          RamenStyle.shio ||
          RamenStyle.tonkotsu:
        _bowlBody(canvas);
        _rim(canvas, fill: _soups[style]!);
        _noodles(canvas);
        if (style == RamenStyle.miso) {
          for (final p in const [
            Offset(0.30, 0.46),
            Offset(0.70, 0.45),
            Offset(0.56, 0.52),
          ]) {
            _dot(canvas, p, 0.018, const Color(0xFF8A5220));
          }
        }
        if (style == RamenStyle.shoyu || style == RamenStyle.shio) {
          // 澄んだ汁は、表面に浮いた油の照りで見せる。
          _dot(
            canvas,
            const Offset(0.72, 0.465),
            0.035,
            const Color(0x99FFF4D6),
          );
          _dot(
            canvas,
            const Offset(0.30, 0.50),
            0.022,
            const Color(0x99FFF4D6),
          );
        }
        _dot(canvas, const Offset(0.68, 0.47), 0.03, _negi);
        _dot(canvas, const Offset(0.74, 0.50), 0.025, _negi);
    }
    canvas.restore();
  }

  static Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.045
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = Washi.ink;

  static Paint _fill(Color color) => Paint()..color = color;

  static void _fillAndStroke(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, _fill(color));
    canvas.drawPath(path, _stroke);
  }

  static void _dot(Canvas canvas, Offset center, double radius, Color color) =>
      canvas.drawCircle(center, radius, _fill(color));

  static void _line(Canvas canvas, Offset a, Offset b) =>
      canvas.drawLine(a, b, _stroke);

  /// 椀の胴と高台、胴に引いた藍の帯。口は [_rim] で描く。
  static void _bowlBody(
    Canvas canvas, {
    Rect rim = const Rect.fromLTRB(0.06, 0.35, 0.94, 0.61),
    double depth = 0.38,
  }) {
    final cx = rim.center.dx;
    final footWidth = rim.width * 0.32;
    final foot = Path()
      ..moveTo(cx - footWidth / 2, rim.center.dy + depth - 0.04)
      ..lineTo(cx - footWidth / 2 - 0.02, rim.center.dy + depth + 0.05)
      ..lineTo(cx + footWidth / 2 + 0.02, rim.center.dy + depth + 0.05)
      ..lineTo(cx + footWidth / 2, rim.center.dy + depth - 0.04)
      ..close();
    _fillAndStroke(canvas, foot, _bowl);
    final bodyRect = Rect.fromLTRB(
      rim.left,
      rim.center.dy - depth,
      rim.right,
      rim.center.dy + depth,
    );
    final body = Path()
      ..moveTo(rim.left, rim.center.dy)
      ..arcTo(bodyRect, math.pi, -math.pi, false)
      ..close();
    _fillAndStroke(canvas, body, _bowl);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawArc(
      bodyRect.deflate(0.09).shift(Offset(0, -0.02)),
      0.25,
      math.pi - 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05
        ..color = Washi.ai,
    );
    canvas.restore();
  }

  /// 椀の口と、中の汁（または麺）。
  static void _rim(
    Canvas canvas, {
    required Color fill,
    Rect rim = const Rect.fromLTRB(0.06, 0.35, 0.94, 0.61),
  }) {
    _fillAndStroke(canvas, Path()..addOval(rim), _bowl);
    final inner = Rect.fromLTRB(
      rim.left + rim.width * 0.06,
      rim.top + rim.height * 0.14,
      rim.right - rim.width * 0.06,
      rim.bottom - rim.height * 0.14,
    );
    canvas.drawOval(inner, _fill(fill));
    canvas.drawOval(inner, _stroke..strokeWidth = 0.03);
  }

  /// 汁の上に見える麺の波。
  static void _noodles(Canvas canvas, {bool thick = false}) {
    final paint = _stroke
      ..color = _noodle
      ..strokeWidth = thick ? 0.05 : 0.035;
    for (final (y, x0, x1) in const [(0.45, 0.22, 0.58), (0.51, 0.30, 0.70)]) {
      final path = Path()..moveTo(x0, y);
      const waves = 4;
      final step = (x1 - x0) / waves;
      for (var i = 0; i < waves; i++) {
        path.quadraticBezierTo(
          x0 + step * (i + 0.5),
          y + (i.isEven ? -0.03 : 0.03),
          x0 + step * (i + 1),
          y,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  /// 器の口に盛り上がった麺（汁なし・つけ麺）。
  static void _noodleMound(Canvas canvas, Rect area) {
    final mound = Path()
      ..moveTo(area.left, area.bottom)
      ..quadraticBezierTo(
        area.center.dx,
        area.top - area.height * 0.6,
        area.right,
        area.bottom,
      )
      ..close();
    _fillAndStroke(canvas, mound, _noodle);
    final wave = _stroke
      ..strokeWidth = 0.022
      ..color = const Color(0xFFA9862A);
    for (var i = 0; i < 3; i++) {
      final y = area.bottom - area.height * (0.3 + i * 0.25);
      final inset = area.width * (0.18 + i * 0.1);
      canvas.drawArc(
        Rect.fromLTRB(
          area.left + inset,
          y - 0.03,
          area.right - inset,
          y + 0.05,
        ),
        math.pi,
        math.pi,
        false,
        wave,
      );
    }
  }

  /// 椀の奥に立てかけた海苔。
  static void _noriSheet(Canvas canvas, double left, double tilt) {
    canvas.save();
    canvas.translate(left + 0.07, 0.46);
    canvas.rotate(tilt);
    final rect = Path()..addRect(const Rect.fromLTRB(-0.065, -0.36, 0.065, 0));
    _fillAndStroke(canvas, rect, _noriColor);
    canvas.restore();
  }

  /// 二郎の、高く盛った野菜と豚。
  static void _vegetableMound(Canvas canvas) {
    final mound = Path()
      ..moveTo(0.20, 0.50)
      ..cubicTo(0.22, 0.22, 0.38, 0.02, 0.50, 0.02)
      ..cubicTo(0.62, 0.02, 0.78, 0.22, 0.80, 0.50)
      ..close();
    _fillAndStroke(canvas, mound, const Color(0xFFE9EDCB));
    final sprout = _stroke
      ..strokeWidth = 0.02
      ..color = const Color(0xFF8FA65A);
    for (final (a, b) in const [
      (Offset(0.36, 0.20), Offset(0.44, 0.30)),
      (Offset(0.56, 0.12), Offset(0.62, 0.24)),
      (Offset(0.30, 0.38), Offset(0.40, 0.42)),
      (Offset(0.58, 0.34), Offset(0.68, 0.40)),
      (Offset(0.46, 0.38), Offset(0.50, 0.46)),
    ]) {
      canvas.drawLine(a, b, sprout);
    }
    final pork = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(0.66, 0.38, 0.90, 0.52),
          const Radius.circular(0.04),
        ),
      );
    _fillAndStroke(canvas, pork, _chashu);
  }

  /// つけ麺: 麺を盛った皿と、つけ汁の小さな椀。
  static void _tsukemen(Canvas canvas) {
    const plate = Rect.fromLTRB(0.0, 0.52, 0.66, 0.82);
    _fillAndStroke(canvas, Path()..addOval(plate), _bowl);
    _noodleMound(canvas, const Rect.fromLTRB(0.06, 0.28, 0.60, 0.67));
    const rim = Rect.fromLTRB(0.48, 0.46, 1.0, 0.64);
    _bowlBody(canvas, rim: rim, depth: 0.28);
    _rim(canvas, rim: rim, fill: const Color(0xFF6B3418));
  }

  @override
  bool shouldRepaint(StyleBowlPainter oldDelegate) =>
      oldDelegate.style != style;
}
