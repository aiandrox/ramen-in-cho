import 'package:ramen_in_cho/features/records/models.dart';

HomeBaseSetting buildHomeBase({
  String? id,
  String name = '拠点',
  double latitude = 35.0,
  double longitude = 139.0,
  required DateTime setAt,
}) => HomeBaseSetting(
  id: id ?? 'base-${setAt.toIso8601String()}',
  name: name,
  latitude: latitude,
  longitude: longitude,
  setAt: setAt,
);

Shop buildShop({
  String id = 'shop',
  String? name,
  bool isFamous = false,
  String? area,
  double? latitude,
  double? longitude,
  String? osmId,
  String strategyMemo = '',
}) => Shop(
  id: id,
  name: name ?? id,
  latitude: latitude,
  longitude: longitude,
  osmId: osmId,
  strategyMemo: strategyMemo,
  isFamous: isFamous,
  area: area,
  createdAt: DateTime(2026),
);

var _visitCount = 0;

Visit buildVisit({
  String? id,
  String shopId = 'shop',
  VisitResult result = VisitResult.eaten,
  DateTime? eatenAt,
  int? waitMinutes,
  RamenStyle? style,
  int? rating = 3,
  bool isLimited = false,
  String memo = '',
  String? photoPath,
}) {
  final at = eatenAt ?? DateTime(2026, 9, 30, 12);
  return Visit(
    id: id ?? 'visit-${_visitCount++}',
    shopId: shopId,
    result: result,
    photoPath: photoPath,
    checkedInAt: waitMinutes == null
        ? null
        : at.subtract(Duration(minutes: waitMinutes)),
    eatenAt: at,
    style: style,
    rating: result == VisitResult.eaten ? rating : null,
    isLimited: isLimited,
    memo: memo,
    createdAt: at,
  );
}

VisitWithShop buildEntry({
  Shop? shop,
  VisitResult result = VisitResult.eaten,
  DateTime? eatenAt,
  int? waitMinutes,
  RamenStyle? style,
  bool isLimited = false,
  String memo = '',
}) {
  final resolvedShop = shop ?? buildShop();
  return VisitWithShop(
    shop: resolvedShop,
    visit: buildVisit(
      shopId: resolvedShop.id,
      result: result,
      eatenAt: eatenAt,
      waitMinutes: waitMinutes,
      style: style,
      isLimited: isLimited,
      memo: memo,
    ),
  );
}
