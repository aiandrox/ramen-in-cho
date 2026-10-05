import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/ink_wear.dart';
import '../../theme/washi.dart';
import 'app_tab.dart';

/// 下のタブのアイコン。手で押した印のような枠に、タブごとの小さな絵を描く。
/// 選んでいるときは藍で塗り、絵を和紙色で抜く。
class TabSeal extends StatelessWidget {
  const TabSeal({
    super.key,
    required this.tab,
    required this.selected,
    this.size = 32,
  });

  final AppTab tab;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWear(
      seed: inkSeed('tab-${tab.name}'),
      strength: 0.32,
      child: CustomPaint(
        size: Size.square(size),
        painter: _TabSealPainter(tab, selected),
      ),
    );
  }
}

class _TabSealPainter extends CustomPainter {
  _TabSealPainter(this.tab, this.selected);

  final AppTab tab;
  final bool selected;

  Color get _fg => selected ? Washi.page : Washi.inkSoft;

  @override
  void paint(Canvas canvas, Size size) {
    // 32×32 の升目で描き、実際の大きさに合わせて拡げる。
    canvas.scale(size.width / 32, size.height / 32);
    final frame = _wobblySquare(inkSeed('frame-${tab.name}'));
    if (selected) {
      canvas.drawPath(frame, Paint()..color = Washi.ai);
    } else {
      canvas.drawPath(
        frame,
        Paint()
          ..color = Washi.inkSoft
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeJoin = StrokeJoin.round,
      );
    }
    // 絵は別の層に描き、抜くところ（題箋・文字など）を消して下の地を見せる。
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 32, 32), Paint());
    switch (tab) {
      case AppTab.records:
        _book(canvas);
      case AppTab.wishes:
        _ema(canvas);
      case AppTab.shugyo:
        _scroll(canvas);
      case AppTab.map:
        _map(canvas);
    }
    canvas.restore();
  }

  Paint get _fill => Paint()..color = _fg;

  Paint _line(double width) => Paint()
    ..color = _fg
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final _clear = Paint()..blendMode = BlendMode.clear;

  static Paint _clearLine(double width) => Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// 手で押した印の、少しゆがんだ角丸の四角。
  static Path _wobblySquare(int seed) {
    final random = math.Random(seed);
    double j() => (random.nextDouble() - 0.5) * 1.1;
    const lo = 2.0, hi = 30.0, r = 4.0;
    final corners = [
      Offset(lo + j(), lo + j()),
      Offset(hi + j(), lo + j()),
      Offset(hi + j(), hi + j()),
      Offset(lo + j(), hi + j()),
    ];
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      final c = corners[(i + 2) % 4];
      final ab = b - a;
      final bc = c - b;
      final start = a + ab / ab.distance * r;
      final end = b - ab / ab.distance * r;
      final mid = Offset.lerp(start, end, 0.5)! + Offset(j() * 0.6, j() * 0.6);
      if (i == 0) path.moveTo(start.dx, start.dy);
      path
        ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy)
        ..quadraticBezierTo(
          b.dx,
          b.dy,
          (b + bc / bc.distance * r).dx,
          (b + bc / bc.distance * r).dy,
        );
    }
    return path..close();
  }

  /// 御朱印帳: 閉じた表紙に題箋、下に蛇腹に折った頁の端がのぞく。
  void _book(Canvas canvas) {
    final cover = RRect.fromLTRBR(9, 5.5, 23.5, 22, const Radius.circular(1.2));
    canvas.drawRRect(cover, _fill);
    // 題箋（縦長の札）を抜き、中に1画を残す。
    canvas.drawRect(const Rect.fromLTRB(11.2, 7.8, 15, 17.5), _clear);
    canvas.drawLine(
      const Offset(13.1, 9.8),
      const Offset(13.1, 15.5),
      _line(1.1),
    );
    // 蛇腹の頁（ジグザグ）。
    final pleats = Path()..moveTo(9.5, 24.5);
    for (var i = 0; i < 4; i++) {
      final x = 9.5 + i * 3.5;
      pleats
        ..lineTo(x + 1.75, 27)
        ..lineTo(x + 3.5, 24.5);
    }
    canvas.drawPath(pleats, _line(1.7));
  }

  /// 絵馬: 浅い屋根の五角形の板に屋根の段、上に紐を掛け、願いを筆で2行。
  void _ema(Canvas canvas) {
    final board = Path()
      ..moveTo(4.5, 15)
      ..lineTo(16, 10)
      ..lineTo(27.5, 15)
      ..lineTo(27.5, 25.5)
      ..lineTo(4.5, 25.5)
      ..close();
    canvas.drawPath(board, _fill);
    // 屋根の下の段（へ の字に抜く）。
    canvas.drawPath(
      Path()
        ..moveTo(5, 17.6)
        ..lineTo(16, 12.8)
        ..lineTo(27, 17.6),
      _clearLine(1.3),
    );
    // 上へ掛ける紐（結び目つき）。
    canvas.drawPath(
      Path()
        ..moveTo(13.2, 11.4)
        ..quadraticBezierTo(12.6, 4.6, 16, 4)
        ..quadraticBezierTo(19.4, 4.6, 18.8, 11.4),
      _line(1.4),
    );
    canvas.drawCircle(const Offset(16, 4.4), 1.3, _fill);
    // 願いの字（筆で横に流した2行）。
    canvas.drawPath(
      Path()
        ..moveTo(9, 20.6)
        ..quadraticBezierTo(15, 19.4, 22.5, 20.4),
      _clearLine(1.6),
    );
    canvas.drawPath(
      Path()
        ..moveTo(10, 23.4)
        ..quadraticBezierTo(14, 22.6, 18, 23.2),
      _clearLine(1.6),
    );
  }

  /// 掛け軸: 上下に軸、まん中に筆の一画。
  void _scroll(Canvas canvas) {
    // 掛け紐。
    canvas.drawPath(
      Path()
        ..moveTo(12.5, 7.5)
        ..lineTo(16, 4)
        ..lineTo(19.5, 7.5),
      _line(1.3),
    );
    // 本紙。
    canvas.drawRect(const Rect.fromLTRB(11, 7.5, 21, 24.5), _fill);
    // 上下の軸（本紙より少し長い）。
    canvas.drawLine(const Offset(9, 7.8), const Offset(23, 7.8), _line(2.4));
    canvas.drawLine(const Offset(8.5, 25), const Offset(23.5, 25), _line(2.6));
    // 筆の一画（上が太く、下へ細る）。
    final stroke = Path()
      ..moveTo(14.6, 10.5)
      ..quadraticBezierTo(17.6, 10.6, 17.4, 12.4)
      ..quadraticBezierTo(16.8, 17, 16.4, 22)
      ..quadraticBezierTo(15.6, 17, 15, 13)
      ..quadraticBezierTo(14.3, 11.6, 14.6, 10.5)
      ..close();
    canvas.drawPath(stroke, _clear);
  }

  /// 古地図: 三つ折りの紙に、点線の道と行き先の印。
  void _map(Canvas canvas) {
    final sheet = Path()
      ..moveTo(5, 9)
      ..lineTo(12, 6.5)
      ..lineTo(20, 9)
      ..lineTo(27, 6.5)
      ..lineTo(27, 23)
      ..lineTo(20, 25.5)
      ..lineTo(12, 23)
      ..lineTo(5, 25.5)
      ..close();
    canvas.drawPath(sheet, _fill);
    // 折り目。
    canvas.drawLine(const Offset(12, 7), const Offset(12, 22.5), _clearLine(1));
    canvas.drawLine(const Offset(20, 9.5), const Offset(20, 25), _clearLine(1));
    // 点線の道。
    for (final (a, b) in const [
      (Offset(7.5, 21.5), Offset(9, 19.2)),
      (Offset(10.3, 17.4), Offset(12.6, 16.4)),
      (Offset(14.4, 16.6), Offset(16.4, 17.6)),
      (Offset(18.2, 17.2), Offset(19.6, 15)),
    ]) {
      canvas.drawLine(a, b, _clearLine(1.5));
    }
    // 行き先の印（×）。
    canvas.drawLine(
      const Offset(21.4, 10.2),
      const Offset(25, 13.8),
      _clearLine(1.7),
    );
    canvas.drawLine(
      const Offset(25, 10.2),
      const Offset(21.4, 13.8),
      _clearLine(1.7),
    );
  }

  @override
  bool shouldRepaint(_TabSealPainter oldDelegate) =>
      oldDelegate.tab != tab || oldDelegate.selected != selected;
}
