import '../records/models.dart';
import '../scoring/points.dart';

/// 地方。印の外枠の形を地方ごとに変える。
enum Region {
  hokkaido,
  tohoku,
  kanto,
  koshinetsu,
  hokuriku,
  tokai,
  kinki,
  chugoku,
  shikoku,
  kyushu,
  okinawa,
}

/// 47都道府県（北から順。都道府県コードの順）。
const prefectureNames = [
  '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県', //
  '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県', //
  '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県', '岐阜県', //
  '静岡県', '愛知県', '三重県', '滋賀県', '京都府', '大阪府', '兵庫県', //
  '奈良県', '和歌山県', '鳥取県', '島根県', '岡山県', '広島県', '山口県', //
  '徳島県', '香川県', '愛媛県', '高知県', '福岡県', '佐賀県', '長崎県', //
  '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県', //
];

/// 地方。中部は甲信越（新潟・長野・山梨）・北陸（富山・石川・福井）・東海（岐阜・静岡・愛知・三重）に分け、三重は東海に入れる。
Region? regionOf(String prefecture) {
  final code = prefectureNames.indexOf(prefecture) + 1;
  if (code == 0) return null;
  if (code == 1) return Region.hokkaido;
  if (code <= 7) return Region.tohoku;
  if (code <= 14) return Region.kanto;
  if (code == 15 || code == 19 || code == 20) return Region.koshinetsu;
  if (code <= 18) return Region.hokuriku;
  if (code <= 24) return Region.tokai;
  if (code <= 30) return Region.kinki;
  if (code <= 35) return Region.chugoku;
  if (code <= 39) return Region.shikoku;
  if (code <= 46) return Region.kyushu;
  return Region.okinawa;
}

/// 地方に入る都道府県（北から順）。
List<String> prefecturesIn(Region region) => [
  for (final name in prefectureNames)
    if (regionOf(name) == region) name,
];

/// 印に書く短い名前。「都・府・県」を落とす（北海道はそのまま）。
String shortPrefectureName(String prefecture) {
  if (prefecture == '北海道') return prefecture;
  final last = prefecture[prefecture.length - 1];
  return '都府県'.contains(last)
      ? prefecture.substring(0, prefecture.length - 1)
      : prefecture;
}

/// 都道府県の印帳の1件。その都道府県で初めて食べた1杯と、食べた杯数。
class PrefectureStamp {
  const PrefectureStamp({required this.first, required this.bowls});

  final ScoredVisit first;

  /// 食べた記録（古い順）。撤退は入れない。
  final List<ScoredVisit> bowls;
}

/// 食べた記録を都道府県ごとにまとめる（[scored]は古い順）。都道府県のわからない店は入れない。
Map<String, PrefectureStamp> prefectureStamps(List<ScoredVisit> scored) {
  final bowls = <String, List<ScoredVisit>>{};
  for (final entry in scored) {
    final prefecture = entry.prefecture;
    if (prefecture == null || entry.visit.result != VisitResult.eaten) {
      continue;
    }
    bowls.putIfAbsent(prefecture, () => []).add(entry);
  }
  return {
    for (final MapEntry(:key, :value) in bowls.entries)
      key: PrefectureStamp(first: value.first, bowls: value),
  };
}
