import '../records/models.dart';
import 'found_shop.dart';
import 'geo.dart';

/// 地図の検索で見つからないことのある店（手で持つ店）。今はラーメン二郎の直系店だけ。
/// 正本は `data/curated_shops.json`。アプリはサーバーから1日1回まで取り直し（[CuratedShopsStore]）、
/// 取れないときはこのファイルに同梱した一覧（[builtinShops]）を使う。同梱分は正本と同じにする（テストで確かめる）。
class BuiltinShop {
  const BuiltinShop({
    required this.name,
    required this.address,
    required this.location,
    this.hoursConditions = const {},
  });

  final String name;
  final String address;
  final GeoPoint location;

  /// 店の条件（攻略しにくさ）。初めて記録するときの下書きにする。調べていない店は空。
  final Set<HoursCondition> hoursConditions;

  /// サーバーや保存したファイルの1件。閉店した店と、形の崩れた店はnull。
  static BuiltinShop? fromJson(Map<String, dynamic> json) {
    final (name, address, lat, lon, status) = (
      json['name'],
      json['address'],
      json['latitude'],
      json['longitude'],
      json['status'],
    );
    if (name is! String || address is! String) return null;
    if (lat is! num || lon is! num) return null;
    if (status != null && status != 'open') return null;
    final conditions = json['hoursConditions'];
    return BuiltinShop(
      name: name,
      address: address,
      location: GeoPoint(lat.toDouble(), lon.toDouble()),
      // 知らない条件（新しい版のアプリで足したもの）は読み飛ばす。
      hoursConditions: {
        if (conditions is List)
          for (final value in conditions)
            ?HoursCondition.values.asNameMap()[value],
      },
    );
  }

  Map<String, Object> toJson() => {
    'name': name,
    'address': address,
    'latitude': location.latitude,
    'longitude': location.longitude,
    'status': 'open',
    'hoursConditions': [for (final c in hoursConditions) c.name],
  };

  FoundShop toFoundShop() => FoundShop(
    name: name,
    location: location,
    address: address,
    curatedConditions: hoursConditions.isEmpty ? null : hoursConditions,
  );
}

/// 検索で見つかった店のうち、手で持つ店と同じ店に、その店の条件を付ける。
/// OpenStreetMap にも同じ店があると、手で持つ店はまとめるときに落ちるため、条件だけを移す。
List<FoundShop> withCuratedConditions(
  List<FoundShop> found,
  List<BuiltinShop> curated,
) => [
  for (final shop in found)
    if (shop.curatedConditions == null)
      if (curated
              .where(
                (c) =>
                    c.hoursConditions.isNotEmpty &&
                    looksLikeSameShop(
                      c.name,
                      c.location,
                      shop.name,
                      shop.location,
                    ),
              )
              .firstOrNull
          case final match?)
        shop.copyWithCuratedConditions(match.hoursConditions)
      else
        shop
    else
      shop,
];

/// [center]から[radiusMeters]以内の、手で持つ店。
List<FoundShop> builtinShopsNear(
  GeoPoint center,
  int radiusMeters, {
  List<BuiltinShop> shops = builtinShops,
}) => [
  for (final shop in shops)
    if (distanceMeters(center, shop.location) <= radiusMeters)
      shop.toFoundShop(),
];

/// [query]に合う、アプリに持たせている店（空白・全角半角は区別しない）。
/// 空白で区切った言葉がすべて名前に含まれるか、言葉の文字が名前に順に現れれば合う
/// （「二郎 関内」「二郎関内」のどちらでも「ラーメン二郎 横浜関内店」に合う）。
/// 「ラーメン」のように多くの店に当たるときでも並びすぎないよう、[near]に近い順に[limit]件まで。
List<FoundShop> builtinShopsNamed(
  String query, {
  GeoPoint? near,
  int limit = 5,
  List<BuiltinShop> shops = builtinShops,
}) {
  final words = [
    for (final word in query.replaceAll('\u3000', ' ').split(' '))
      if (normalizeShopName(word).isNotEmpty) normalizeShopName(word),
  ];
  if (words.isEmpty) return const [];
  final joined = words.join();
  bool matches(BuiltinShop shop) {
    final name = normalizeShopName(shop.name);
    return words.every(name.contains) || _appearsInOrder(joined, name);
  }

  final matched = [
    for (final shop in shops)
      if (matches(shop)) shop,
  ];
  if (near != null) {
    matched.sort(
      (a, b) => distanceMeters(
        near,
        a.location,
      ).compareTo(distanceMeters(near, b.location)),
    );
  }
  return [for (final shop in matched.take(limit)) shop.toFoundShop()];
}

/// [query]の文字が、[name]の中に同じ順で（間に別の文字をはさんでもよく）現れるか。
bool _appearsInOrder(String query, String name) {
  var from = 0;
  for (final rune in query.runes) {
    final index = name.indexOf(String.fromCharCode(rune), from);
    if (index < 0) return false;
    from = index + 1;
  }
  return true;
}

const builtinShops = <BuiltinShop>[
  BuiltinShop(
    name: 'ラーメン二郎 三田本店',
    address: '東京都港区三田2-16-4',
    location: GeoPoint(35.648045, 139.741516),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 目黒店',
    address: '東京都目黒区目黒3-7-2',
    location: GeoPoint(35.634285, 139.707077),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 仙川店',
    address: '東京都調布市仙川町1-10-17',
    location: GeoPoint(35.661385, 139.583847),
    hoursConditions: {HoursCondition.nightOnly},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 新宿歌舞伎町店',
    address: '東京都新宿区歌舞伎町2-37-5',
    location: GeoPoint(35.696198, 139.701874),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 品川店',
    address: '東京都品川区北品川1-18-5',
    location: GeoPoint(35.623974, 139.742966),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 新宿小滝橋通り店',
    address: '東京都新宿区西新宿7-5-5',
    location: GeoPoint(35.696323, 139.698318),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 環七新新代田店',
    address: '東京都世田谷区代田5-29-5',
    location: GeoPoint(35.661949, 139.660385),
    hoursConditions: {HoursCondition.lunchOnly},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 八王子野猿街道店2',
    address: '東京都八王子市堀之内2-13-16',
    location: GeoPoint(35.62962, 139.40126),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 池袋東口店',
    address: '東京都豊島区南池袋2-27-17',
    location: GeoPoint(35.728195, 139.713913),
    hoursConditions: {HoursCondition.nightOnly},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 亀戸店',
    address: '東京都江東区亀戸4-35-17',
    location: GeoPoint(35.701885, 139.826706),
    hoursConditions: {HoursCondition.irregular},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 府中店',
    address: '東京都府中市宮西町1-15-5',
    location: GeoPoint(35.672115, 139.477158),
    hoursConditions: {HoursCondition.nightOnly, HoursCondition.weekdaysOnly},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 めじろ台店',
    address: '東京都八王子市椚田町513-9',
    location: GeoPoint(35.638947, 139.312744),
    hoursConditions: {HoursCondition.irregular},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 荻窪店',
    address: '東京都杉並区荻窪4-33-1',
    location: GeoPoint(35.703602, 139.626282),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 上野毛店',
    address: '東京都世田谷区上野毛1-26-16',
    location: GeoPoint(35.612442, 139.639023),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 環七一之江店',
    address: '東京都江戸川区一之江8-3-4',
    location: GeoPoint(35.684071, 139.881927),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 神田神保町店',
    address: '東京都千代田区神田神保町1-21-4',
    location: GeoPoint(35.69529, 139.761002),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 小岩店',
    address: '東京都江戸川区西小岩3-31-13',
    location: GeoPoint(35.734898, 139.880005),
    hoursConditions: {HoursCondition.lunchOnly, HoursCondition.weekdaysOnly},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 ひばりヶ丘駅前店',
    address: '東京都西東京市谷戸町3-27-24',
    location: GeoPoint(35.749908, 139.543793),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 立川店',
    address: '東京都立川市柴崎町2-10-1',
    location: GeoPoint(35.696507, 139.409515),
    hoursConditions: {HoursCondition.irregular},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 千住大橋駅前店',
    address: '東京都足立区千住橋戸町10-8',
    location: GeoPoint(35.742706, 139.796906),
    hoursConditions: {HoursCondition.lunchOnly, HoursCondition.weekdaysOnly},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 西台駅前店',
    address: '東京都板橋区蓮根3-9-7',
    location: GeoPoint(35.7869, 139.674423),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 一橋学園店',
    address: '東京都小平市学園西町2-13-4',
    location: GeoPoint(35.722313, 139.479294),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 京急川崎店',
    address: '神奈川県川崎市川崎区本町2-10-1',
    location: GeoPoint(35.534908, 139.705704),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 相模大野店',
    address: '神奈川県相模原市南区相模大野6-14-9',
    location: GeoPoint(35.529911, 139.432846),
    hoursConditions: {HoursCondition.irregular},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 横浜関内店',
    address: '神奈川県横浜市中区長者町6-94',
    location: GeoPoint(35.442196, 139.63089),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 湘南藤沢店',
    address: '神奈川県藤沢市本町1-10-14',
    location: GeoPoint(35.342964, 139.482269),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 中山駅前店',
    address: '神奈川県横浜市緑区台村町309-1',
    location: GeoPoint(35.51297, 139.538147),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 生田駅前店',
    address: '神奈川県川崎市多摩区生田8-1-15',
    location: GeoPoint(35.615597, 139.546448),
    hoursConditions: {HoursCondition.irregular},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 松戸駅前店',
    address: '千葉県松戸市本町17-21',
    location: GeoPoint(35.785427, 139.899033),
    hoursConditions: {HoursCondition.nightOnly},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 京成大久保店',
    address: '千葉県船橋市三山2-1-11',
    location: GeoPoint(35.691578, 140.049591),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 千葉店',
    address: '千葉県千葉市中央区中央1-7-8',
    location: GeoPoint(35.610481, 140.123581),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 柏店',
    address: '千葉県柏市十余二249-5',
    location: GeoPoint(35.881977, 139.957626),
    hoursConditions: {HoursCondition.lunchOnly, HoursCondition.badAccess},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 栃木街道店',
    address: '栃木県下都賀郡壬生町本丸2-15-67',
    location: GeoPoint(36.422985, 139.7948),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 仙台店',
    address: '宮城県仙台市青葉区一番町2-5-32',
    location: GeoPoint(38.259483, 140.872208),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 札幌店',
    address: '北海道札幌市北区北六条西8-8-11',
    location: GeoPoint(43.067162, 141.343063),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 会津若松駅前店',
    address: '福島県会津若松市駅前町6-31',
    location: GeoPoint(37.506386, 139.93132),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 新潟店',
    address: '新潟県新潟市中央区万代5-2-8',
    location: GeoPoint(37.917233, 139.06015),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 川越店',
    address: '埼玉県川越市旭町1-4-15',
    location: GeoPoint(35.902737, 139.476166),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 越谷店',
    address: '埼玉県越谷市越ヶ谷2-3-7',
    location: GeoPoint(35.890182, 139.787659),
    hoursConditions: {HoursCondition.weekdaysOnly, HoursCondition.irregular},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 大宮公園駅前店',
    address: '埼玉県さいたま市大宮区寿能町1-24',
    location: GeoPoint(35.921688, 139.632248),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 京都店',
    address: '京都府京都市左京区一乗寺里ノ前町4',
    location: GeoPoint(35.043465, 135.787445),
    hoursConditions: {HoursCondition.irregular},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 前橋千代田町店',
    address: '群馬県前橋市千代田町4-12-3',
    location: GeoPoint(36.392548, 139.070999),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 ひたちなか店',
    address: '茨城県ひたちなか市田彦1648-4',
    location: GeoPoint(36.409088, 140.514603),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 朝倉街道駅前店',
    address: '福岡県筑紫野市針摺中央2-17-8',
    location: GeoPoint(33.48444, 130.533493),
    hoursConditions: {HoursCondition.weekdaysOnly},
  ),
  BuiltinShop(
    name: 'ラーメン二郎 名古屋大曽根店',
    address: '愛知県名古屋市東区矢田4-3-7',
    location: GeoPoint(35.193916, 136.941925),
  ),
  BuiltinShop(
    name: 'ラーメン二郎 沖縄店',
    address: '沖縄県那覇市壺屋1-6-16',
    location: GeoPoint(26.21266, 127.689667),
  ),
];
