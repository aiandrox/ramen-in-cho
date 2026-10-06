import '../records/models.dart';
import 'points.dart';

/// 段位。入門から五級〜一級、初段〜九段を経て、師範代・免許皆伝へ。
/// ふつうの1杯（20〜30点）で数えて、級は1〜3杯ごと、段は4杯ほどから少しずつ間をあけ、
/// 免許皆伝はおよそ140杯で届く。点の多い1杯でも上がるのは1つだけ（rank_history.dart）。
enum AdventurerRank {
  apprentice(0),
  kyu5(15),
  kyu4(65),
  kyu3(115),
  kyu2(185),
  kyu1(260),
  dan1(360),
  dan2(485),
  dan3(635),
  dan4(810),
  dan5(1010),
  dan6(1260),
  dan7(1560),
  dan8(1910),
  dan9(2310),
  master(2810),
  grandmaster(3510);

  const AdventurerRank(this.requiredPoints);

  final int requiredPoints;

  /// 級（五級〜一級）か。
  bool get isKyu => index >= kyu5.index && index <= kyu1.index;

  /// 次のランク。最高ランクならnull。
  AdventurerRank? get next =>
      index + 1 < values.length ? values[index + 1] : null;
}

enum ShopRank {
  s(60),
  a(40),
  b(25),
  c(0);

  const ShopRank(this.requiredPoints);

  final int requiredPoints;
}

ShopRank shopRankFor(int bestPoints) =>
    ShopRank.values.firstWhere((rank) => bestPoints >= rank.requiredPoints);

/// 店ごとのランク。その店で得た最高ポイントで決まる。食べた記録の無い店は含めない。
Map<String, ShopRank> shopRanks(List<ScoredVisit> scored) {
  final best = <String, int>{};
  for (final entry in scored) {
    if (entry.visit.result != VisitResult.eaten) continue;
    final shopId = entry.visit.shopId;
    final points = entry.points.total;
    if (points > (best[shopId] ?? -1)) best[shopId] = points;
  }
  return best.map((shopId, points) => MapEntry(shopId, shopRankFor(points)));
}
