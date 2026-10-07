import 'package:flutter/material.dart';

/// 日付と時刻を続けて選ぶ。どちらかを閉じたらnull。
/// 選び直さずに閉じたときは、秒を落として変えたことにしないよう[initial]をそのまま返す。
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
  required DateTime now,
}) async {
  final latest = now.isAfter(initial) ? now : initial;
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: initial.year < 2000 ? initial : DateTime(2000),
    lastDate: latest,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  final picked = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  if (picked == initial.copyWith(second: 0, millisecond: 0, microsecond: 0)) {
    return initial;
  }
  return picked.isAfter(latest) ? latest : picked;
}
