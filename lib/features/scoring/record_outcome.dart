import '../quests/quests.dart';
import '../records/models.dart';
import 'points.dart';
import 'rank_history.dart';
import 'ranks.dart';
import '../streak/daily_streak.dart';

/// 1件の記録を保存した結果。得たポイントと、累計・ランクの変化。
class RecordOutcome {
  const RecordOutcome({
    required this.scored,
    required this.totalBefore,
    required this.totalAfter,
    required this.rankBefore,
    required this.rankAfter,
    this.questLevelUps = const [],
    this.bestDailyStreakBefore = 0,
    this.bestDailyStreakAfter = 0,
  });

  final ScoredVisit scored;
  final int totalBefore;
  final int totalAfter;

  /// この記録で新しく達成・レベルアップしたクエスト。
  final List<QuestLevelUp> questLevelUps;

  /// 毎日続けて食べた日数の最高記録の、この記録の前とあと。
  final int bestDailyStreakBefore;
  final int bestDailyStreakAfter;

  /// この1杯で、隠し要素「毎日ラーメン健康生活」が初めて出現したか。
  bool get revealsHealthyLife =>
      bestDailyStreakBefore < healthyLifeDays &&
      bestDailyStreakAfter >= healthyLifeDays;

  final AdventurerRank rankBefore;
  final AdventurerRank rankAfter;

  bool get isRankUp => rankAfter.index > rankBefore.index;
}

/// [visitId]の記録が無ければnull。累計の変化は、その記録が無かった場合との差で求める
/// （過去の日時の記録を足すと、ほかの記録の初訪問ボーナスが動くことがあるため）。
RecordOutcome? computeRecordOutcome(
  List<VisitWithShop> all,
  String visitId, {
  List<Wish> wishes = const [],
  List<HomeBaseSetting> homeBases = const [],
}) {
  final scoredAll = scoreVisits(all, wishes: wishes, homeBases: homeBases);
  final scored = scoredAll.where((e) => e.visit.id == visitId).firstOrNull;
  if (scored == null) return null;
  final others = [
    for (final entry in all)
      if (entry.visit.id != visitId) entry,
  ];
  final scoredOthers = scoreVisits(
    others,
    wishes: wishes,
    homeBases: homeBases,
  );
  return RecordOutcome(
    scored: scored,
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
