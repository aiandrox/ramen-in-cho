import '../records/models.dart';
import '../shop_search/geo.dart';

/// 遠征とみなす、拠点からの距離。首都圏から北関東や関東の外へ出かけるくらい。
const expeditionKilometers = 80;

/// 拠点の並び順（決めた日時の順。同じ日時ならIDの順にして、どちらが効くかを毎回同じにする）。
int compareHomeBases(HomeBaseSetting a, HomeBaseSetting b) {
  final bySetAt = a.setAt.compareTo(b.setAt);
  return bySetAt != 0 ? bySetAt : a.id.compareTo(b.id);
}

/// 新しい順に並べた拠点（これまでの拠点の一覧に使う）。
List<HomeBaseSetting> homeBasesNewestFirst(List<HomeBaseSetting> settings) =>
    [...settings]..sort((a, b) => compareHomeBases(b, a));

/// 日付を直したときに保存する日時（その日の0時。その日の記録すべてに効かせる）。
DateTime homeBaseDayStart(DateTime day) =>
    DateTime(day.year, day.month, day.day);

/// 新しく決める拠点の「いつから」に選べる、いちばん前の日。
/// 今の拠点より前の日にすると今の拠点のほうが新しいままになるので、今の拠点を決めた日の翌日から（今日より後にはしない）。
/// 前の日から効かせたいときは、これまでの拠点の日付を直す。
DateTime earliestNewHomeBaseDay(List<HomeBaseSetting> settings, DateTime now) {
  final today = homeBaseDayStart(now);
  final latest = latestHomeBase(settings);
  if (latest == null) return homeBaseFirstDay;
  final next = homeBaseDayStart(latest.setAt).add(const Duration(days: 1));
  return next.isAfter(today) ? today : next;
}

/// 「いつから」に選べる日の下限（拠点がまだ無いとき）。
final homeBaseFirstDay = DateTime(2000);

/// 新しく決める拠点の効き始め。[day]が無いか今日なら今この時から（その日のうちに決め直しても、後に決めたほうが効くように）、
/// 前の日ならその日の0時から（その日の記録すべてに効かせる）。
/// 今の拠点より前になるとき（窓を開いている間に日付が変わったなど）は今この時にし、新しい拠点がいつも今の拠点になるようにする。
DateTime newHomeBaseSetAt({
  required DateTime? day,
  required DateTime now,
  List<HomeBaseSetting> settings = const [],
}) {
  if (day == null) return now;
  final start = homeBaseDayStart(day);
  if (!start.isBefore(homeBaseDayStart(now))) return now;
  final latest = latestHomeBase(settings);
  return latest != null && !start.isAfter(latest.setAt) ? now : start;
}

/// [at]の時点で効いている拠点（[at]以前に決めたうちの最新）。まだ決めていなければnull。
HomeBaseSetting? homeBaseAt(List<HomeBaseSetting> settings, DateTime at) =>
    latestHomeBase([
      for (final setting in settings)
        if (!setting.setAt.isAfter(at)) setting,
    ]);

/// いちばん新しく決めた拠点。
HomeBaseSetting? latestHomeBase(List<HomeBaseSetting> settings) {
  HomeBaseSetting? found;
  for (final setting in settings) {
    if (found == null || compareHomeBases(setting, found) > 0) found = setting;
  }
  return found;
}

/// 初めて拠点を決めたとき。
HomeBaseSetting? firstHomeBase(List<HomeBaseSetting> settings) {
  HomeBaseSetting? found;
  for (final setting in settings) {
    if (found == null || compareHomeBases(setting, found) < 0) found = setting;
  }
  return found;
}

/// [base]から店までの距離（m）。拠点か店の位置が分からなければnull。
double? homeBaseDistanceMeters(HomeBaseSetting? base, Shop shop) {
  final latitude = shop.latitude;
  final longitude = shop.longitude;
  if (base == null || latitude == null || longitude == null) return null;
  return distanceMeters(
    GeoPoint(base.latitude, base.longitude),
    GeoPoint(latitude, longitude),
  );
}

/// [base]から[expeditionKilometers]以上離れた店か。拠点か店の位置が分からなければfalse。
bool isFarFromHomeBase(HomeBaseSetting? base, Shop shop) =>
    (homeBaseDistanceMeters(base, shop) ?? 0) >= expeditionKilometers * 1000;
