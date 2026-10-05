import '../home_base/home_base.dart';
import '../records/models.dart';
import '../records/wait_time.dart';

/// 1件の記録で得たポイントの内訳。撤退は全て0。
class PointsBreakdown {
  const PointsBreakdown({
    required this.base,
    required this.waitBonus,
    required this.limitedBonus,
    required this.firstVisitBonus,
    required this.retryBonus,
    this.expeditionBonus = 0,
    this.earlyBonus = 0,
    this.lateNightBonus = 0,
    required this.hoursConditions,
  });

  static const zero = PointsBreakdown(
    base: 0,
    waitBonus: 0,
    limitedBonus: 0,
    firstVisitBonus: 0,
    retryBonus: 0,
    hoursConditions: {},
  );

  final int base;
  final int waitBonus;
  final int limitedBonus;
  final int firstVisitBonus;
  final int retryBonus;
  final int expeditionBonus;
  final int earlyBonus;
  final int lateNightBonus;
  final Set<HoursCondition> hoursConditions;

  int get subtotal =>
      base +
      waitBonus +
      limitedBonus +
      firstVisitBonus +
      retryBonus +
      expeditionBonus +
      earlyBonus +
      lateNightBonus;

  /// 倍率をかけたあとの小数は切り捨てる。
  int get total => subtotal * _multiplierTenths(hoursConditions) ~/ 10;
}

const basePoints = 10;
const waitBonusPerTenMinutes = 5;
const limitedBonus = 20;
const firstVisitBonus = 10;
const retryBonus = 15;

/// 押さなくても、記録の時刻と場所から自動でつく難しさ。
const expeditionBonus = 20;
const earlyBonus = 10;
const lateNightBonus = 10;

/// 朝ラー（5〜9時台）と深夜（0〜4時台）。
bool isEarlyHour(DateTime at) => at.hour >= 5 && at.hour < 10;
bool isLateNightHour(DateTime at) => at.hour < 5;

/// 攻略しにくさの条件ごとの倍率の上乗せ（10分の1単位）。条件の分だけ足し、上限で止める。
const hoursConditionWeights = <HoursCondition, int>{
  HoursCondition.lunchOnly: 3,
  HoursCondition.nightOnly: 2,
  HoursCondition.weekdaysOnly: 5,
  HoursCondition.weekendsOnly: 2,
  HoursCondition.fewDays: 5,
  HoursCondition.irregular: 5,
  HoursCondition.badAccess: 5,
};
const _maxMultiplierTenths = 25;

/// 倍率（×1〜×2.5）を整数で扱うため10倍した値。
int _multiplierTenths(Set<HoursCondition> conditions) {
  final total =
      10 +
      conditions.fold<int>(
        0,
        (sum, c) => sum + (hoursConditionWeights[c] ?? 0),
      );
  return total > _maxMultiplierTenths ? _maxMultiplierTenths : total;
}

/// 攻略しにくさの条件による倍率。条件ごとの上乗せを足し、最大×2.5。
double hoursMultiplier(Set<HoursCondition> conditions) =>
    _multiplierTenths(conditions) / 10;

PointsBreakdown calculatePoints({
  required Visit visit,
  required Set<HoursCondition> hoursConditions,
  required bool isFirstVisit,
  required bool isRetrySuccess,
  bool isExpedition = false,
}) {
  if (visit.result != VisitResult.eaten) return PointsBreakdown.zero;
  return PointsBreakdown(
    base: basePoints,
    waitBonus: (waitMinutes(visit) ?? 0) ~/ 10 * waitBonusPerTenMinutes,
    limitedBonus: visit.isLimited ? limitedBonus : 0,
    firstVisitBonus: isFirstVisit ? firstVisitBonus : 0,
    retryBonus: isRetrySuccess ? retryBonus : 0,
    expeditionBonus: isExpedition ? expeditionBonus : 0,
    earlyBonus: isEarlyHour(visit.eatenAt) ? earlyBonus : 0,
    lateNightBonus: isLateNightHour(visit.eatenAt) ? lateNightBonus : 0,
    hoursConditions: hoursConditions,
  );
}

/// 記録1件ごとの採点結果。
class ScoredVisit {
  const ScoredVisit({
    required this.visit,
    required this.shop,
    required this.points,
    required this.isFirstVisit,
    required this.isRetrySuccess,
    this.fulfilledWish,
    this.homeBase,
  });

  final Visit visit;
  final Shop shop;
  final PointsBreakdown points;

  /// その店で最初の「食べた」記録か。
  final bool isFirstVisit;

  /// 同じ店での直前の記録が撤退だったか。
  final bool isRetrySuccess;

  /// この1杯で叶った願。
  final Wish? fulfilledWish;

  /// この1杯を食べた時点で効いていた拠点。
  final HomeBaseSetting? homeBase;

  /// 拠点から遠い店で食べた1杯か（遠征）。
  bool get isExpedition =>
      visit.result == VisitResult.eaten && isFarFromHomeBase(homeBase, shop);
}

/// 全記録を採点し、古い順に返す。初訪問と再挑戦成功は店ごとの記録の順番で決まるため、
/// 1件だけでは採点できない。[wishes]を渡すと、どの1杯で叶った願かも添える。
/// 遠征は、その1杯を食べた時点で効いていた[homeBases]の拠点から決める。
List<ScoredVisit> scoreVisits(
  List<VisitWithShop> entries, {
  List<Wish> wishes = const [],
  List<HomeBaseSetting> homeBases = const [],
}) {
  final ordered = [...entries]
    ..sort((a, b) {
      final byEaten = a.visit.eatenAt.compareTo(b.visit.eatenAt);
      if (byEaten != 0) return byEaten;
      return a.visit.createdAt.compareTo(b.visit.createdAt);
    });
  final eatenShops = <String>{};
  final lastResult = <String, VisitResult>{};
  final scored = <ScoredVisit>[];
  final wishByVisit = {for (final wish in wishes) ?wish.fulfilledVisitId: wish};
  for (final entry in ordered) {
    final visit = entry.visit;
    final isEaten = visit.result == VisitResult.eaten;
    final fulfilledWish = isEaten ? wishByVisit[visit.id] : null;
    final isFirstVisit = isEaten && !eatenShops.contains(visit.shopId);
    final isRetrySuccess =
        isEaten && lastResult[visit.shopId] == VisitResult.retreated;
    final homeBase = homeBaseAt(homeBases, visit.eatenAt);
    scored.add(
      ScoredVisit(
        visit: visit,
        shop: entry.shop,
        points: calculatePoints(
          visit: visit,
          hoursConditions: entry.shop.hoursConditions,
          isFirstVisit: isFirstVisit,
          isRetrySuccess: isRetrySuccess,
          isExpedition: isFarFromHomeBase(homeBase, entry.shop),
        ),
        isFirstVisit: isFirstVisit,
        isRetrySuccess: isRetrySuccess,
        fulfilledWish: fulfilledWish,
        homeBase: homeBase,
      ),
    );
    if (isEaten) eatenShops.add(visit.shopId);
    lastResult[visit.shopId] = visit.result;
  }
  return scored;
}

int totalPoints(List<ScoredVisit> scored) =>
    scored.fold(0, (sum, entry) => sum + entry.points.total);
