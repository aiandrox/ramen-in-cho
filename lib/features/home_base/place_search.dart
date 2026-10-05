import 'dart:convert';

import '../shop_search/geo.dart';

/// 拠点の候補の種類。
enum PlaceKind { station, city, town, village, suburb }

/// 拠点の候補（駅や市町村など）。
class PlaceCandidate {
  const PlaceCandidate({
    required this.name,
    required this.kind,
    required this.location,
    this.operators = const [],
  });

  /// 画面に出し、拠点の名前として残す名前（「横浜駅」「札幌市」など）。
  final String name;
  final PlaceKind kind;
  final GeoPoint location;

  /// 駅の運営会社（同じ名前の駅を見分けるため）。
  final List<String> operators;
}

/// 同じ名前の候補を1つにまとめる距離。同じ駅の路線ごとの点をまとめる。
const _samePlaceMeters = 2000;
const _maxCandidates = 30;
const _placeSuffixes = ['市', '町', '村', '区'];

/// 問い合わせの文字列を壊す記号は、駅や市町村の名前に出てこないので取り除く。
String _cleanName(String input) =>
    input.replaceAll(RegExp(r'[\\"]'), '').replaceAll('　', ' ').trim();

/// 「横浜駅」と打っても「横浜」と打っても同じように探す。
String placeSearchStem(String input) {
  final cleaned = _cleanName(input);
  return cleaned.endsWith('駅') && cleaned.length > 1
      ? cleaned.substring(0, cleaned.length - 1)
      : cleaned;
}

/// 探す名前。全国を名前の一部で探すと公開サーバーでは時間切れになるため、名前がぴったり合うものだけを探す。
/// 「札幌」なら駅の「札幌」と、市町村などの「札幌」「札幌市」「札幌町」「札幌村」「札幌区」。
({Set<String> stations, Set<String> places}) placeSearchNames(String input) {
  final stem = placeSearchStem(input);
  if (stem.isEmpty) return (stations: <String>{}, places: <String>{});
  final bare =
      stem.length > 1 && _placeSuffixes.any((suffix) => stem.endsWith(suffix))
      ? stem.substring(0, stem.length - 1)
      : stem;
  return (
    stations: {stem, bare},
    places: {stem, bare, for (final suffix in _placeSuffixes) '$bare$suffix'},
  );
}

String buildPlaceSearchQuery(String input, {int timeoutSeconds = 23}) {
  final names = placeSearchNames(input);
  final stations = [
    for (final name in names.stations) ...[
      'nwr["name"="$name"]["railway"="station"];',
      'nwr["name"="$name"]["public_transport"="station"];',
    ],
  ];
  final places = [
    for (final name in names.places) 'node["name"="$name"]["place"];',
  ];
  return '[out:json][timeout:$timeoutSeconds];'
      '(${stations.join()}${places.join()});'
      'out center tags 100;';
}

/// Overpass の応答から拠点の候補を作る。同じ名前で近いものはまとめ、名前がぴったり合うもの・駅を先にし、
/// [near]（現在地）が分かれば、その中で近い順にする。
List<PlaceCandidate> parsePlaceSearchResponse(
  String body,
  String input, {
  GeoPoint? near,
}) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Overpassの応答がオブジェクトではありません');
  }
  final remark = decoded['remark'];
  if (remark is String && remark.contains('error')) {
    throw FormatException('Overpassの検索が失敗しました: $remark');
  }
  final elements = decoded['elements'];
  if (elements is! List) {
    throw const FormatException('Overpassの応答にelementsがありません');
  }
  final candidates = <PlaceCandidate>[];
  for (final element in elements) {
    if (element is! Map<String, dynamic>) continue;
    final tags = element['tags'];
    final center = element['center'];
    final position = center is Map<String, dynamic> ? center : element;
    final lat = position['lat'];
    final lon = position['lon'];
    if (tags is! Map<String, dynamic> || lat is! num || lon is! num) continue;
    if (!_isInJapan(lat, lon)) continue;
    final rawName = tags['name'];
    if (rawName is! String || rawName.trim().isEmpty) continue;
    final kind = _kindOf(tags);
    if (kind == null) continue;
    final name = rawName.trim();
    final location = GeoPoint(lat.toDouble(), lon.toDouble());
    final operator = tags['operator'];
    final operators = [
      if (kind == PlaceKind.station &&
          operator is String &&
          operator.isNotEmpty)
        ...operator.split(';').map((o) => o.trim()).where((o) => o.isNotEmpty),
    ];
    final displayName = kind == PlaceKind.station && !name.endsWith('駅')
        ? '$name駅'
        : name;
    final index = candidates.indexWhere(
      (c) =>
          c.name == displayName &&
          distanceMeters(c.location, location) <= _samePlaceMeters,
    );
    if (index < 0) {
      candidates.add(
        PlaceCandidate(
          name: displayName,
          kind: kind,
          location: location,
          operators: operators,
        ),
      );
      continue;
    }
    final existing = candidates[index];
    candidates[index] = PlaceCandidate(
      name: existing.name,
      kind: existing.kind,
      location: existing.location,
      operators: {...existing.operators, ...operators}.toList(),
    );
  }
  final stem = placeSearchStem(input);
  int rank(PlaceCandidate c) {
    final exact = c.name == stem || c.name == '$stem駅';
    return (exact ? 0 : 2) + (c.kind == PlaceKind.station ? 0 : 1);
  }

  final indexed = candidates.indexed.toList()
    ..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      if (byRank != 0) return byRank;
      if (near != null) {
        final byDistance = distanceMeters(
          near,
          a.$2.location,
        ).compareTo(distanceMeters(near, b.$2.location));
        if (byDistance != 0) return byDistance;
      }
      return a.$1.compareTo(b.$1);
    });
  return [for (final (_, c) in indexed.take(_maxCandidates)) c];
}

/// 同じ名前の外国の村などを除く（日本のおおよその範囲）。
bool _isInJapan(num lat, num lon) =>
    lat >= 20 && lat <= 46 && lon >= 122 && lon <= 154;

/// 駅と、市町村・地区だけを候補にする（集落や字のような小さな地名は除く）。
PlaceKind? _kindOf(Map<String, dynamic> tags) {
  if (tags['railway'] == 'station' || tags['public_transport'] == 'station') {
    return PlaceKind.station;
  }
  return switch (tags['place']) {
    'city' => PlaceKind.city,
    'town' => PlaceKind.town,
    'village' => PlaceKind.village,
    'suburb' || 'quarter' => PlaceKind.suburb,
    _ => null,
  };
}
