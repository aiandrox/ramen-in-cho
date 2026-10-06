enum VisitResult { eaten, retreated }

enum RamenStyle {
  shoyu,
  miso,
  shio,
  tonkotsu,
  iekei,
  jiro,
  tsukemen,
  shirunashi,
  other,
}

/// 検索サービスから取り込んだ店の出所。OpenPOI API は、保存した店と一緒にこれを残すよう求めている。
class ShopSource {
  const ShopSource({this.licenses = const [], this.attributions = const []});

  final List<String> licenses;
  final List<String> attributions;
}

class Shop {
  const Shop({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.osmId,
    this.isFamous = false,
    this.strategyMemo = '',
    this.dataSource,
    this.area,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final String? osmId;

  /// 利用者が「名店」の印をつけた店か。食べるたびに修行点が上乗せされる。
  final bool isFamous;

  /// 店の覚え書き（開店の何分前に着けばよいか、券売機など）。1杯ごとの「この一杯について」（Visit.memo）とは別。
  final String strategyMemo;

  /// OpenPOI で見つけた店の出所。OpenStreetMap の店・手入力の店は null。
  final ShopSource? dataSource;

  /// 店のある市区町村（「新宿区」など）。道中記に使う。位置から調べるまではnull、調べても分からなければ空。
  final String? area;
  final DateTime createdAt;
}

class Visit {
  const Visit({
    required this.id,
    required this.shopId,
    required this.result,
    this.photoPath,
    this.checkedInAt,
    required this.eatenAt,
    this.style,
    this.rating,
    required this.isLimited,
    required this.hasTicket,
    required this.memo,
    required this.createdAt,
  });

  final String id;
  final String shopId;
  final VisitResult result;

  /// documentsディレクトリからの相対パス。iOSは更新のたびに絶対パスが変わるため。
  final String? photoPath;
  final DateTime? checkedInAt;
  final DateTime eatenAt;
  final RamenStyle? style;
  final int? rating;
  final bool isLimited;

  /// 整理券制か。今は入力も採点もしないが、過去の記録の値は残している。
  final bool hasTicket;
  final String memo;
  final DateTime createdAt;
}

/// 願掛け帳（行きたい店）の1件。まだ行っていない店のこともあるため、店の情報をそのまま持つ。
/// 記録のときに願の店を選ぶと、その1杯と結び付く（叶う）。
class Wish {
  const Wish({
    required this.id,
    this.shopId,
    this.osmId,
    required this.name,
    this.latitude,
    this.longitude,
    this.dataSource,
    this.trigger = '',
    this.note = '',
    required this.createdAt,
    this.fulfilledVisitId,
  });

  final String id;

  /// 書き留めたときに記録済みだった店のID。店はあとで消えることがあるので、名前と位置でも照らし合わせる。
  final String? shopId;
  final String? osmId;
  final String name;
  final double? latitude;
  final double? longitude;
  final ShopSource? dataSource;

  /// きっかけ（誰に聞いた・どこで見た）。
  final String trigger;

  /// ひとこと（食べたいもの など）。
  final String note;
  final DateTime createdAt;

  /// この願が叶った1杯。まだならnull。
  final String? fulfilledVisitId;
}

/// 並んでいる最中の店。記録がまだ無い店のこともあるため、店の情報をそのまま持つ。
class Checkin {
  const Checkin({
    this.shopId,
    this.osmId,
    required this.name,
    this.latitude,
    this.longitude,
    this.dataSource,
    required this.checkedInAt,
  });

  final String? shopId;
  final String? osmId;
  final String name;
  final double? latitude;
  final double? longitude;
  final ShopSource? dataSource;
  final DateTime checkedInAt;
}

class VisitWithShop {
  const VisitWithShop({required this.visit, required this.shop});

  final Visit visit;
  final Shop shop;
}

/// 利用者が決めた拠点（駅・市など）。変えるたびに1件ずつ足し、変えた日時から後の記録にだけ効く。
class HomeBaseSetting {
  const HomeBaseSetting({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.setAt,
  });

  final String id;

  /// 画面に出す名前（「横浜駅」「札幌市」など）。
  final String name;
  final double latitude;
  final double longitude;
  final DateTime setAt;

  HomeBaseSetting copyWith({
    String? name,
    double? latitude,
    double? longitude,
    DateTime? setAt,
  }) => HomeBaseSetting(
    id: id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    setAt: setAt ?? this.setAt,
  );
}
