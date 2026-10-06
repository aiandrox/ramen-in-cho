import '../prefecture/regions.dart';
import '../quests/quests.dart';
import '../records/models.dart';
import '../scoring/points.dart';
import '../scoring/rank_history.dart';
import 'analytics_events.dart';

/// 利用者ごとの様子（段位・杯数など）。記録から計算し、数は幅にまとめて送る。
/// ゲームの釣り合い（段位や秘伝を足すか）を決める材料にする。
Map<String, String> analyticsUserProperties({
  required List<ScoredVisit> scored,
  required List<QuestProgress> quests,
  required HomeBaseSetting? homeBase,
}) {
  final bowls = scored
      .where((e) => e.visit.result == VisitResult.eaten)
      .length;
  final hiden = quests
      .where((p) => p.quest.kind == QuestKind.spot && p.isAchieved)
      .length;
  final kataLevels = quests
      .where((p) => p.quest.kind == QuestKind.standing)
      .fold(0, (sum, p) => sum + p.level);
  return {
    'current_rank': currentRank(scored).name,
    'total_bowls': bucket(bowls),
    'hiden_count': bucket(hiden),
    'kata_levels_sum': bucket(kataLevels),
    'prefectures_count': bucket(prefectureStamps(scored).length),
    'has_home_base': homeBase == null ? '0' : '1',
  };
}
