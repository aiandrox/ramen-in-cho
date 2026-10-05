import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 祝う場面の動きの長さと速さ。動きは余韻を出したい場面だけにつけ、記録までの流れには付けない。
abstract final class Motion {
  /// 並んだものを1つずつ出す間隔。
  static const stagger = Duration(milliseconds: 80);

  /// ふわっと浮かび上がる長さ。
  static const reveal = Duration(milliseconds: 280);

  /// 印を押す（上から落ちて紙に当たる）長さ。
  static const press = Duration(milliseconds: 420);

  /// 印のインクが紙ににじむ長さ。
  static const bleed = Duration(milliseconds: 450);

  /// 筆で1文字書く長さと、1文を書き終えるまでの上限。
  static const brushPerChar = Duration(milliseconds: 25);
  static const brushMax = Duration(milliseconds: 1000);

  static Duration brushDuration(String text) {
    final length = brushPerChar * text.characters.length;
    return length < brushMax ? length : brushMax;
  }
}

/// OS の「動きを減らす」が入っていれば、動かさずに最後の状態だけを見せる。
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// 1画面の演出の時計。中の [MotionBuilder] は、この時計が動き出してからの時間で動く
/// （下にスクロールしてから組み立てられた部品も、同じ時計で決まった状態になる）。
/// どこをタップしても最後の状態まで飛ばせる。ボタンは自分でタップを受けるので、すぐ押せる。
class MotionTimeline extends StatefulWidget {
  const MotionTimeline({
    super.key,
    required this.duration,
    required this.child,
    this.skipOnTap = true,
  });

  /// 演出の全体の長さ。中の部品はこれより後に終わらないようにする。
  final Duration duration;
  final Widget child;
  final bool skipOnTap;

  @override
  State<MotionTimeline> createState() => MotionTimelineState();

  static MotionTimelineState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MotionTimelineScope>()?.state;
}

class MotionTimelineState extends State<MotionTimeline>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _skipped = false;
  bool _started = false;

  Animation<double> get clock => _controller;
  Duration get duration => widget.duration;

  /// タップで飛ばしたか、動きを減らしているか（このときは印を押した手応えも出さない）。
  bool get skipped => _skipped;

  /// 最後の状態まで飛ばす。
  void skip() {
    if (_controller.isCompleted) return;
    _skipped = true;
    _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _skipped = true;
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _MotionTimelineScope(state: this, child: widget.child);
    if (!widget.skipOnTap) return scope;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: skip,
      child: scope,
    );
  }
}

class _MotionTimelineScope extends InheritedWidget {
  const _MotionTimelineScope({required this.state, required super.child});

  final MotionTimelineState state;

  @override
  bool updateShouldNotify(_MotionTimelineScope oldWidget) =>
      state != oldWidget.state;
}

/// [delay]から[duration]の間に 0→1 と進む値で組み立てる、演出の基本の部品。
/// [MotionTimeline]の中ならその時計で、外なら自分の時計で動く（外ではタップで飛ばせない）。
class MotionBuilder extends StatefulWidget {
  const MotionBuilder({
    super.key,
    this.delay = Duration.zero,
    required this.duration,
    this.curve = Curves.linear,
    required this.builder,
    this.child,
    this.onCompleted,
  });

  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;

  /// 最後まで動き終えたときに1度だけ呼ぶ。飛ばしたとき・動きを減らしているときは呼ばない。
  final VoidCallback? onCompleted;

  @override
  State<MotionBuilder> createState() => _MotionBuilderState();
}

class _MotionBuilderState extends State<MotionBuilder>
    with SingleTickerProviderStateMixin {
  MotionTimelineState? _timeline;
  AnimationController? _own;
  bool _ownSkipped = false;
  bool _done = false;

  Animation<double> get _clock => _timeline?.clock ?? _own!;

  Duration get _total =>
      _timeline?.duration ?? (widget.delay + widget.duration);

  bool get _skipped => _timeline?.skipped ?? _ownSkipped;

  double get _progress {
    final clock = _clock.value;
    if (clock >= 1) return 1;
    final elapsed = _total.inMicroseconds * clock;
    final length = widget.duration.inMicroseconds;
    final start = widget.delay.inMicroseconds;
    if (length == 0) return elapsed >= start ? 1 : 0;
    return ((elapsed - start) / length).clamp(0.0, 1.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final timeline = MotionTimeline.maybeOf(context);
    if (timeline != null) {
      if (timeline != _timeline) {
        _timeline?.clock.removeListener(_tick);
        _timeline = timeline..clock.addListener(_tick);
        _done = _progress >= 1;
      }
      return;
    }
    if (_own != null) return;
    final own = _own = AnimationController(vsync: this, duration: _total)
      ..addListener(_tick);
    if (reduceMotion(context)) {
      _ownSkipped = true;
      _done = true;
      own.value = 1;
    } else {
      own.forward();
    }
  }

  void _tick() {
    if (_done || _progress < 1) return;
    _done = true;
    if (!_skipped) widget.onCompleted?.call();
  }

  /// 外の時計で動いているときに、この部品だけを最後まで飛ばす。
  void skip() {
    final own = _own;
    if (own == null || own.isCompleted) return;
    _ownSkipped = true;
    own.value = 1;
  }

  @override
  void dispose() {
    _timeline?.clock.removeListener(_tick);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    child: widget.child,
    builder: (context, child) =>
        widget.builder(context, widget.curve.transform(_progress), child),
  );
}

/// 少し下からふわっと浮かび上がる。
class RiseIn extends StatelessWidget {
  const RiseIn({
    super.key,
    this.delay = Duration.zero,
    this.duration = Motion.reveal,
    this.offset = 8,
    required this.child,
  });

  final Duration delay;
  final Duration duration;
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) => MotionBuilder(
    delay: delay,
    duration: duration,
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, t, child) => t >= 1
        ? child!
        : Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, offset * (1 - t)),
              child: child,
            ),
          ),
  );
}

/// 縦に並べたものを、[stagger]ずつずらして1つずつ浮かび上がらせる。
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    super.key,
    this.delay = Duration.zero,
    this.stagger = Motion.stagger,
    this.duration = Motion.reveal,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    required this.children,
  });

  final Duration delay;
  final Duration stagger;
  final Duration duration;
  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;

  /// [count]個を並べ終えるまでの長さ。
  static Duration lengthOf(
    int count, {
    Duration stagger = Motion.stagger,
    Duration duration = Motion.reveal,
  }) => count == 0 ? Duration.zero : stagger * (count - 1) + duration;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: crossAxisAlignment,
    children: [
      for (final (i, child) in children.indexed)
        RiseIn(delay: delay + stagger * i, duration: duration, child: child),
    ],
  );
}

/// 印のインクが和紙ににじむように現れる（ぼかしと少しの大きさから、くっきりと落ち着く）。
class InkBleed extends StatelessWidget {
  const InkBleed({
    super.key,
    this.delay = Duration.zero,
    this.duration = Motion.bleed,
    required this.child,
  });

  final Duration delay;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => MotionBuilder(
    delay: delay,
    duration: duration,
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, t, child) {
      if (t >= 1) return child!;
      final blur = 4 * (1 - t);
      return Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 1.05 - 0.05 * t,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: child,
          ),
        ),
      );
    },
  );
}

/// 印を「ポンッ」と押す。上から落ちてきて、紙に当たったところでぴたりと止まり、強めに震わせる。
/// 押したあとに揺れたり輪が広がったりはしない。
class StampPress extends StatelessWidget {
  const StampPress({
    super.key,
    this.delay = Duration.zero,
    this.duration = Motion.press,
    this.haptic = true,
    required this.child,
  });

  final Duration delay;
  final Duration duration;

  /// 当たったときに端末を震わせるか。
  final bool haptic;
  final Widget child;

  @override
  Widget build(BuildContext context) => MotionBuilder(
    delay: delay,
    duration: duration,
    curve: Curves.easeInCubic,
    onCompleted: haptic ? HapticFeedback.heavyImpact : null,
    child: child,
    builder: (context, drop, child) {
      if (drop >= 1) return child!;
      return Opacity(
        opacity: drop == 0 ? 0 : 0.3 + 0.7 * drop,
        child: Transform.scale(scale: 1.9 - 0.9 * drop, child: child),
      );
    },
  );
}

/// 筆で書くように、1文字ずつ書き出す（1文字 25ms、長くても1秒）。
/// 書き終わる前から行の形は決めておき、文字が増えても周りが動かないようにする。
/// [MotionTimeline]の外では、タップで書き終える。
class BrushText extends StatefulWidget {
  const BrushText(
    this.text, {
    super.key,
    this.delay = Duration.zero,
    this.style,
    this.textAlign,
  });

  final String text;
  final Duration delay;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<BrushText> createState() => _BrushTextState();
}

class _BrushTextState extends State<BrushText> {
  final _motion = GlobalKey<_MotionBuilderState>();

  @override
  Widget build(BuildContext context) {
    final chars = widget.text.characters.toList();
    final color =
        widget.style?.color ?? DefaultTextStyle.of(context).style.color;
    final text = MotionBuilder(
      key: _motion,
      delay: widget.delay,
      duration: Motion.brushDuration(widget.text),
      builder: (context, t, _) {
        if (t >= 1) {
          return Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
          );
        }
        final written = t * chars.length;
        return Text.rich(
          TextSpan(
            children: [
              for (final (i, char) in chars.indexed)
                TextSpan(
                  text: char,
                  style: TextStyle(
                    color: color?.withValues(
                      alpha: (color.a * (written - i).clamp(0.0, 1.0))
                          .toDouble(),
                    ),
                  ),
                ),
            ],
          ),
          style: widget.style,
          textAlign: widget.textAlign,
        );
      },
    );
    if (MotionTimeline.maybeOf(context) != null) return text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _motion.currentState?.skip(),
      child: text,
    );
  }
}
