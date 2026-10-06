import 'package:flutter/material.dart';

/// 幅いっぱいに、同じ幅の升目で並べる。列の数は[minItemWidth]が入るだけ取り、余りは升目に配る
/// （右に空きが残らないように）。
class EvenGrid extends StatelessWidget {
  const EvenGrid({
    super.key,
    this.minItemWidth = 0,
    this.columns,
    this.spacing = 8,
    this.runSpacing = 8,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double minItemWidth;

  /// 列の数を決めて並べるとき。指定がなければ[minItemWidth]から決める。
  final int? columns;
  final double spacing;
  final double runSpacing;
  final int itemCount;
  final Widget Function(BuildContext context, int index, double width)
  itemBuilder;

  /// [width]に並べるときの列の数と、升目の幅。
  static (int, double) layout(
    double width,
    double minItemWidth,
    double spacing,
  ) {
    final columns = ((width + spacing) / (minItemWidth + spacing))
        .floor()
        .clamp(1, 99);
    // 小数の誤差で最後の1つが次の行に落ちないよう、ごくわずかに詰める。
    final itemWidth = (width - spacing * (columns - 1)) / columns - 0.01;
    return (columns, itemWidth);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fixed = columns;
        final itemWidth = fixed == null
            ? layout(constraints.maxWidth, minItemWidth, spacing).$2
            : (constraints.maxWidth - spacing * (fixed - 1)) / fixed - 0.01;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (var i = 0; i < itemCount; i++)
              SizedBox(
                width: itemWidth,
                child: itemBuilder(context, i, itemWidth),
              ),
          ],
        );
      },
    );
  }
}
