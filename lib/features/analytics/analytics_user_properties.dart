import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home_base/home_base_repository.dart';
import '../prefecture/prefecture_book_screen.dart';
import '../records/record_repository.dart';
import '../scoring/scoring_providers.dart';
import '../quests/quests.dart';
import '../records/models.dart';
import '../scoring/points.dart';
import '../scoring/ranks.dart';
import 'analytics_events.dart';

/// 利用者ごとの様子（段位・杯数など）。記録から計算し、数は幅にまとめて送る。
/// ゲームの釣り合い（段位や秘伝を足すか）を決める材料にする。
Map<String, String> analyticsUserProperties({
  required List<ScoredVisit> scored,
  required List<QuestProgress> quests,
  required HomeBaseSetting? homeBase,
  required AdventurerRank rank,
  required int prefectureCount,
}) {
  final bowls = scored.where((e) => e.visit.result == VisitResult.eaten).length;
  final hiden = quests
      .where((p) => p.quest.kind == QuestKind.spot && p.isAchieved)
      .length;
  final kataLevels = quests
      .where((p) => p.quest.kind == QuestKind.standing)
      .fold(0, (sum, p) => sum + p.level);
  return {
    'current_rank': rank.name,
    'total_bowls': bucket(bowls),
    'hiden_count': bucket(hiden),
    'kata_levels_sum': bucket(kataLevels),
    'prefectures_count': bucket(prefectureCount),
    'has_home_base': homeBase == null ? '0' : '1',
  };
}

/// 記録を読み終えるまではnull。
final analyticsUserPropertiesProvider = Provider<Map<String, String>?>((ref) {
  if (!ref.watch(visitsProvider).hasValue) return null;
  return analyticsUserProperties(
    scored: ref.watch(scoredVisitsProvider),
    quests: ref.watch(questProgressProvider),
    homeBase: ref.watch(currentHomeBaseProvider),
    rank: ref.watch(currentRankProvider),
    prefectureCount: ref.watch(prefectureStampsProvider).length,
  );
});
