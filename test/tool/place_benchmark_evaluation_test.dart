import 'package:flutter_test/flutter_test.dart';

import '../../tool/place_benchmark/src/evaluation.dart';
import '../../tool/place_benchmark/src/providers.dart';

const _point = BenchmarkPoint(
  id: 'p',
  label: '新宿駅西口',
  latitude: 35.0,
  longitude: 139.0,
  radii: [300],
  expected: ['豚山', 'はれのひ', 'AFURI'],
);

FoundPlace _place(String name, {bool closed = false}) =>
    FoundPlace(name: name, latitude: 35.0, longitude: 139.0, closed: closed);

ProviderRun _run(List<FoundPlace> places, {String? error, int ms = 1000}) =>
    ProviderRun(
      provider: 'Google',
      pointId: 'p',
      radius: 300,
      elapsed: Duration(milliseconds: ms),
      places: places,
      error: error,
    );

void main() {
  test('店名は、空白・全角英数字・大文字小文字・記号の違いを吸収して比べる', () {
    expect(nameMatches('麺処 さくら 新宿店', 'さくら'), isTrue);
    expect(nameMatches('ＡＦＵＲＩ　新宿', 'afuri'), isTrue);
    expect(nameMatches('麺屋・ふじみち', '麺屋ふじみち'), isTrue);
    expect(nameMatches('一風堂', '一蘭'), isFalse);
    expect(nameMatches('', '豚山'), isFalse);
    // 短い店名が正解に含まれるだけでは、同じ店とみなさない。
    expect(nameMatches('麺屋', '麺屋ふじみち'), isFalse);
    // 長音記号は消さない（「ラーメン」と「ラメン」を取り違えない）。
    expect(normalizeName('ラーメン'), 'ラーメン');
  });

  test('地点の設定を読み込める', () {
    final points = parsePoints('''
{"points": [{"id": "a", "label": "A駅", "latitude": 35, "longitude": 139.5,
  "radii": [300, 1000], "expected": ["豚山"]}]}''');

    expect(points.single.label, 'A駅');
    expect(points.single.longitude, 139.5);
    expect(points.single.radii, [300, 1000]);
    expect(points.single.expected, ['豚山']);
  });

  test('正解リストのうち出た店・出なかった店、閉店、応答時間の中央値、失敗を数える', () {
    final summary = summarize(
      [_point],
      [
        _run([_place('ラーメン豚山'), _place('閉店した店', closed: true)], ms: 3000),
        _run([_place('ラーメン豚山')], ms: 1000),
        _run(const [], error: 'HTTP 504'),
      ],
    ).single;

    expect(summary.places, hasLength(2));
    expect(summary.hits, ['豚山']);
    expect(summary.misses, ['はれのひ', 'AFURI']);
    expect(summary.closedCount, 1);
    expect(summary.medianElapsed, const Duration(milliseconds: 3000));
    expect(summary.failures, 1);
  });

  test('回によって返る店が違うときは、どれかの回で出れば「出た」と数える', () {
    final summary = summarize(
      [_point],
      [
        _run([_place('ほかの店')]),
        _run([_place('ラーメン豚山')]),
      ],
    ).single;

    expect(summary.hits, ['豚山']);
    expect(summary.places, hasLength(2));
  });

  test('表には、全部失敗した組み合わせを「取得失敗」と出す', () {
    final report = markdownReport(
      summarize([_point], [_run(const [], error: 'HTTP 429')]),
    );

    expect(report, contains('| 新宿駅西口 | 300m | Google | 取得失敗 |'));
  });

  test('ホットペッパーの半径は、決まった5段階のうち近いものにする', () {
    expect(HotPepperProvider.rangeFor(300), 1);
    expect(HotPepperProvider.rangeFor(1000), 3);
    expect(HotPepperProvider.rangeFor(5000), 5);
  });

  test('キーが無い提供元は使えないと判定し、理由を示す', () {
    final google = GooglePlacesProvider(null);

    expect(google.isAvailable, isFalse);
    expect(google.unavailableReason, contains('GOOGLE_PLACES_API_KEY'));
    expect(GooglePlacesProvider('key').isAvailable, isTrue);
    expect(OsmProvider().isAvailable, isTrue);
  });
}
