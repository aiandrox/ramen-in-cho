import '../records/models.dart';
import '../scoring/points.dart';
import '../shop_search/geo.dart';
import 'map_camera.dart';

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

/// 旅路の再生で、地図を寄せたまま変えない倍率（地図を開いたときの現在地のまわりより1段広い）。
const journeyFollowZoom = neighborhoodZoom - 1;

/// 店に着いてからピンが刺さりきるまでの長さ（店で止まっている間に刺す）。
const journeyPinDropMs = 350;

/// 1区間を進む長さの下限と上限。遠征のような遠い区間も、上限で切り上げる。
const journeyStepMinMs = 1200;
const journeyStepMaxMs = 2800;

/// 店に着くたびに止まる長さ（1杯目の店も、ここから始める）。
const journeyStopPauseMs = 800;

/// これより遠い区間は、地図を流さずに、線が半分まで来たところで次の店へ移す。
/// 寄せた倍率のまま遠くまで流すと、通り過ぎる地図の画像を大量に取りに行くため。
const journeyPanLimitMeters = 10000.0;

/// 1区間を進む長さ。近いほど短く、遠くても[journeyStepMaxMs]まで。
Duration journeyStepDuration(double meters) => Duration(
  milliseconds: (journeyStepMinMs + meters * 0.8)
      .clamp(journeyStepMinMs, journeyStepMaxMs)
      .round(),
);

/// 旅路の再生の段取り。1杯目の店で止まり、1区間ずつ線をのばしては着いた店で止まる。
/// 進み具合[t]（0〜1）から、線の先と地図の真ん中を決める。
class JourneyReplayPlan {
  JourneyReplayPlan(this.stops)
    : _stepMs = [
        for (var i = 1; i < stops.length; i++)
          journeyStepDuration(
            distanceMeters(stops[i - 1].location, stops[i].location),
          ).inMilliseconds,
      ];

  final List<JourneyStop> stops;
  final List<int> _stepMs;

  Duration get duration => Duration(
    milliseconds:
        journeyStopPauseMs +
        _stepMs.fold(0, (sum, ms) => sum + ms + journeyStopPauseMs),
  );

  /// 線の先がどこまで来たか。店の番号で数え、0〜店の数−1。
  /// 1区間ごとに、出だしと着きをゆっくりにする（筆を置いて、引いて、止める）。
  double reachAt(double t) {
    var elapsed = t * duration.inMilliseconds - journeyStopPauseMs;
    for (var i = 0; i < _stepMs.length; i++) {
      if (elapsed <= 0) return i.toDouble();
      if (elapsed < _stepMs[i]) {
        final f = elapsed / _stepMs[i];
        return i + f * f * (3 - 2 * f);
      }
      elapsed -= _stepMs[i] + journeyStopPauseMs;
    }
    return (stops.length - 1).toDouble();
  }

  /// [order]番目の店のピンが刺さった具合（0〜1）。線が着いた直後、止まっている間に刺す。
  double pinAt(double t, int order) {
    if (order == 0) return 1;
    var arrival = journeyStopPauseMs;
    for (var i = 0; i < order && i < _stepMs.length; i++) {
      arrival += _stepMs[i] + (i == 0 ? 0 : journeyStopPauseMs);
    }
    final elapsed = t * duration.inMilliseconds - arrival;
    return (elapsed / journeyPinDropMs).clamp(0.0, 1.0);
  }

  /// 地図の真ん中に置く点。近い区間は線の先を追い、遠い区間は半分で次の店へ移る。
  GeoPoint cameraAt(double t) {
    final reach = reachAt(t);
    final whole = reach.floor().clamp(0, stops.length - 1);
    final f = reach - whole;
    if (f == 0 || whole + 1 >= stops.length) return stops[whole].location;
    final from = stops[whole].location;
    final to = stops[whole + 1].location;
    if (distanceMeters(from, to) > journeyPanLimitMeters) {
      return f < 0.5 ? from : to;
    }
    return journeyLineTo(stops, reach).last;
  }
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
