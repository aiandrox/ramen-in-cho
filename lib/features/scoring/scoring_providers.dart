import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home_base/home_base_repository.dart';
import '../prefecture/prefectures.dart';
import '../quests/quests.dart';
import '../records/record_repository.dart';
import '../wishes/wish_repository.dart';
import 'points.dart';
import 'rank_history.dart';
import 'ranks.dart';

/// 採点済みの全記録（古い順）。ポイントは保存せず、記録が変わるたびに計算し直す。
final scoredVisitsProvider = Provider<List<ScoredVisit>>(
  (ref) => scoreVisits(
    ref.watch(visitsProvider).value ?? const [],
    wishes: ref.watch(wishesProvider).value ?? const [],
    homeBases: ref.watch(homeBaseSettingsProvider).value ?? const [],
    prefectureOf: ref.watch(prefectureIndexProvider).prefectureOf,
  ),
);

final totalPointsProvider = Provider<int>(
  (ref) => totalPoints(ref.watch(scoredVisitsProvider)),
);

/// 今の段位（1杯で1つずつ上がる）。
final currentRankProvider = Provider<AdventurerRank>(
  (ref) => currentRank(ref.watch(scoredVisitsProvider)),
);

/// 記録のIDから、その記録の採点結果を引く。
final scoredVisitByIdProvider = Provider<Map<String, ScoredVisit>>(
  (ref) => {
    for (final entry in ref.watch(scoredVisitsProvider)) entry.visit.id: entry,
  },
);

/// 全クエストの達成状況。保存せず、記録から毎回計算する。
final questProgressProvider = Provider<List<QuestProgress>>(
  (ref) => evaluateQuests(
    ref.watch(scoredVisitsProvider),
    homeBases: ref.watch(homeBaseSettingsProvider).value ?? const [],
  ),
);
