import 'package:flutter/material.dart';

import 'washi.dart';

/// 昇段の記録・型のこれまでの段で使う1行。左に印、右に文、押せるときは右端に矢印。
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.seal,
    required this.lines,
    this.onTap,
  });

  final Widget seal;
  final List<Widget> lines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Washi.line, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(width: 76, child: Center(child: seal)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines,
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Washi.faded),
          ],
        ),
      ),
    );
  }
}
