import '../records/models.dart';
import '../scoring/points.dart';
import '../shop_search/geo.dart';

/// 旅路の1か所（食べた店）。
class JourneyStop {
  const JourneyStop({
    required this.visitId,
    required this.shop,
    required this.location,
    required this.eatenAt,
  });

  final String visitId;
  final Shop shop;
  final GeoPoint location;
  final DateTime eatenAt;
}

/// 食べた店を、食べた順に並べる。位置のわからない店は除き、同じ店が続くときは1つにまとめる。
/// [year]を渡すとその年だけ。
List<JourneyStop> journeyStops(List<ScoredVisit> scored, {int? year}) {
  final stops = <JourneyStop>[];
  for (final entry in scored) {
    final visit = entry.visit;
    if (visit.result != VisitResult.eaten) continue;
    if (year != null && visit.eatenAt.year != year) continue;
    final latitude = entry.shop.latitude;
    final longitude = entry.shop.longitude;
    if (latitude == null || longitude == null) continue;
    if (stops.isNotEmpty && stops.last.shop.id == entry.shop.id) continue;
    stops.add(
      JourneyStop(
        visitId: visit.id,
        shop: entry.shop,
        location: GeoPoint(latitude, longitude),
        eatenAt: visit.eatenAt,
      ),
    );
  }
  return stops;
}

/// 旅路の長さ（店と店を直線でつないだ距離、km）。
double journeyKilometers(List<JourneyStop> stops) {
  var meters = 0.0;
  for (var i = 1; i < stops.length; i++) {
    meters += distanceMeters(stops[i - 1].location, stops[i].location);
  }
  return meters / 1000;
}

/// 遠くへ食べに行った1日。
class Expedition {
  const Expedition({required this.day, required this.stops});

  final DateTime day;
  final List<JourneyStop> stops;
}

/// その1杯を食べた時点の拠点（利用者が決めたもの）から遠い店で食べた日を、日ごとにまとめる（新しい順）。
/// 拠点を変えても、前の遠征は変わらない。拠点を決める前の1杯は遠征にならない。
/// [year]を渡すと、その年の遠征だけを返す。
List<Expedition> expeditions(List<ScoredVisit> scored, {int? year}) {
  final byDay = <DateTime, List<JourneyStop>>{};
  for (final entry in scored) {
    if (!entry.isExpedition) continue;
    final at = entry.visit.eatenAt;
    if (year != null && at.year != year) continue;
    (byDay[DateTime(at.year, at.month, at.day)] ??= []).add(
      JourneyStop(
        visitId: entry.visit.id,
        shop: entry.shop,
        location: GeoPoint(entry.shop.latitude!, entry.shop.longitude!),
        eatenAt: at,
      ),
    );
  }
  return [
    for (final MapEntry(key: day, value: stops) in byDay.entries)
      Expedition(day: day, stops: stops),
  ]..sort((a, b) => b.day.compareTo(a.day));
}
