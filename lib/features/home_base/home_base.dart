import '../records/models.dart';
import '../shop_search/geo.dart';

/// 遠征とみなす、拠点からの距離。首都圏から北関東や関東の外へ出かけるくらい。
const expeditionKilometers = 80;

/// [at]の時点で効いている拠点（[at]以前に決めたうちの最新）。まだ決めていなければnull。
HomeBaseSetting? homeBaseAt(List<HomeBaseSetting> settings, DateTime at) {
  HomeBaseSetting? found;
  for (final setting in settings) {
    if (setting.setAt.isAfter(at)) continue;
    if (found == null || !setting.setAt.isBefore(found.setAt)) found = setting;
  }
  return found;
}

/// いちばん新しく決めた拠点。
HomeBaseSetting? latestHomeBase(List<HomeBaseSetting> settings) {
  HomeBaseSetting? found;
  for (final setting in settings) {
    if (found == null || !setting.setAt.isBefore(found.setAt)) found = setting;
  }
  return found;
}

/// 初めて拠点を決めたとき。
HomeBaseSetting? firstHomeBase(List<HomeBaseSetting> settings) {
  HomeBaseSetting? found;
  for (final setting in settings) {
    if (found == null || setting.setAt.isBefore(found.setAt)) found = setting;
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
