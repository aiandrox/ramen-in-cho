import '../records/models.dart';

/// 日本の島々をおおまかに覆う四角（南の緯度・北の緯度・西の経度・東の経度）。
/// 近くの国（韓国・台湾・中国・ロシア）にかからないよう、島ごとに分けて区切る。
const japanBoxes = <(double, double, double, double)>[
  (41.3, 45.6, 139.3, 148.95), // 北海道・北方領土
  (36.0, 41.6, 132.5, 142.1), // 本州の北半分・佐渡・隠岐
  (32.6, 36.0, 130.8, 141.0), // 本州の南半分・四国
  (30.9, 34.0, 128.5, 132.1), // 九州・五島・壱岐
  (34.0, 34.75, 129.1, 129.55), // 対馬
  (24.0, 31.0, 122.85, 131.4), // 南西諸島（奄美・沖縄・八重山・与那国・大東）
  (24.0, 34.9, 138.9, 142.4), // 伊豆諸島・小笠原
  (24.2, 24.4, 153.9, 154.1), // 南鳥島
  (20.3, 20.6, 136.0, 136.2), // 沖ノ鳥島
];

/// [latitude]・[longitude]が日本の島々の四角に入るか。
bool isInJapan(double latitude, double longitude) {
  for (final (south, north, west, east) in japanBoxes) {
    if (latitude >= south &&
        latitude <= north &&
        longitude >= west &&
        longitude <= east) {
      return true;
    }
  }
  return false;
}

/// 海外の店か。位置のわからない店は海外とみなさない（わからない）。
bool isOverseasShop(Shop shop) {
  final latitude = shop.latitude;
  final longitude = shop.longitude;
  if (latitude == null || longitude == null) return false;
  return !isInJapan(latitude, longitude);
}
