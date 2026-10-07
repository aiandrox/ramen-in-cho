import '../quests/quests.dart';
import '../records/models.dart';
import '../streak/daily_streak.dart';
import 'points.dart';
import 'rank_history.dart';
import 'ranks.dart';

/// 何枚もの写真をまとめて記録した結果。累計・段位・型と秘伝は、まとめた記録が無かった場合との差で求める。
class BatchOutcome {
  const BatchOutcome({
    required this.scored,
    required this.totalBefore,
    required this.totalAfter,
    required this.rankBefore,
    required this.rankAfter,
    this.questLevelUps = const [],
    this.bestDailyStreakBefore = 0,
    this.bestDailyStreakAfter = 0,
  });

  /// まとめて記録した杯（食べた順）。
  final List<ScoredVisit> scored;
  final int totalBefore;
  final int totalAfter;
  final AdventurerRank rankBefore;
  final AdventurerRank rankAfter;
  final List<QuestLevelUp> questLevelUps;
  final int bestDailyStreakBefore;
  final int bestDailyStreakAfter;

  /// まとめた杯それぞれの修行点の合計。
  int get points => scored.fold(0, (sum, e) => sum + e.points.total);

  /// 上がった段位の数（1杯で上がるのは1つだけなので、杯数より多くはならない）。
  int get rankSteps {
    final steps = rankAfter.index - rankBefore.index;
    return steps < 0 ? 0 : steps;
  }

  bool get isRankUp => rankSteps > 0;

  /// まとめた杯で叶った願（食べた順）。
  List<ScoredVisit> get wishFulfillments => [
    for (final entry in scored)
      if (entry.fulfilledWish != null) entry,
  ];

  bool get revealsHealthyLife =>
      bestDailyStreakBefore < healthyLifeDays &&
      bestDailyStreakAfter >= healthyLifeDays;
}

/// [visitIds]の記録が1件も無ければnull。
BatchOutcome? computeBatchOutcome(
  List<VisitWithShop> all,
  Iterable<String> visitIds, {
  List<Wish> wishes = const [],
  List<HomeBaseSetting> homeBases = const [],
  String? Function(Shop shop) prefectureOf = noPrefecture,
}) {
  final ids = visitIds.toSet();
  List<ScoredVisit> score(List<VisitWithShop> entries) => scoreVisits(
    entries,
    wishes: wishes,
    homeBases: homeBases,
    prefectureOf: prefectureOf,
  );
  final scoredAll = score(all);
  final batch = [
    for (final entry in scoredAll)
      if (ids.contains(entry.visit.id)) entry,
  ];
  if (batch.isEmpty) return null;
  final scoredOthers = score([
    for (final entry in all)
      if (!ids.contains(entry.visit.id)) entry,
  ]);
  return BatchOutcome(
    scored: batch,
    totalBefore: totalPoints(scoredOthers),
    totalAfter: totalPoints(scoredAll),
    rankBefore: currentRank(scoredOthers),
    rankAfter: currentRank(scoredAll),
    questLevelUps: newlyAchievedLevels(
      before: evaluateQuests(scoredOthers, homeBases: homeBases),
      after: evaluateQuests(scoredAll, homeBases: homeBases),
    ),
    bestDailyStreakBefore: bestDailyStreak(scoredOthers),
    bestDailyStreakAfter: bestDailyStreak(scoredAll),
  );
}
