import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 端末の下の帯（Android のナビゲーションバー、iPhone のホームインジケーター）と、
/// その上に置くボタンとのあいだに空けるゆとり。
const safeBottomGap = 8.0;

/// 画面の下端に置くものの下の余白。帯が無ければ [base]、あれば帯の高さに [safeBottomGap] を足した分
/// （[base] より小さくはしない）。キーボードが出ているあいだは帯の分を数えない。
double safeBottomPadding(BuildContext context, {double base = 16}) =>
    math.max(base, MediaQuery.paddingOf(context).bottom + safeBottomGap);

/// 画面の下に固定するボタンの帯。端末の下の帯にかからず、ぎりぎりにもならないように空ける。
class SafeBottomBar extends StatelessWidget {
  const SafeBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    bottom: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, safeBottomPadding(context)),
      child: child,
    ),
  );
}
