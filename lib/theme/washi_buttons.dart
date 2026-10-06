import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ink_wear.dart';
import 'washi.dart';

/// 墨色の背景の上でも沈まないよう、少し明るくした藍。
const _aiOnNight = Color(0xFF3D5278);

/// ボタンの見た目。役割ごとに、札・筆の線・印で描き分ける。
///
/// - 藍札（[ai]）: その画面でいちばん大事な決定（着丼・保存・共有など）
/// - 墨札（[sumi]）: ほかの選び方・寄り道（並ぶ・ページを見る・読み込むなど）
/// - 筆の下線（[fude]）: 控えめな寄り道の文字リンク
/// - 消し札（[keshi]）: 取り消し・撤退・削除。赤で脅かさず、灰の墨で控えめに
///
/// [night]は、墨色の背景（着丼直後の画面・並び中の帯）に置くとき。
/// 役割の違う札を横に並べるときは[FudaRow]で、高さ・幅・字の大きさをそろえる。
abstract final class FudaStyle {
  /// 札の高さ。3つの札で同じにし、縦に積んでも横に並べても大きさがそろうようにする。
  static const defaultHeight = 52.0;

  /// [FudaRow]で並べたときの字の大きさ（筆文字も明朝も同じ大きさにする）。
  static const rowFontSize = 18.0;

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(2)),
  );

  static ButtonStyle ai({
    bool night = false,
    double height = defaultHeight,
    double fontSize = 20,
    bool expand = false,
  }) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        expand ? Size.fromHeight(height) : Size(64, height),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22),
      ),
      shape: const WidgetStatePropertyAll(_shape),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? (night ? Washi.nightSoft : Washi.faded)
            : Washi.page,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? (night ? Washi.nightSoft : Washi.faded)
            : Washi.page,
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: Washi.brush,
          fontSize: fontSize,
          letterSpacing: fontSize / 8,
        ),
      ),
      backgroundBuilder: (context, states, child) =>
          _AiBackground(states: states, night: night, child: child),
    );
  }

  static ButtonStyle sumi({
    bool night = false,
    double height = defaultHeight,
    double fontSize = 16,
    bool expand = false,
  }) {
    final ink = night ? Washi.paper : Washi.ink;
    return _brushFramed(
      height: height,
      fontSize: fontSize,
      expand: expand,
      foreground: ink,
      disabled: night ? Washi.inkSoft : Washi.line,
      frame: ink,
      fill: night ? Colors.transparent : Washi.page,
      pressedFill: night ? const Color(0x22F3ECDF) : Washi.desk,
      weight: FontWeight.w600,
    );
  }

  static ButtonStyle keshi({
    bool night = false,
    double height = defaultHeight,
    double fontSize = 16,
    bool expand = false,
  }) {
    return _brushFramed(
      height: height,
      fontSize: fontSize,
      expand: expand,
      foreground: night ? Washi.nightSoft : Washi.inkSoft,
      disabled: night ? Washi.inkSoft : Washi.line,
      frame: night ? Washi.nightSoft.withValues(alpha: 0.6) : Washi.faded,
      fill: night ? const Color(0x14F3ECDF) : Washi.desk,
      pressedFill: night ? const Color(0x2EF3ECDF) : Washi.line,
      weight: FontWeight.w500,
    );
  }

  static ButtonStyle fude({bool night = false}) {
    final text = night ? Washi.paper : Washi.ink;
    final disabled = night ? Washi.inkSoft : Washi.faded;
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10),
      ),
      shape: const WidgetStatePropertyAll(_shape),
      overlayColor: WidgetStatePropertyAll(text.withValues(alpha: 0.06)),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? disabled : text,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? disabled
            : (night ? Washi.aiLight : Washi.ai),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: Washi.mincho, fontSize: 15),
      ),
      backgroundBuilder: (context, states, child) => CustomPaint(
        painter: _UnderlinePainter(
          color: states.contains(WidgetState.disabled)
              ? disabled.withValues(alpha: 0.5)
              : (night ? Washi.aiLight : Washi.ai).withValues(alpha: 0.8),
        ),
        child: child,
      ),
    );
  }

  static ButtonStyle _brushFramed({
    required double height,
    required double fontSize,
    required bool expand,
    required Color foreground,
    required Color disabled,
    required Color frame,
    required Color fill,
    required Color pressedFill,
    required FontWeight weight,
  }) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        expand ? Size.fromHeight(height) : Size(64, height),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20),
      ),
      shape: const WidgetStatePropertyAll(_shape),
      side: const WidgetStatePropertyAll(BorderSide.none),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? disabled : foreground,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? disabled : foreground,
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: Washi.mincho,
          fontSize: fontSize,
          fontWeight: weight,
        ),
      ),
      backgroundBuilder: (context, states, child) => CustomPaint(
        painter: _BrushFramePainter(
          frame: states.contains(WidgetState.disabled) ? disabled : frame,
          fill: states.contains(WidgetState.pressed) ? pressedFill : fill,
        ),
        child: child,
      ),
    );
  }
}

/// 藍染めの札。藍の地に、和紙色の細い枠（角印の枠）を内側に引き、押しむらのかすれをつける。
class _AiBackground extends StatelessWidget {
  const _AiBackground({
    required this.states,
    required this.night,
    required this.child,
  });

  final Set<WidgetState> states;
  final bool night;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final disabled = states.contains(WidgetState.disabled);
    final pressed = states.contains(WidgetState.pressed);
    final fill = disabled
        ? (night ? const Color(0x26F3ECDF) : Washi.line)
        : night
        ? (pressed ? Washi.ai : _aiOnNight)
        : (pressed ? Washi.aiDeep : Washi.ai);
    final paint = CustomPaint(
      painter: _AiPlatePainter(
        fill: fill,
        frame: disabled
            ? Colors.transparent
            : Washi.page.withValues(alpha: pressed ? 0.35 : 0.55),
      ),
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: disabled
              ? paint
              : InkWear(seed: 7, strength: 0.2, child: paint),
        ),
        ?child,
      ],
    );
  }
}

class _AiPlatePainter extends CustomPainter {
  const _AiPlatePainter({required this.fill, required this.frame});

  final Color fill;
  final Color frame;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect.deflate(0.5), Paint()..color = fill);
    canvas.drawRect(
      rect.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = frame,
    );
  }

  @override
  bool shouldRepaint(_AiPlatePainter old) =>
      old.fill != fill || old.frame != frame;
}

/// 筆で4辺を引いた枠。辺ごとに入りが太く抜けが細く、角で少しはみ出す。
class _BrushFramePainter extends CustomPainter {
  const _BrushFramePainter({required this.frame, required this.fill});

  final Color frame;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final l = 4.0, t = 4.0, r = size.width - 4, b = size.height - 4;
    canvas.drawRect(Rect.fromLTRB(l, t, r, b), Paint()..color = fill);
    final paint = Paint()..color = frame;
    brushStroke(canvas, Offset(l - 2, t), Offset(r + 3, t), 3.2, 0.9, paint);
    brushStroke(canvas, Offset(r, t - 2), Offset(r, b + 3), 2.8, 0.8, paint);
    brushStroke(canvas, Offset(l - 3, b), Offset(r + 2, b), 3.0, 1.0, paint);
    brushStroke(canvas, Offset(l, t - 1), Offset(l, b + 2), 3.4, 1.1, paint);
  }

  @override
  bool shouldRepaint(_BrushFramePainter old) =>
      old.frame != frame || old.fill != fill;
}

/// 文字の下に引いた、入りが太く抜けが細い筆の線。
class _UnderlinePainter extends CustomPainter {
  const _UnderlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 11;
    final lift = math.Random(size.width.round()).nextDouble() * 1.5;
    brushStroke(
      canvas,
      Offset(10, y),
      Offset(size.width - 8, y - lift),
      2.6,
      0.6,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) => old.color != color;
}

/// [from]から[to]へ、太さ[startWidth]から[endWidth]へ細くなる筆の線を引く。
void brushStroke(
  Canvas canvas,
  Offset from,
  Offset to,
  double startWidth,
  double endWidth,
  Paint paint,
) {
  final delta = to - from;
  final length = delta.distance;
  if (length == 0) return;
  final normal = Offset(-delta.dy, delta.dx) / length;
  final path = Path()
    ..moveTo(
      from.dx + normal.dx * startWidth / 2,
      from.dy + normal.dy * startWidth / 2,
    )
    ..lineTo(to.dx + normal.dx * endWidth / 2, to.dy + normal.dy * endWidth / 2)
    ..arcToPoint(
      to - normal * endWidth / 2,
      radius: Radius.circular(endWidth / 2),
    )
    ..lineTo(
      from.dx - normal.dx * startWidth / 2,
      from.dy - normal.dy * startWidth / 2,
    )
    ..arcToPoint(
      from + normal * startWidth / 2,
      radius: Radius.circular(startWidth / 2),
    )
    ..close();
  canvas.drawPath(path, paint);
}

/// 藍札。その画面でいちばん大事な決定に使う。
class AiFuda extends StatelessWidget {
  const AiFuda({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.night = false,
    this.expand = false,
    this.height = FudaStyle.defaultHeight,
    this.fontSize,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final bool night;
  final bool expand;
  final double height;

  /// 字の大きさ。指定しなければ、[FudaRow]の中では並びの大きさ、ほかは20。
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final style = FudaStyle.ai(
      night: night,
      height: height,
      fontSize: fontSize ?? _FudaRowScope.fontSizeOf(context) ?? 20,
      expand: expand,
    );
    return switch (icon) {
      final icon? => FilledButton.icon(
        style: style,
        onPressed: onPressed,
        icon: icon,
        label: child,
      ),
      null => FilledButton(style: style, onPressed: onPressed, child: child),
    };
  }
}

/// 墨札。ほかの選び方や、別の画面へ進む寄り道に使う。
class SumiFuda extends StatelessWidget {
  const SumiFuda({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.night = false,
    this.expand = false,
    this.height = FudaStyle.defaultHeight,
    this.fontSize,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final bool night;
  final bool expand;
  final double height;

  /// 字の大きさ。指定しなければ、[FudaRow]の中では並びの大きさ、ほかは16。
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final style = FudaStyle.sumi(
      night: night,
      height: height,
      fontSize: fontSize ?? _FudaRowScope.fontSizeOf(context) ?? 16,
      expand: expand,
    );
    return switch (icon) {
      final icon? => OutlinedButton.icon(
        style: style,
        onPressed: onPressed,
        icon: icon,
        label: child,
      ),
      null => OutlinedButton(style: style, onPressed: onPressed, child: child),
    };
  }
}

/// 消し札。取り消し・撤退・削除に使う。目立たせすぎず、押せることはわかるように。
class KeshiFuda extends StatelessWidget {
  const KeshiFuda({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.night = false,
    this.expand = false,
    this.height = FudaStyle.defaultHeight,
    this.fontSize,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final bool night;
  final bool expand;
  final double height;

  /// 字の大きさ。指定しなければ、[FudaRow]の中では並びの大きさ、ほかは16。
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final style = FudaStyle.keshi(
      night: night,
      height: height,
      fontSize: fontSize ?? _FudaRowScope.fontSizeOf(context) ?? 16,
      expand: expand,
    );
    return switch (icon) {
      final icon? => OutlinedButton.icon(
        style: style,
        onPressed: onPressed,
        icon: icon,
        label: child,
      ),
      null => OutlinedButton(style: style, onPressed: onPressed, child: child),
    };
  }
}

/// 役割の違う札（藍札・墨札・消し札）を並べるときの入れ物。
///
/// どの札も同じ幅・同じ高さにし、字の大きさもそろえる。並ぶ札の数は2〜3つまで。
/// 幅が足りないところ（確かめる窓など）では[direction]を縦にして、同じ大きさのまま積む。
class FudaRow extends StatelessWidget {
  const FudaRow({
    super.key,
    required this.children,
    this.direction = Axis.horizontal,
    this.height = FudaStyle.defaultHeight,
    this.fontSize = FudaStyle.rowFontSize,
    this.spacing = 12,
  });

  final List<Widget> children;
  final Axis direction;
  final double height;
  final double fontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final sized = [
      for (final child in children) SizedBox(height: height, child: child),
    ];
    return _FudaRowScope(
      fontSize: fontSize,
      child: switch (direction) {
        Axis.horizontal => Row(
          spacing: spacing,
          children: [for (final child in sized) Expanded(child: child)],
        ),
        Axis.vertical => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing / 1.5,
          children: sized,
        ),
      },
    );
  }
}

class _FudaRowScope extends InheritedWidget {
  const _FudaRowScope({required this.fontSize, required super.child});

  final double fontSize;

  static double? fontSizeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FudaRowScope>()?.fontSize;

  @override
  bool updateShouldNotify(_FudaRowScope oldWidget) =>
      fontSize != oldWidget.fontSize;
}

/// 筆の下線を引いた文字リンク。控えめな寄り道に使う。
class FudeLink extends StatelessWidget {
  const FudeLink({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.night = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final style = FudaStyle.fude(night: night);
    return switch (icon) {
      final icon? => TextButton.icon(
        style: style,
        onPressed: onPressed,
        icon: icon,
        label: child,
      ),
      null => TextButton(style: style, onPressed: onPressed, child: child),
    };
  }
}

/// 画面の上に浮かぶ丸いボタン。藍の丸印（[sumi]なら和紙に墨の輪）。
class SealFab extends StatelessWidget {
  const SealFab({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.sumi = false,
    this.small = false,
    this.brush = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool sumi;
  final bool small;

  /// 内側の輪を、筆でひと息に描いた輪（円相）にする。
  final bool brush;

  @override
  Widget build(BuildContext context) {
    final size = small ? 48.0 : 60.0;
    final disc = CustomPaint(
      painter: _SealDiscPainter(sumi: sumi, brush: brush),
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: sumi
                      ? disc
                      : InkWear(seed: 3, strength: 0.4, child: disc),
                ),
                IconTheme.merge(
                  data: IconThemeData(
                    size: small ? 22 : 28,
                    color: sumi ? Washi.ink : Washi.page,
                  ),
                  child: child,
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onPressed,
                      splashColor: (sumi ? Washi.ink : Washi.page).withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 手で押した印のように、縁をごくわずかに揺らした丸。
Path _wobblyCircle(Offset center, double radius) {
  final path = Path();
  const steps = 72;
  for (var i = 0; i <= steps; i++) {
    final a = 2 * math.pi * i / steps;
    // 規則的な波にならないよう、周期の違う小さな揺れを重ねる。
    final r =
        radius -
        0.5 +
        math.sin(a * 3 + 0.7) * 0.35 +
        math.sin(a * 7 + 2.1) * 0.2 +
        math.sin(a * 11 + 4.0) * 0.12;
    final p = center + Offset(math.cos(a), math.sin(a)) * r;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

class _SealDiscPainter extends CustomPainter {
  const _SealDiscPainter({required this.sumi, this.brush = false});

  final bool sumi;
  final bool brush;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (brush) {
      _paintBrushed(canvas, center, radius);
      return;
    }
    canvas.drawPath(
      _wobblyCircle(center, radius),
      Paint()..color = sumi ? Washi.page : Washi.ai,
    );
    canvas.drawCircle(
      center,
      radius - (sumi ? 3 : 5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sumi ? 2.2 : 1.2
        ..color = sumi
            ? Washi.ink.withValues(alpha: 0.85)
            : Washi.page.withValues(alpha: 0.6),
    );
  }

  /// いちばん目立たせたい「＋」。藍の丸を、外側から墨の筆でひと息に描いた輪（円相）で囲む。
  /// 左上で筆を置いて太く入り、時計回りに細く抜け、始まりの少し手前で終わる。
  void _paintBrushed(Canvas canvas, Offset center, double radius) {
    Offset at(double angle, double r) =>
        center + Offset(math.cos(angle), math.sin(angle)) * r;

    canvas.drawPath(
      _wobblyCircle(center, radius * 0.84),
      Paint()..color = Washi.ai,
    );

    final ringRadius = radius * 0.88;
    final maxWidth = radius * 0.22;
    const start = -math.pi * 0.62;
    const sweep = math.pi * 1.88;
    const steps = 90;
    final outer = <Offset>[];
    final inner = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final a = start + sweep * t;
      final width =
          maxWidth *
          (t < 0.08 ? 0.7 + t / 0.08 * 0.3 : 1 - 0.7 * ((t - 0.08) / 0.92));
      final r = ringRadius + math.sin(t * math.pi * 2) * radius * 0.015;
      outer.add(at(a, r + width / 2));
      inner.add(at(a, r - width / 2));
    }
    final ring = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (final p in outer.skip(1)) {
      ring.lineTo(p.dx, p.dy);
    }
    for (final p in inner.reversed) {
      ring.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      ring..close(),
      Paint()..color = Washi.ink.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(_SealDiscPainter old) =>
      old.sumi != sumi || old.brush != brush;
}

/// 下のタブの真ん中に置く、記録を始める大きな判子。藍の丸に淡い藍の筆の円相、和紙色の筆の字
/// （ふだんは「麺」、並んでいる最中は「着」）。
class RecordSealButton extends StatelessWidget {
  const RecordSealButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
  });

  static const size = 72.0;

  /// 下のタブの上端から下げる分。
  static const drop = 36.0;

  /// 下のタブの上にはみ出す高さ。タブの画面の下端に置くものは、この分だけ上げる。
  static const overhang = (size - drop) / 2;

  final String glyph;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: tooltip,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: InkWear(
                    seed: inkSeed('record-seal'),
                    strength: 0.6,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: _RecordSealPainter()),
                        ),
                        Text(
                          glyph,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: Washi.brush,
                            fontSize: 34,
                            height: 1,
                            color: Washi.page,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onPressed,
                      splashColor: Washi.aiLight.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordSealPainter extends CustomPainter {
  const _RecordSealPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawPath(_wobblyCircle(center, radius), Paint()..color = Washi.ai);
    _paintEnso(
      canvas,
      center,
      ringRadius: radius * 0.74,
      maxWidth: radius * 0.19,
      wobble: radius * 0.015,
      color: Washi.aiLight,
    );
  }

  @override
  bool shouldRepaint(_RecordSealPainter old) => false;
}

/// 筆でひと息に描いた輪（円相）。真上のやや左で筆を置いて丸く太く入り、時計回りに走って、
/// 左下からは穂先が割れて細い筋になり、かすれながら始まりの手前で抜ける。
void _paintEnso(
  Canvas canvas,
  Offset center, {
  required double ringRadius,
  required double maxWidth,
  required double wobble,
  required Color color,
}) {
  Offset at(double angle, double r) =>
      center + Offset(math.cos(angle), math.sin(angle)) * r;
  const start = -math.pi * 0.56;
  const sweep = math.pi * 1.86;
  const steps = 160;
  // 割れた筋が始まる位置と、筋の数。
  const splitAt = 0.5;
  const strands = 4;
  final paint = Paint()..color = color;

  double widthAt(double t) {
    if (t < 0.05) return maxWidth * (1.15 - t / 0.05 * 0.15);
    if (t < 0.45) return maxWidth * (1 - (t - 0.05) / 0.4 * 0.12);
    return maxWidth * (0.88 - (t - 0.45) / 0.55 * 0.7);
  }

  double radiusAt(double t) =>
      ringRadius +
      math.sin(t * math.pi * 2) * wobble +
      math.sin(t * math.pi * 5 + 1.3) * wobble * 0.4;

  // 規則的に見えないよう、筋と位置ごとに決まった揺らぎを作る。
  double noise(int k, int i) {
    final v = math.sin(k * 127.1 + i * 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  Path strip(List<Offset> outer, List<Offset> inner) {
    final path = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (final p in outer.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in inner.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // 太い芯。穂先が割れはじめると内側から痩せていき、筋だけが残る。
  double coreAt(double t) {
    if (t < splitAt) return 1;
    return math.max(0, 1 - (t - splitAt) / 0.3);
  }

  final outer = <Offset>[];
  final inner = <Offset>[];
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final core = coreAt(t);
    if (core <= 0) break;
    final a = start + sweep * t;
    final w = widthAt(t) * (0.35 + 0.65 * core);
    final r = radiusAt(t);
    outer.add(at(a, r + w / 2));
    inner.add(at(a, r - w / 2));
  }
  canvas.drawPath(strip(outer, inner), paint);
  canvas.drawCircle(
    (outer.last + inner.last) / 2,
    (outer.last - inner.last).distance / 2,
    paint,
  );
  // 筆を置いた頭は、外側へ少しはみ出す丸い溜まりにする。
  canvas.drawCircle(
    at(start + sweep * 0.012 - 0.04, radiusAt(0) + maxWidth * 0.05),
    maxWidth * 0.68,
    paint,
  );

  // 割れた穂先の筋。先へ行くほど細く離れ、終わり近くでところどころ途切れる。
  for (var k = 0; k < strands; k++) {
    final offset = (k + 0.5) / strands - 0.5;
    var segOuter = <Offset>[];
    var segInner = <Offset>[];
    void flush() {
      if (segOuter.length > 1) {
        canvas.drawPath(strip(segOuter, segInner), paint);
      }
      segOuter = [];
      segInner = [];
    }

    final from = (steps * splitAt).round();
    final last = steps - (k == 1 ? 0 : 4 + k * 3);
    for (var i = from; i <= last; i++) {
      final t = i / steps;
      final fade = (t - splitAt) / (1 - splitAt);
      if (noise(k, i ~/ 5) < math.max(0, fade - 0.45) * 0.6) {
        flush();
        continue;
      }
      final a = start + sweep * t;
      final w = widthAt(t);
      final r =
          radiusAt(t) +
          offset * w * (1 + fade * 0.6) +
          math.sin(t * 11 + k * 2.1) * wobble * 0.25;
      final sw = w / strands * (1.1 - fade * 0.55);
      segOuter.add(at(a, r + sw / 2));
      segInner.add(at(a, r - sw / 2));
    }
    flush();
  }
}

/// 願掛け帳で願を足す、絵馬の形のボタン。真ん中の判子（記録）と取り違えないよう、丸にしない。
class EmaFab extends StatelessWidget {
  const EmaFab({super.key, required this.tooltip, required this.onPressed});

  static const width = 60.0;
  static const height = 58.0;

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: InkWear(
                  seed: inkSeed('ema'),
                  strength: 0.5,
                  child: CustomPaint(
                    painter: const _EmaPainter(),
                    child: Padding(
                      padding: EdgeInsets.only(top: height * 0.34),
                      child: const Center(
                        child: Text(
                          '願',
                          style: TextStyle(
                            fontFamily: Washi.brush,
                            fontSize: 24,
                            height: 1,
                            color: Washi.page,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                top: height * 0.18,
                child: Material(
                  type: MaterialType.transparency,
                  shape: const _EmaBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPressed,
                    customBorder: const _EmaBorder(),
                    splashColor: Washi.page.withValues(alpha: 0.2),
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

/// 絵馬の板。屋根のように上を山形にした五角形。
Path _emaPath(Rect rect) {
  final roof = rect.height * 0.3;
  final r = rect.width * 0.06;
  return Path()
    ..moveTo(rect.center.dx, rect.top)
    ..lineTo(rect.right, rect.top + roof)
    ..lineTo(rect.right, rect.bottom - r)
    ..quadraticBezierTo(rect.right, rect.bottom, rect.right - r, rect.bottom)
    ..lineTo(rect.left + r, rect.bottom)
    ..quadraticBezierTo(rect.left, rect.bottom, rect.left, rect.bottom - r)
    ..lineTo(rect.left, rect.top + roof)
    ..close();
}

class _EmaBorder extends ShapeBorder {
  const _EmaBorder();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _emaPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _emaPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

class _EmaPainter extends CustomPainter {
  const _EmaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 板は紐の分だけ下げて描き、上に吊るし紐の輪を出す。
    final board = Rect.fromLTRB(0, size.height * 0.18, size.width, size.height);
    final path = _emaPath(board);
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = Washi.ai);
    // 屋根の下に、淡い藍の細い線で屋根板の縁を引く。
    final roofLine = board.top + board.height * 0.3 + 4;
    canvas.drawLine(
      Offset(board.left + 5, roofLine),
      Offset(board.right - 5, roofLine),
      Paint()
        ..color = Washi.aiLight.withValues(alpha: 0.8)
        ..strokeWidth = 1.2,
    );
    final cord = Paint()
      ..color = Washi.ai
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final top = board.top + board.height * 0.12;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.38, top)
        ..quadraticBezierTo(
          size.width * 0.5,
          -size.height * 0.08,
          size.width * 0.62,
          top,
        ),
      cord,
    );
  }

  @override
  bool shouldRepaint(_EmaPainter old) => false;
}
