import 'dart:math' as math;

import '../home_base/home_base.dart';
import '../records/models.dart';
import '../records/wait_time.dart';
import '../streak/streak.dart';

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
    this.newPrefectureBonus = 0,
    this.newAreaBonus = 0,
    this.regularBonus = 0,
    this.streakBonus = 0,
    this.famousBonus = 0,
  });

  static const zero = PointsBreakdown(
    base: 0,
    waitBonus: 0,
    limitedBonus: 0,
    firstVisitBonus: 0,
    retryBonus: 0,
  );

  final int base;
  final int waitBonus;
  final int limitedBonus;
  final int firstVisitBonus;
  final int retryBonus;
  final int expeditionBonus;
  final int earlyBonus;
  final int lateNightBonus;

  /// 旅: 初めての都道府県・初めての市区町村。
  final int newPrefectureBonus;
  final int newAreaBonus;

  /// 通い: 常連・連続記録・名店。
  final int regularBonus;
  final int streakBonus;
  final int famousBonus;

  int get total =>
      base +
      waitBonus +
      limitedBonus +
      firstVisitBonus +
      retryBonus +
      expeditionBonus +
      earlyBonus +
      lateNightBonus +
      newPrefectureBonus +
      newAreaBonus +
      regularBonus +
      streakBonus +
      famousBonus;
}

const basePoints = 10;
const waitBonusPerTenMinutes = 5;
const limitedBonus = 20;
const firstVisitBonus = 10;
const retryBonus = 15;

/// 押さなくても、記録の時刻と場所から自動でつく難しさ。
const earlyBonus = 10;
const lateNightBonus = 10;

/// 遠征の段階。拠点から遠いほど上がり、当てはまるいちばん上の段だけをつける（足さない）。
const expeditionTiers = [
  (kilometers: 800, bonus: 60),
  (kilometers: 300, bonus: 40),
  (kilometers: expeditionKilometers, bonus: 20),
];

/// その都道府県・市区町村で初めて食べた1杯。
const newPrefectureBonus = 30;
const newAreaBonus = 10;

/// 常連: その店で5杯目に+10、10杯目からは10杯ごとに+20。
const regularFifthBonus = 10;
const regularTenthBonus = 20;

/// 連続記録: 前の週から続いている週数1つにつき+2（最大+10）。その週の最初の1杯だけ。
const streakBonusPerWeek = 2;
const maxStreakBonus = 10;

/// 名店の印をつけた店で食べるたびに。
const famousBonus = 15;

/// 朝ラー（5〜9時台）と深夜（0〜4時台）。
bool isEarlyHour(DateTime at) => at.hour >= 5 && at.hour < 10;
bool isLateNightHour(DateTime at) => at.hour < 5;

/// 拠点からの距離（m）に応じた遠征の点。拠点か店の位置が分からなければ0。
int expeditionBonusFor(double? meters) {
  if (meters == null) return 0;
  for (final tier in expeditionTiers) {
    if (meters >= tier.kilometers * 1000) return tier.bonus;
  }
  return 0;
}

/// その店で[count]杯目（食べた記録だけを数える）の常連の点。
int regularBonusFor(int count) {
  if (count >= 10 && count % 10 == 0) return regularTenthBonus;
  if (count == 5) return regularFifthBonus;
  return 0;
}

/// 前の週から途切れずに続いている週の数が[weeksBefore]のときの連続記録の点。
int streakBonusFor(int weeksBefore) =>
    math.min(weeksBefore * streakBonusPerWeek, maxStreakBonus);

PointsBreakdown calculatePoints({
  required Visit visit,
  required bool isFirstVisit,
  required bool isRetrySuccess,
  double? homeBaseMeters,
  bool isNewPrefecture = false,
  bool isNewArea = false,
  int countAtShop = 1,
  int streakWeeksBefore = 0,
  bool isFamous = false,
}) {
  if (visit.result != VisitResult.eaten) return PointsBreakdown.zero;
  return PointsBreakdown(
    base: basePoints,
    waitBonus: (waitMinutes(visit) ?? 0) ~/ 10 * waitBonusPerTenMinutes,
    limitedBonus: visit.isLimited ? limitedBonus : 0,
    firstVisitBonus: isFirstVisit ? firstVisitBonus : 0,
    retryBonus: isRetrySuccess ? retryBonus : 0,
    expeditionBonus: expeditionBonusFor(homeBaseMeters),
    earlyBonus: isEarlyHour(visit.eatenAt) ? earlyBonus : 0,
    lateNightBonus: isLateNightHour(visit.eatenAt) ? lateNightBonus : 0,
    newPrefectureBonus: isNewPrefecture ? newPrefectureBonus : 0,
    newAreaBonus: isNewArea ? newAreaBonus : 0,
    regularBonus: regularBonusFor(countAtShop),
    streakBonus: streakBonusFor(streakWeeksBefore),
    famousBonus: isFamous ? famousBonus : 0,
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
    this.prefecture,
    this.countAtShop = 0,
    this.streakWeeksBefore = 0,
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

  /// 店のある都道府県（「東京都」など）。位置のわからない店・海の上などはnull。
  final String? prefecture;

  /// その店で何杯目か（食べた記録だけを数える。撤退は0）。
  final int countAtShop;

  /// この1杯がその週の最初の1杯のとき、前の週から途切れずに続いていた週の数。それ以外は0。
  final int streakWeeksBefore;

  /// 拠点から遠い店で食べた1杯か（遠征）。
  bool get isExpedition =>
      visit.result == VisitResult.eaten && isFarFromHomeBase(homeBase, shop);
}

/// 都道府県を引かないとき（どの店も都道府県なし）。
String? noPrefecture(Shop shop) => null;

/// 記録を食べた順に並べる。同じ日時なら作った順、それも同じなら記録のIDの順にして、毎回同じ順にする。
int compareVisitOrder(Visit a, Visit b) {
  final byEaten = a.eatenAt.compareTo(b.eatenAt);
  if (byEaten != 0) return byEaten;
  final byCreated = a.createdAt.compareTo(b.createdAt);
  if (byCreated != 0) return byCreated;
  return a.id.compareTo(b.id);
}

/// 全記録を採点し、古い順に返す。初訪問・再挑戦成功・初めての都道府県・常連・連続記録は
/// 記録の順番で決まるため、1件だけでは採点できない。[wishes]を渡すと、どの1杯で叶った願かも添える。
/// 遠征は、その1杯を食べた時点で効いていた[homeBases]の拠点から決める。
/// [prefectureOf]は店の都道府県を引く（同梱した境界で、通信しない）。
List<ScoredVisit> scoreVisits(
  List<VisitWithShop> entries, {
  List<Wish> wishes = const [],
  List<HomeBaseSetting> homeBases = const [],
  String? Function(Shop shop) prefectureOf = noPrefecture,
}) {
  final ordered = [...entries]
    ..sort((a, b) => compareVisitOrder(a.visit, b.visit));
  final eatenCounts = <String, int>{};
  final lastResult = <String, VisitResult>{};
  final prefectures = <String>{};
  final areas = <String>{};
  final weeks = <DateTime>{};
  final scored = <ScoredVisit>[];
  final wishByVisit = {for (final wish in wishes) ?wish.fulfilledVisitId: wish};
  for (final entry in ordered) {
    final visit = entry.visit;
    final shop = entry.shop;
    final isEaten = visit.result == VisitResult.eaten;
    final fulfilledWish = isEaten ? wishByVisit[visit.id] : null;
    final countAtShop = isEaten ? (eatenCounts[visit.shopId] ?? 0) + 1 : 0;
    final isRetrySuccess =
        isEaten && lastResult[visit.shopId] == VisitResult.retreated;
    final homeBase = homeBaseAt(homeBases, visit.eatenAt);
    final prefecture = prefectureOf(shop);
    final area = shop.area;
    final areaKey = area == null || area.isEmpty
        ? null
        : '${prefecture ?? ''}/$area';
    final week = weekStartOf(visit.eatenAt);
    final streakWeeksBefore = isEaten && !weeks.contains(week)
        ? _consecutiveWeeksBefore(weeks, week)
        : 0;
    scored.add(
      ScoredVisit(
        visit: visit,
        shop: shop,
        points: calculatePoints(
          visit: visit,
          isFirstVisit: countAtShop == 1,
          isRetrySuccess: isRetrySuccess,
          homeBaseMeters: homeBaseDistanceMeters(homeBase, shop),
          isNewPrefecture:
              isEaten &&
              prefecture != null &&
              !prefectures.contains(prefecture),
          isNewArea: isEaten && areaKey != null && !areas.contains(areaKey),
          countAtShop: countAtShop,
          streakWeeksBefore: streakWeeksBefore,
          isFamous: shop.isFamous,
        ),
        isFirstVisit: countAtShop == 1,
        isRetrySuccess: isRetrySuccess,
        fulfilledWish: fulfilledWish,
        homeBase: homeBase,
        prefecture: prefecture,
        countAtShop: countAtShop,
        streakWeeksBefore: streakWeeksBefore,
      ),
    );
    if (isEaten) {
      eatenCounts[visit.shopId] = countAtShop;
      if (prefecture != null) prefectures.add(prefecture);
      if (areaKey != null) areas.add(areaKey);
      weeks.add(week);
    }
    lastResult[visit.shopId] = visit.result;
  }
  return scored;
}

/// [week]の前の週から数えて、食べた週が途切れずに何週続いているか。
int _consecutiveWeeksBefore(Set<DateTime> weeks, DateTime week) {
  var count = 0;
  var previous = _previousWeek(week);
  while (weeks.contains(previous)) {
    count++;
    previous = _previousWeek(previous);
  }
  return count;
}

DateTime _previousWeek(DateTime monday) =>
    DateTime(monday.year, monday.month, monday.day - 7);

int totalPoints(List<ScoredVisit> scored) =>
    scored.fold(0, (sum, entry) => sum + entry.points.total);
