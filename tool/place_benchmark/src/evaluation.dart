import 'dart:convert';

/// 検証する地点。`expected` は、その地点で必ず出てほしい店名の一部（正解リスト）。
class BenchmarkPoint {
  const BenchmarkPoint({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radii,
    required this.expected,
  });

  factory BenchmarkPoint.fromJson(Map<String, Object?> json) => BenchmarkPoint(
    id: json['id']! as String,
    label: json['label']! as String,
    latitude: (json['latitude']! as num).toDouble(),
    longitude: (json['longitude']! as num).toDouble(),
    radii: [for (final r in json['radii']! as List) (r as num).toInt()],
    expected: [for (final e in (json['expected'] ?? []) as List) e as String],
  );

  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final List<int> radii;
  final List<String> expected;
}

List<BenchmarkPoint> parsePoints(String body) {
  final json = jsonDecode(body) as Map<String, Object?>;
  return [
    for (final point in json['points']! as List)
      BenchmarkPoint.fromJson(point as Map<String, Object?>),
  ];
}

/// 提供元が返した1軒。
class FoundPlace {
  const FoundPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category,
    this.closed = false,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? category;
  final bool closed;

  Map<String, Object?> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'category': category,
    'closed': closed,
  };
}

/// 1回の問い合わせの結果。
class ProviderRun {
  const ProviderRun({
    required this.provider,
    required this.pointId,
    required this.radius,
    required this.elapsed,
    this.places = const [],
    this.error,
  });

  final String provider;
  final String pointId;
  final int radius;
  final Duration elapsed;
  final List<FoundPlace> places;
  final String? error;

  bool get failed => error != null;

  Map<String, Object?> toJson() => {
    'provider': provider,
    'pointId': pointId,
    'radius': radius,
    'elapsedMs': elapsed.inMilliseconds,
    'error': error,
    'places': [for (final place in places) place.toJson()],
  };
}

/// 表記ゆれ（空白・全角英数字・大文字小文字・記号）を吸収して比べるための形にする。
String normalizeName(String name) {
  final buffer = StringBuffer();
  for (final rune in name.runes) {
    var code = rune;
    // 全角の英数字・記号（！〜～）を半角に。
    if (code >= 0xFF01 && code <= 0xFF5E) code -= 0xFEE0;
    final char = String.fromCharCode(code).toLowerCase();
    if (RegExp(r'[\s　・･\-－‐_.,、。()（）「」『』\[\]【】!?!？&＆/]').hasMatch(char)) {
      continue;
    }
    buffer.write(char);
  }
  return buffer.toString();
}

/// 見つかった店名に、正解リストの店名が含まれていれば同じ店とみなす。
/// 逆向き（短い店名が正解に含まれる）は、「麺屋」だけで「麺屋ふじみち」に当たってしまうので数えない。
bool nameMatches(String found, String expected) {
  final a = normalizeName(found);
  final b = normalizeName(expected);
  if (a.isEmpty || b.isEmpty) return false;
  return a.contains(b);
}

/// 地点×半径×提供元ごとの集計。
class RunSummary {
  const RunSummary({
    required this.provider,
    required this.point,
    required this.radius,
    required this.runs,
  });

  final String provider;
  final BenchmarkPoint point;
  final int radius;
  final List<ProviderRun> runs;

  List<ProviderRun> get _succeeded => [
    for (final run in runs)
      if (!run.failed) run,
  ];

  int get failures => runs.length - _succeeded.length;

  /// 成功したすべての回で返った店を合わせたもの（同じ店名・ほぼ同じ位置は1軒）。
  List<FoundPlace> get places {
    final seen = <String>{};
    return [
      for (final run in _succeeded)
        for (final place in run.places)
          if (seen.add(
            '${normalizeName(place.name)}@'
            '${place.latitude.toStringAsFixed(4)},'
            '${place.longitude.toStringAsFixed(4)}',
          ))
            place,
    ];
  }

  /// 正解リストのうち、この半径で出てきた店名。
  List<String> get hits => [
    for (final expected in point.expected)
      if (places.any((place) => nameMatches(place.name, expected))) expected,
  ];

  List<String> get misses => [
    for (final expected in point.expected)
      if (!hits.contains(expected)) expected,
  ];

  int get closedCount => places.where((place) => place.closed).length;

  Duration? get medianElapsed {
    final times = [for (final run in _succeeded) run.elapsed]..sort();
    return times.isEmpty ? null : times[times.length ~/ 2];
  }
}

List<RunSummary> summarize(
  List<BenchmarkPoint> points,
  List<ProviderRun> runs,
) {
  final providers = {for (final run in runs) run.provider};
  return [
    for (final point in points)
      for (final radius in point.radii)
        for (final provider in providers)
          RunSummary(
            provider: provider,
            point: point,
            radius: radius,
            runs: [
              for (final run in runs)
                if (run.provider == provider &&
                    run.pointId == point.id &&
                    run.radius == radius)
                  run,
            ],
          ),
  ].where((summary) => summary.runs.isNotEmpty).toList();
}

/// #56 に貼れる Markdown の表。
String markdownReport(List<RunSummary> summaries) {
  final buffer = StringBuffer()
    ..writeln('| 地点 | 半径 | 提供元 | 件数 | 正解リストで出た店 | 出なかった店 | 閉店 | 応答（中央値） | 失敗 |')
    ..writeln('|---|---|---|---|---|---|---|---|---|');
  for (final s in summaries) {
    final elapsed = s.medianElapsed;
    if (s.failures == s.runs.length) {
      buffer.writeln(
        '| ${s.point.label} | ${s.radius}m | ${s.provider} | 取得失敗 | — | — | — | — '
        '| ${s.failures}/${s.runs.length} |',
      );
      continue;
    }
    buffer.writeln(
      '| ${s.point.label} | ${s.radius}m | ${s.provider} | ${s.places.length} '
      '| ${s.point.expected.isEmpty ? '—' : '${s.hits.length}/${s.point.expected.length} ${s.hits.join('、')}'} '
      '| ${s.misses.isEmpty ? '—' : s.misses.join('、')} '
      '| ${s.closedCount} '
      '| ${elapsed == null ? '—' : '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}秒'} '
      '| ${s.failures}/${s.runs.length} |',
    );
  }
  return buffer.toString();
}
