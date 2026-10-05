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

/// 旅路を再生する長さ。最初の店を灯す間をおき、1区間ずつ筆で引くように線をのばす。
/// 店が多くても [journeyReplayCap] に収め、少なくても1区間は短すぎないようにする。
Duration journeyReplayDuration(int stops) {
  if (stops <= 1) return const Duration(milliseconds: journeyReplayLeadMs);
  final perSegment =
      (journeyReplayCap.inMilliseconds - journeyReplayLeadMs) / (stops - 1);
  final segment = perSegment.clamp(0.0, 700.0);
  return Duration(
    milliseconds: (journeyReplayLeadMs + segment * (stops - 1)).round(),
  );
}

const journeyReplayLeadMs = 300;
const journeyReplayCap = Duration(seconds: 7);

/// 再生の進み具合[t]（0〜1）で、線の先がどこまで来たか。店の番号で数え、0〜[stops]−1。
/// 1区間ごとに、出だしと着きをゆっくりにする（筆を置いて、引いて、止める）。
double journeyReplayReach(double t, int stops) {
  if (stops <= 1) return 0;
  final total = journeyReplayDuration(stops).inMilliseconds;
  final drawn =
      ((t * total - journeyReplayLeadMs) / (total - journeyReplayLeadMs)).clamp(
        0.0,
        1.0,
      );
  final x = drawn * (stops - 1);
  final whole = x.floorToDouble();
  final f = x - whole;
  return whole + f * f * (3 - 2 * f);
}

/// 線の先が[reach]まで来たときの線の点。途中の区間は、その割合のところまで。
List<GeoPoint> journeyLineTo(List<JourneyStop> stops, double reach) {
  if (stops.isEmpty) return const [];
  final whole = reach.floor().clamp(0, stops.length - 1);
  final points = [for (final stop in stops.take(whole + 1)) stop.location];
  final f = reach - whole;
  if (f > 0 && whole + 1 < stops.length) {
    final from = stops[whole].location;
    final to = stops[whole + 1].location;
    points.add(
      GeoPoint(
        from.latitude + (to.latitude - from.latitude) * f,
        from.longitude + (to.longitude - from.longitude) * f,
      ),
    );
  }
  return points;
}
