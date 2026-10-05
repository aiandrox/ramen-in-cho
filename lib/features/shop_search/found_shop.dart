import '../records/models.dart';
import 'geo.dart';
import 'opening_hours.dart';

const shopSearchRadiusMeters = 300;

/// 店の検索（Overpass・OpenPOI）で見つかった店。
class FoundShop {
  const FoundShop({
    this.osmId,
    required this.name,
    required this.location,
    this.dataSource,
    this.address,
    this.openingHours,
    this.curatedConditions,
  });

  /// OpenStreetMap の ID。OpenPOI で見つかった店は null。
  final String? osmId;
  final String name;
  final GeoPoint location;

  /// OpenPOI で見つけた店の出所。
  final ShopSource? dataSource;

  /// 店名で探したときに、同じ名前の店（支店）を見分けるための住所。わからなければnull。
  final String? address;

  /// OpenStreetMap に載っている営業時間（`opening_hours`）。
  final String? openingHours;

  /// 手で持つ店（`data/curated_shops.json`）に書いた攻略しにくさ。手で持つ店でないか、条件が無ければnull。
  final Set<HoursCondition>? curatedConditions;

  /// 初めて記録するときの条件の下書き。手で持つ店の条件を、営業時間から推し量った条件より優先する。
  /// 当てはまるものが無いか、わからなければnull。
  Set<HoursCondition>? get suggestedConditions => _suggestion?.$1;

  /// [suggestedConditions]をどこから作ったか。
  ConditionsDraftSource? get suggestedConditionsSource => _suggestion?.$2;

  (Set<HoursCondition>, ConditionsDraftSource)? get _suggestion {
    final curated = curatedConditions;
    if (curated != null && curated.isNotEmpty) {
      return (curated, ConditionsDraftSource.curatedShops);
    }
    final conditions = conditionsFromOpeningHours(openingHours);
    return conditions == null || conditions.isEmpty
        ? null
        : (conditions, ConditionsDraftSource.openingHours);
  }

  FoundShop copyWithCuratedConditions(Set<HoursCondition> conditions) =>
      FoundShop(
        osmId: osmId,
        name: name,
        location: location,
        dataSource: dataSource,
        address: address,
        openingHours: openingHours,
        curatedConditions: conditions,
      );
}

/// 店の条件の下書きの出どころ。
enum ConditionsDraftSource {
  /// OpenStreetMap の営業時間（`opening_hours`）から推し量った。
  openingHours,

  /// 手で持つ店の一覧に書いた条件。
  curatedShops,
}

/// [near] があれば近い順に並べ替える（無ければそのまま）。
List<FoundShop> nearestFirst(List<FoundShop> shops, GeoPoint? near) {
  if (near == null) return shops;
  return [...shops]..sort(
    (a, b) => distanceMeters(
      near,
      a.location,
    ).compareTo(distanceMeters(near, b.location)),
  );
}

/// OpenStreetMap の店を優先し（ID があるため）、OpenPOI の店は重ならないものだけ足す。
/// OpenPOI には ID が無く、同じ店が業種違いで複数件になることもあるため、名前と近さで重なりを判定する。
List<FoundShop> mergeFoundShops(List<FoundShop> osm, List<FoundShop> poi) {
  final merged = [...osm];
  for (final shop in poi) {
    if (merged.any(
      (other) => looksLikeSameShop(
        shop.name,
        shop.location,
        other.name,
        other.location,
      ),
    )) {
      continue;
    }
    merged.add(shop);
  }
  return merged;
}

/// 表記ゆれを許して同じ店とみなす距離。同じ名前の別の支店（数百 m 離れている）と混ざらない程度に狭くする。
const lookAlikeShopMeters = 100;

/// 出どころの違う（ID で比べられない）2つの店が同じ店か。
/// 近くにあり、空白や全角半角を無視して一方の名前がもう一方を含むなら同じ店とみなす（「鴨 to 葱」と「らーめん鴨to葱」）。
bool looksLikeSameShop(String aName, GeoPoint a, String bName, GeoPoint b) {
  if (distanceMeters(a, b) > lookAlikeShopMeters) return false;
  return shopNamesLookAlike(aName, bName);
}

bool shopNamesLookAlike(String a, String b) {
  final aName = normalizeShopName(a);
  final bName = normalizeShopName(b);
  final (shorter, longer) = aName.length <= bName.length
      ? (aName, bName)
      : (bName, aName);
  return shorter.length >= 2 && longer.contains(shorter);
}

/// 店名で探すときに問い合わせる言葉。全角の空白は半角にそろえ、空白があれば空白を詰めた言葉も足す
/// （検索サービスによって「麺屋 武蔵」では見つからず「麺屋武蔵」では見つかる、などの違いがあるため）。
List<String> nameQueryVariants(String query) {
  final spaced = query
      .replaceAll('\u3000', ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .join(' ');
  if (spaced.isEmpty) return const [];
  final joined = spaced.replaceAll(' ', '');
  return [spaced, if (joined != spaced) joined];
}

/// 空白を除き、全角英数を半角に、英字を小文字にそろえる。
String normalizeShopName(String name) {
  final buffer = StringBuffer();
  for (final rune in name.runes) {
    if (rune == 0x20 || rune == 0x3000) continue;
    final ascii = rune >= 0xFF01 && rune <= 0xFF5E ? rune - 0xFEE0 : rune;
    buffer.writeCharCode(ascii);
  }
  return buffer.toString().toLowerCase();
}
