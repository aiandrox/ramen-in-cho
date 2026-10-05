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

/// [base]から[expeditionKilometers]以上離れた店か。拠点か店の位置が分からなければfalse。
bool isFarFromHomeBase(HomeBaseSetting? base, Shop shop) {
  final latitude = shop.latitude;
  final longitude = shop.longitude;
  if (base == null || latitude == null || longitude == null) return false;
  return distanceMeters(
        GeoPoint(base.latitude, base.longitude),
        GeoPoint(latitude, longitude),
      ) >=
      expeditionKilometers * 1000;
}
