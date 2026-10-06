import '../records/models.dart';

/// 行事の日。毎年同じ日付のものだけにする（節分・冬至のように年で日付が動くものは入れない）。
enum RamenEvent {
  valentine(2, 14, 11, 30),
  whiteDay(3, 14, 11, 30),
  tanabata(7, 7, 18, 0),
  ramenDay(7, 11, 11, 30),
  halloween(10, 31, 18, 0),
  christmas(12, 24, 18, 0),
  newYearsEve(12, 31, 17, 0);

  const RamenEvent(this.month, this.day, this.hour, this.minute);

  final int month;
  final int day;
  final int hour;
  final int minute;

  DateTime inYear(int year) => DateTime(year, month, day, hour, minute);
}

/// [from]から[until]まで（[from]を含み[until]を含まない）の行事と、知らせる時刻。
List<(RamenEvent, DateTime)> ramenEventsBetween(
  DateTime from,
  DateTime until,
) => [
  for (var year = from.year; year <= until.year; year++)
    for (final event in RamenEvent.values)
      if (event.inYear(year) case final at
          when !at.isBefore(from) && at.isBefore(until))
        (event, at),
];

/// 年の振り返りを勧める時刻（12月26日〜31日のうち2回）。31日は「大晦日」の知らせに譲る。
List<DateTime> yearReviewTimes(int year) => [
  DateTime(year, 12, 26, 20),
  DateTime(year, 12, 30, 20),
];

/// 振り返りを開いたら、その年の通知をやめるか。年の途中で開いても、まとめを見たことにはしない。
bool closesYearReview(int year, DateTime openedAt) =>
    !openedAt.isBefore(DateTime(year, 12, 26));

/// 年始の願掛けを勧める時刻（1月1日〜7日のうち2回）。
List<DateTime> newYearWishTimes(int year) => [
  DateTime(year, 1, 1, 11),
  DateTime(year, 1, 5, 20),
];

/// 年始の願掛けを勧める期間のはじまり。この日から後に願を掛けていれば、もう勧めない。
DateTime newYearWishWindowStart(int year) => DateTime(year, 1, 1);

/// 月一の「今月は食べた？」の時刻（毎月20日の19時）。
DateTime monthlyReminderAt(int year, int month) =>
    DateTime(year, month, 20, 19);

/// その月に1杯でも食べたか（撤退は数えない）。
bool ateInMonth(Iterable<Visit> visits, int year, int month) => visits.any(
  (visit) =>
      visit.result == VisitResult.eaten &&
      visit.eatenAt.year == year &&
      visit.eatenAt.month == month,
);

/// ★の付け忘れを知らせるのは、保存してから1時間半後。
const ratingReminderDelay = Duration(minutes: 90);

/// ★を付けられるのは、食べてから12時間以内（一覧の上の案内と同じ）。
const ratingWindow = Duration(hours: 12);

/// ★の付け忘れを知らせる時刻。★の無い「食べた」記録だけ。過去の写真から記録したなど、
/// 食べてから12時間を過ぎてしまう記録には知らせない。
DateTime? ratingReminderAt(Visit visit) {
  if (visit.result != VisitResult.eaten || visit.rating != null) return null;
  final at = visit.createdAt.add(ratingReminderDelay);
  if (at.difference(visit.eatenAt) > ratingWindow) return null;
  return at;
}
