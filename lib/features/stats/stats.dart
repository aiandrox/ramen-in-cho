import '../records/models.dart';
import '../records/wait_time.dart';
import '../scoring/points.dart';
import '../scoring/ranks.dart';

class StyleShare {
  const StyleShare({
    required this.style,
    required this.count,
    required this.ratio,
  });

  /// 系統。系統をつけていない記録はnullにまとめる。
  final RamenStyle? style;
  final int count;

  /// 食べた記録全体に占める割合（0〜1）。
  final double ratio;
}

class FrequentShop {
  const FrequentShop({
    required this.shop,
    required this.count,
    required this.lastVisitId,
  });

  final Shop shop;
  final int count;

  /// 店のページを開くときに選んでおく1杯（いちばん新しい1杯）。
  final String lastVisitId;
}

class RankedShop {
  const RankedShop({
    required this.shop,
    required this.rank,
    required this.bestPoints,
    required this.count,
    required this.bestVisitId,
  });

  final Shop shop;
  final ShopRank rank;

  /// 最高ポイントを得た1杯。店のページを開くときに選んでおく。
  final String bestVisitId;

  /// その店で1杯に得た最高ポイント。
  final int bestPoints;
  final int count;
}

Iterable<ScoredVisit> _eaten(List<ScoredVisit> scored) =>
    scored.where((entry) => entry.visit.result == VisitResult.eaten);

int totalBowls(List<ScoredVisit> scored) => _eaten(scored).length;

int bowlsInYear(List<ScoredVisit> scored, int year) =>
    _eaten(scored).where((entry) => entry.visit.eatenAt.year == year).length;

/// 系統ごとの杯数と割合。杯数の多い順。
List<StyleShare> styleShares(List<ScoredVisit> scored) {
  final counts = <RamenStyle?, int>{};
  var total = 0;
  for (final entry in _eaten(scored)) {
    counts.update(entry.visit.style, (count) => count + 1, ifAbsent: () => 1);
    total++;
  }
  final shares = [
    for (final MapEntry(key: style, value: count) in counts.entries)
      StyleShare(style: style, count: count, ratio: count / total),
  ];
  // 同数のときは、系統の定義順（系統なしは最後）にして並びを安定させる。
  int order(RamenStyle? style) => style?.index ?? RamenStyle.values.length;
  shares.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : order(a.style).compareTo(order(b.style));
  });
  return shares;
}

/// 2杯以上食べた店を、回数の多い順に返す（1杯だけの店は「よく行く」と言えないので除く）。
/// 同数なら、最近行った店を先にする。
List<FrequentShop> frequentShops(List<ScoredVisit> scored, {int limit = 5}) {
  final counts = <String, int>{};
  final lastVisit = <String, Visit>{};
  final shops = <String, Shop>{};
  for (final entry in _eaten(scored)) {
    final shopId = entry.visit.shopId;
    counts.update(shopId, (count) => count + 1, ifAbsent: () => 1);
    shops[shopId] = entry.shop;
    final last = lastVisit[shopId];
    if (last == null || entry.visit.eatenAt.isAfter(last.eatenAt)) {
      lastVisit[shopId] = entry.visit;
    }
  }
  final ids =
      [
        for (final MapEntry(:key, :value) in counts.entries)
          if (value >= 2) key,
      ]..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0
            ? byCount
            : lastVisit[b]!.eatenAt.compareTo(lastVisit[a]!.eatenAt);
      });
  return [
    for (final id in ids.take(limit))
      FrequentShop(
        shop: shops[id]!,
        count: counts[id]!,
        lastVisitId: lastVisit[id]!.id,
      ),
  ];
}

/// 食べたことのある店を、ランクの高い順（同じランクなら最高ポイントの高い順）に返す。
List<RankedShop> rankedShops(List<ScoredVisit> scored) {
  final best = <String, int>{};
  final bestVisit = <String, String>{};
  final counts = <String, int>{};
  final shops = <String, Shop>{};
  for (final entry in _eaten(scored)) {
    final shopId = entry.visit.shopId;
    final points = entry.points.total;
    if (points > (best[shopId] ?? -1)) {
      best[shopId] = points;
      bestVisit[shopId] = entry.visit.id;
    }
    counts.update(shopId, (count) => count + 1, ifAbsent: () => 1);
    shops[shopId] = entry.shop;
  }
  final ranked = [
    for (final MapEntry(key: shopId, value: points) in best.entries)
      RankedShop(
        shop: shops[shopId]!,
        rank: shopRankFor(points),
        bestPoints: points,
        count: counts[shopId]!,
        bestVisitId: bestVisit[shopId]!,
      ),
  ];
  ranked.sort((a, b) {
    final byPoints = b.bestPoints.compareTo(a.bestPoints);
    return byPoints != 0 ? byPoints : a.shop.name.compareTo(b.shop.name);
  });
  return ranked;
}

class PersonalBest {
  const PersonalBest({required this.entry, required this.value});

  final ScoredVisit entry;
  final int value;
}

class PersonalBests {
  const PersonalBests({
    this.longestWait,
    this.highestPoints,
    this.mostRetreats,
  });

  /// 待ち時間が最も長かった記録（分）。
  final PersonalBest? longestWait;

  /// 1杯で最も高いポイントを得た記録。
  final PersonalBest? highestPoints;

  /// 撤退の回数が最も多い店の、その回数に達した撤退の記録（回数）。
  final PersonalBest? mostRetreats;
}

/// 自分の記録の中の最高。同じ値なら先に達成した記録を残す。
PersonalBests personalBests(List<ScoredVisit> scored) {
  PersonalBest? longestWait;
  PersonalBest? highestPoints;
  PersonalBest? mostRetreats;
  final retreats = <String, int>{};
  for (final entry in scored) {
    if (entry.visit.result == VisitResult.retreated) {
      final count = retreats.update(
        entry.visit.shopId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (count > (mostRetreats?.value ?? 0)) {
        mostRetreats = PersonalBest(entry: entry, value: count);
      }
      continue;
    }
    final wait = waitMinutes(entry.visit);
    if (wait != null && wait > (longestWait?.value ?? -1)) {
      longestWait = PersonalBest(entry: entry, value: wait);
    }
    final points = entry.points.total;
    if (points > (highestPoints?.value ?? -1)) {
      highestPoints = PersonalBest(entry: entry, value: points);
    }
  }
  return PersonalBests(
    longestWait: longestWait,
    highestPoints: highestPoints,
    mostRetreats: mostRetreats,
  );
}
