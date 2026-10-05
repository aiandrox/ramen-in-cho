import 'models.dart';

/// 並んでから食べるまでの分数（端数切り捨て）。チェックインしていない記録と撤退はnull。
int? waitMinutes(Visit visit) {
  final checkedInAt = visit.checkedInAt;
  if (checkedInAt == null || visit.result != VisitResult.eaten) return null;
  final minutes = visit.eatenAt.difference(checkedInAt).inMinutes;
  return minutes < 0 ? 0 : minutes;
}

/// 記録画面で保存するときの、食べた時刻と並んだ時刻。
/// 「着」を押した時刻（[arrivedAt]）があれば、写真をいつ撮っても（撮らなくても）それを食べた時刻にする。
/// [checkedInAt]は並んだ店を選んでいるときだけ渡す。並ぶ前に食べた（昔の写真の）記録には待ち時間をつけない。
({DateTime eatenAt, DateTime? checkedInAt}) recordTimes({
  required DateTime now,
  DateTime? photoTakenAt,
  DateTime? arrivedAt,
  DateTime? checkedInAt,
}) {
  final eatenAt = arrivedAt ?? photoTakenAt ?? now;
  return (
    eatenAt: eatenAt,
    checkedInAt: checkedInAt == null || eatenAt.isBefore(checkedInAt)
        ? null
        : checkedInAt,
  );
}
