import '../home_base/home_base.dart';
import '../records/models.dart';
import '../records/wait_time.dart';
import '../scoring/points.dart';
import '../scoring/ranks.dart';
import '../shop_search/geo.dart';
import '../wishes/wishes.dart';

/// 常設: 回数を重ねるごとにレベルが上がる。スポット: 1回達成すれば終わり。
enum QuestKind { standing, spot }

/// 秘伝の印の形。
enum QuestSealShape {
  eightRing,
  doubleCircle,
  square,
  octagon,
  diamond,
  hexagon,
  flower,
  dottedRing,
  castle,
  sunburst,
  crescent,
  triangle,
  pill,
  boldRing,
  dashedRing,
  pentagon,
  star,
  garlic,
  compass,
  cornerDots,
  wave,
  fortySevenDots,
  globe,
}

/// 秘伝の印の字（なるべく1文字、1文字で表しにくければ2文字）と形。
class QuestSealDesign {
  const QuestSealDesign(this.glyph, this.shape);

  final String glyph;
  final QuestSealShape shape;
}

/// クエスト（お題）の定義。追加・変更はこの一覧だけを書き換える。
///
/// 達成状況は保存せず、毎回記録から[Quest.count]で数える。[Quest.count]は記録が増えても
/// 減らない数にすること（達成した日を求めるのに使うため）。
const quests = <Quest>[
  Quest(
    id: 'bowls',
    kind: QuestKind.standing,
    title: '着丼の道',
    description: '食べた杯数',
    unit: '杯',
    // 1杯目は「はじめての着丼」で祝うので、Lv.1 は5杯から。
    thresholds: [5, 10, 30, 50, 100, 200],
    count: _eatenCount,
  ),
  Quest(
    id: 'shops',
    kind: QuestKind.standing,
    title: '開拓者',
    description: '食べたことのある店の数',
    unit: '軒',
    thresholds: [3, 10, 30, 50, 100],
    count: _eatenShopCount,
  ),
  Quest(
    id: 'queue',
    kind: QuestKind.standing,
    title: '行列の覇者',
    description: '三十分以上並んで食べた回数',
    unit: '回',
    thresholds: [1, 5, 10, 30],
    count: _waited30Count,
  ),
  Quest(
    id: 'limited',
    kind: QuestKind.standing,
    title: '限定ハンター',
    description: '限定メニューを食べた回数',
    unit: '杯',
    thresholds: [1, 5, 10, 30],
    count: _limitedCount,
  ),
  Quest(
    id: 'retry',
    kind: QuestKind.standing,
    title: '不屈の挑戦者',
    description: '撤退した店で、あとから食べた回数',
    unit: '回',
    thresholds: [1, 3, 10],
    count: _retryCount,
  ),
  Quest(
    id: 'boss',
    kind: QuestKind.standing,
    title: '大物討伐',
    description: '一杯で55点以上を取り、「極」にした店の数',
    unit: '軒',
    thresholds: [1, 3, 10],
    count: _rankSShopCount,
  ),
  Quest(
    id: 'wishes',
    kind: QuestKind.standing,
    title: '願掛け',
    description: '願掛け帳に書き留めた店で食べ、願成就した数',
    unit: '軒',
    thresholds: [1, 3, 10, 30],
    count: _wishFulfilledCount,
  ),
  Quest(
    id: 'first_bowl',
    kind: QuestKind.spot,
    title: 'はじめての着丼',
    description: '最初の一杯を記録する',
    unit: '杯',
    thresholds: [1],
    count: _eatenCount,
    seal: QuestSealDesign('初', QuestSealShape.doubleCircle),
  ),
  Quest(
    id: 'queue_60',
    kind: QuestKind.spot,
    title: '六十分の試練',
    description: '六十分以上並んで食べる',
    unit: '回',
    thresholds: [1],
    count: _waited60Count,
    seal: QuestSealDesign('忍', QuestSealShape.square),
  ),
  Quest(
    id: 'queue_90',
    kind: QuestKind.spot,
    title: '九十分の死闘',
    description: '九十分以上並んで食べる',
    unit: '回',
    thresholds: [1],
    count: _waited90Count,
    seal: QuestSealDesign('闘', QuestSealShape.octagon),
  ),
  Quest(
    id: 'double_bowl',
    kind: QuestKind.spot,
    title: '一日二杯',
    description: '同じ日に二杯食べる',
    unit: '日',
    thresholds: [1],
    count: _doubleBowlDays,
    seal: QuestSealDesign('双', QuestSealShape.diamond),
  ),
  Quest(
    id: 'third_time',
    kind: QuestKind.spot,
    title: '三度目の正直',
    description: '同じ店で二度撤退したあと、その店で食べる',
    unit: '回',
    thresholds: [1],
    count: _thirdTimeCount,
    seal: QuestSealDesign('三', QuestSealShape.hexagon),
  ),
  Quest(
    id: 'styles',
    kind: QuestKind.spot,
    title: '系統の探究',
    description: '「その他」を除く八系統をすべて食べる',
    unit: '系統',
    thresholds: [8],
    count: _styleCount,
    seal: QuestSealDesign('全', QuestSealShape.eightRing),
  ),
  Quest(
    id: 'famous_shop',
    kind: QuestKind.spot,
    title: '名店の暖簾',
    description: '名店の印をつけた店で食べる',
    unit: '回',
    thresholds: [1],
    count: _famousShopCount,
    seal: QuestSealDesign('名', QuestSealShape.flower),
  ),
  Quest(
    id: 'home_base',
    kind: QuestKind.spot,
    title: '拠点を構える',
    description: '自分の拠点にする駅や街を決める',
    unit: '回',
    thresholds: [1],
    count: _none,
    byHomeBase: true,
    seal: QuestSealDesign('城', QuestSealShape.castle),
  ),
  Quest(
    id: 'long_wish',
    kind: QuestKind.spot,
    title: '百日越しの願',
    description: '願を掛けてから百日以上たって、その店で食べる',
    unit: '回',
    thresholds: [1],
    count: _longWishCount,
    seal: QuestSealDesign('願', QuestSealShape.dottedRing),
  ),
  Quest(
    id: 'dawn',
    kind: QuestKind.spot,
    title: '朝ラーの心得',
    description: '朝五時〜十時に食べる',
    unit: '回',
    thresholds: [1],
    count: _dawnCount,
    seal: QuestSealDesign('朝', QuestSealShape.sunburst),
  ),
  Quest(
    id: 'midnight',
    kind: QuestKind.spot,
    title: '丑三つの背徳',
    description: '夜中の零時〜四時に食べる',
    unit: '回',
    thresholds: [1],
    count: _midnightCount,
    seal: QuestSealDesign('丑三', QuestSealShape.crescent),
  ),
  Quest(
    id: 'swift',
    kind: QuestKind.spot,
    title: '疾風の着丼',
    description: '並んでから五分以内に着丼する',
    unit: '回',
    thresholds: [1],
    count: _swiftCount,
    seal: QuestSealDesign('速', QuestSealShape.triangle),
  ),
  Quest(
    id: 'style_ladder',
    kind: QuestKind.spot,
    title: '系統はしご',
    description: '同じ日に違う系統を二杯食べる',
    unit: '日',
    thresholds: [1],
    count: _styleLadderDays,
    seal: QuestSealDesign('二味', QuestSealShape.pill),
  ),
  Quest(
    id: 'devoted',
    kind: QuestKind.spot,
    title: '一途',
    description: '同じ店で十杯食べる',
    unit: '杯',
    thresholds: [10],
    count: _mostAtOneShop,
    seal: QuestSealDesign('一途', QuestSealShape.boldRing),
  ),
  Quest(
    id: 'pilgrimage',
    kind: QuestKind.spot,
    title: '月の巡礼',
    description: 'ひと月に十軒の違う店で食べる',
    unit: '軒',
    thresholds: [10],
    count: _mostShopsInMonth,
    seal: QuestSealDesign('巡', QuestSealShape.dashedRing),
  ),
  Quest(
    id: 'limited_month',
    kind: QuestKind.spot,
    title: '限定狩りの月',
    description: 'ひと月に限定を三杯食べる',
    unit: '杯',
    thresholds: [3],
    count: _mostLimitedInMonth,
    seal: QuestSealDesign('狩', QuestSealShape.pentagon),
  ),
  Quest(
    id: 'perfect',
    kind: QuestKind.spot,
    title: '満点の舌',
    description: '★5を十杯つける',
    unit: '杯',
    thresholds: [10],
    count: _fiveStarCount,
    seal: QuestSealDesign('満', QuestSealShape.star),
  ),
  Quest(
    id: 'jiro',
    kind: QuestKind.spot,
    title: '二郎の洗礼',
    description: '二郎系を食べる',
    unit: '杯',
    thresholds: [1],
    count: _jiroCount,
    seal: QuestSealDesign('二郎', QuestSealShape.garlic),
  ),
  Quest(
    id: 'far_journey',
    kind: QuestKind.spot,
    title: '遥かなる遠征',
    description: 'いちばん通っている店から100km以上離れた店で食べる',
    unit: '回',
    thresholds: [1],
    count: _farJourneyCount,
    seal: QuestSealDesign('旅', QuestSealShape.compass),
  ),
  Quest(
    id: 'new_year_eve',
    kind: QuestKind.spot,
    title: '年越しの一杯',
    description: '十二月三十一日に食べる',
    unit: '回',
    thresholds: [1],
    count: _newYearEveCount,
    seal: QuestSealDesign('年越', QuestSealShape.cornerDots),
  ),
  Quest(
    id: 'summer_cold',
    kind: QuestKind.spot,
    title: '夏の涼麺',
    description: '七〜八月につけ麺か汁なしを食べる',
    unit: '杯',
    thresholds: [1],
    count: _summerColdCount,
    seal: QuestSealDesign('涼', QuestSealShape.wave),
  ),
  Quest(
    id: 'all_prefectures',
    kind: QuestKind.spot,
    title: '全国行脚',
    description: '四十七都道府県すべてで食べる',
    unit: '都道府県',
    thresholds: [47],
    count: _prefectureCount,
    seal: QuestSealDesign('行脚', QuestSealShape.fortySevenDots),
  ),
  // 海外は隠し要素。秘伝はどれも会得するまで一覧に出ないので、この秘伝も会得して初めて姿を見せる。
  Quest(
    id: 'overseas',
    kind: QuestKind.spot,
    title: '麺の道は海を越えて',
    description: '海外の店で食べる',
    unit: '杯',
    thresholds: [1],
    count: _overseasCount,
    seal: QuestSealDesign('渡', QuestSealShape.globe),
  ),
];

class Quest {
  const Quest({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.unit,
    required this.thresholds,
    required this.count,
    this.seal,
    this.availableFrom,
    this.availableUntil,
    this.byHomeBase = false,
  });

  final String id;
  final QuestKind kind;
  final String title;
  final String description;

  /// 数の単位（杯・軒・回など）。
  final String unit;

  /// レベルごとに必要な数（小さい順）。スポットは1つだけ。
  final List<int> thresholds;

  /// 採点済みの記録（古い順）から、今の数を数える。
  final int Function(List<ScoredVisit> scored) count;

  /// 秘伝の印の字と形。秘伝ごとに違う印にする。
  final QuestSealDesign? seal;

  /// 期間限定の秘伝の、数えはじめる日時と、数えおわる日時（この日時より前まで）。
  /// どちらもnullなら、いつでも数える。期間が過ぎても定義は消さずに残す（過去分の記録のため）。
  final DateTime? availableFrom;
  final DateTime? availableUntil;

  /// 記録ではなく、初めて拠点を決めたことで会得する秘伝か。
  final bool byHomeBase;

  /// [at]に食べた記録を、このクエストで数えるか。
  bool isAvailableAt(DateTime at) =>
      (availableFrom == null || !at.isBefore(availableFrom!)) &&
      (availableUntil == null || at.isBefore(availableUntil!));

  int get maxLevel => thresholds.length;
}

class QuestProgress {
  QuestProgress({
    required this.quest,
    required this.current,
    required this.levelAchievedBy,
  }) : levelAchievedAt = [
         for (final entry in levelAchievedBy) entry.visit.eatenAt,
       ],
       achievedHomeBase = null;

  /// 拠点を決めて会得した秘伝。
  QuestProgress.byHomeBase({
    required this.quest,
    required HomeBaseSetting? base,
  }) : current = base == null ? 0 : 1,
       levelAchievedBy = const [],
       levelAchievedAt = [?base?.setAt],
       achievedHomeBase = base;

  final Quest quest;

  /// 今の数。
  final int current;

  /// 到達したレベルごとの、到達した記録（古い順）。拠点を決めて会得した秘伝では空。
  final List<ScoredVisit> levelAchievedBy;

  /// 到達したレベルごとの、到達した日時（古い順）。長さが今のレベル。
  final List<DateTime> levelAchievedAt;

  /// 拠点を決めて会得したときの、初めて決めた拠点。
  final HomeBaseSetting? achievedHomeBase;

  int get level => levelAchievedAt.length;

  bool get isMaxLevel => level >= quest.maxLevel;

  /// スポットは達成済みか。常設はLv.1以上か。
  bool get isAchieved => level > 0;

  /// 次のレベルに必要な数。最高レベルならnull。
  int? get nextThreshold => isMaxLevel ? null : quest.thresholds[level];
}

/// 型の段の1つ。上がった段と、その段の数、その段に届いた1杯。
class QuestLevelAttainment {
  const QuestLevelAttainment({
    required this.level,
    required this.threshold,
    required this.visit,
  });

  final int level;
  final int threshold;
  final ScoredVisit visit;
}

/// これまでに上がった段（古い順）。まだ届いていない段は含めない。拠点を決めて会得する秘伝では空。
List<QuestLevelAttainment> questLevelHistory(QuestProgress progress) => [
  for (final (i, visit) in progress.levelAchievedBy.indexed)
    QuestLevelAttainment(
      level: i + 1,
      threshold: progress.quest.thresholds[i],
      visit: visit,
    ),
];

/// あるクエストが、あるレベルに届いたこと。
class QuestLevelUp {
  const QuestLevelUp({required this.quest, required this.level});

  final Quest quest;
  final int level;
}

/// すべてのクエストの達成状況を、定義の順に返す。[scored]は古い順。
/// [homeBases]は、これまでに決めた拠点（秘伝「拠点を構える」に使う）。
List<QuestProgress> evaluateQuests(
  List<ScoredVisit> scored, {
  List<HomeBaseSetting> homeBases = const [],
  List<Quest> definitions = quests,
}) => [
  for (final quest in definitions)
    quest.byHomeBase
        ? QuestProgress.byHomeBase(quest: quest, base: firstHomeBase(homeBases))
        : _evaluate(quest, scored),
];

/// [before]から[after]で新しく届いたレベル。1回で2つ上がったら、上のレベルだけを返す。
List<QuestLevelUp> newlyAchievedLevels({
  required List<QuestProgress> before,
  required List<QuestProgress> after,
}) {
  final levelBefore = {
    for (final progress in before) progress.quest.id: progress.level,
  };
  return [
    for (final progress in after)
      if (progress.level > (levelBefore[progress.quest.id] ?? 0))
        QuestLevelUp(quest: progress.quest, level: progress.level),
  ];
}

QuestProgress _evaluate(Quest quest, List<ScoredVisit> all) {
  // 期間限定のクエストは、期間内に食べた記録だけで数える。
  final scored = quest.availableFrom == null && quest.availableUntil == null
      ? all
      : [
          for (final entry in all)
            if (quest.isAvailableAt(entry.visit.eatenAt)) entry,
        ];
  final count = quest.count(scored);
  return QuestProgress(
    quest: quest,
    current: count,
    levelAchievedBy: [
      for (final threshold in quest.thresholds)
        if (count >= threshold) _reachedBy(quest, scored, threshold),
    ],
  );
}

/// 記録が増えても数は減らないので、[threshold]に届いた記録を二分探索で求められる。
ScoredVisit _reachedBy(Quest quest, List<ScoredVisit> scored, int threshold) {
  var low = 1;
  var high = scored.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (quest.count(scored.sublist(0, middle)) >= threshold) {
      high = middle;
    } else {
      low = middle + 1;
    }
  }
  return scored[low - 1];
}

bool _isEaten(ScoredVisit entry) => entry.visit.result == VisitResult.eaten;

int _eatenCount(List<ScoredVisit> scored) => scored.where(_isEaten).length;

int _eatenShopCount(List<ScoredVisit> scored) => {
  for (final entry in scored)
    if (_isEaten(entry)) entry.visit.shopId,
}.length;

int _waitedCount(List<ScoredVisit> scored, int minutes) =>
    scored.where((e) => (waitMinutes(e.visit) ?? 0) >= minutes).length;

int _waited30Count(List<ScoredVisit> scored) => _waitedCount(scored, 30);

int _waited60Count(List<ScoredVisit> scored) => _waitedCount(scored, 60);

int _waited90Count(List<ScoredVisit> scored) => _waitedCount(scored, 90);

int _styleCount(List<ScoredVisit> scored) => {
  for (final entry in scored)
    if (_isEaten(entry) &&
        entry.visit.style != null &&
        entry.visit.style != RamenStyle.other)
      entry.visit.style,
}.length;

int _limitedCount(List<ScoredVisit> scored) =>
    scored.where((e) => _isEaten(e) && e.visit.isLimited).length;

/// 撤退のあと、同じ店で食べた（再挑戦成功した）回数。撤退1回につき1回まで数える。
int _retryCount(List<ScoredVisit> scored) =>
    scored.where((entry) => entry.isRetrySuccess).length;

/// 同じ店で2回以上撤退したあと、その店で食べた記録の数。
int _thirdTimeCount(List<ScoredVisit> scored) {
  final retreats = <String, int>{};
  var count = 0;
  for (final entry in scored) {
    final shopId = entry.visit.shopId;
    if (entry.visit.result == VisitResult.retreated) {
      retreats.update(shopId, (n) => n + 1, ifAbsent: () => 1);
    } else if ((retreats[shopId] ?? 0) >= 2) {
      count++;
    }
  }
  return count;
}

/// 2杯以上食べた日の数。
int _doubleBowlDays(List<ScoredVisit> scored) {
  final perDay = <DateTime, int>{};
  for (final entry in scored.where(_isEaten)) {
    final at = entry.visit.eatenAt;
    perDay.update(
      DateTime(at.year, at.month, at.day),
      (n) => n + 1,
      ifAbsent: () => 1,
    );
  }
  return perDay.values.where((n) => n >= 2).length;
}

int _none(List<ScoredVisit> scored) => 0;

int _famousShopCount(List<ScoredVisit> scored) =>
    scored.where((e) => _isEaten(e) && e.shop.isFamous).length;

int _rankSShopCount(List<ScoredVisit> scored) =>
    shopRanks(scored).values.where((rank) => rank == ShopRank.s).length;

int _wishFulfilledCount(List<ScoredVisit> scored) =>
    scored.where((e) => e.fulfilledWish != null).length;

int _longWishCount(List<ScoredVisit> scored) => scored
    .where(
      (e) =>
          e.fulfilledWish != null &&
          daysToFulfill(e.fulfilledWish!, e.visit.eatenAt) >= 100,
    )
    .length;

int _hourCount(List<ScoredVisit> scored, bool Function(int hour) matches) =>
    scored.where((e) => _isEaten(e) && matches(e.visit.eatenAt.hour)).length;

int _dawnCount(List<ScoredVisit> scored) =>
    _hourCount(scored, (hour) => hour >= 5 && hour < 10);

int _midnightCount(List<ScoredVisit> scored) =>
    _hourCount(scored, (hour) => hour < 4);

/// 並んでから5分以内に着丼した回数（並んでいない記録は数えない）。
int _swiftCount(List<ScoredVisit> scored) => scored.where((e) {
  final waited = waitMinutes(e.visit);
  return waited != null && waited <= 5;
}).length;

/// 違う系統を2杯以上食べた日の数。
int _styleLadderDays(List<ScoredVisit> scored) {
  final perDay = <DateTime, Set<RamenStyle>>{};
  for (final entry in scored.where(_isEaten)) {
    final style = entry.visit.style;
    if (style == null) continue;
    final at = entry.visit.eatenAt;
    (perDay[DateTime(at.year, at.month, at.day)] ??= {}).add(style);
  }
  return perDay.values.where((styles) => styles.length >= 2).length;
}

/// いちばん多く食べた店での杯数。
int _mostAtOneShop(List<ScoredVisit> scored) {
  final counts = <String, int>{};
  for (final entry in scored.where(_isEaten)) {
    counts.update(entry.visit.shopId, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts.values.fold(0, (a, b) => a > b ? a : b);
}

/// 1か月のうちで、いちばん多くの店で食べた月の軒数。
int _mostShopsInMonth(List<ScoredVisit> scored) {
  final perMonth = <DateTime, Set<String>>{};
  for (final entry in scored.where(_isEaten)) {
    final at = entry.visit.eatenAt;
    (perMonth[DateTime(at.year, at.month)] ??= {}).add(entry.visit.shopId);
  }
  return perMonth.values.fold(0, (a, b) => a > b.length ? a : b.length);
}

/// 1か月のうちで、いちばん多く限定を食べた月の杯数。
int _mostLimitedInMonth(List<ScoredVisit> scored) {
  final perMonth = <DateTime, int>{};
  for (final entry in scored.where((e) => _isEaten(e) && e.visit.isLimited)) {
    final at = entry.visit.eatenAt;
    perMonth.update(
      DateTime(at.year, at.month),
      (n) => n + 1,
      ifAbsent: () => 1,
    );
  }
  return perMonth.values.fold(0, (a, b) => a > b ? a : b);
}

int _fiveStarCount(List<ScoredVisit> scored) =>
    scored.where((e) => _isEaten(e) && e.visit.rating == 5).length;

int _jiroCount(List<ScoredVisit> scored) =>
    scored.where((e) => _isEaten(e) && e.visit.style == RamenStyle.jiro).length;

/// 遠征とみなす、いつもの店からの距離。
const _farJourneyMeters = 100000;

/// その1杯より前にいちばん多く食べた店から、100km以上離れた店で食べた回数。
/// その1杯より前の記録だけで決めるので、記録が増えても数は減らない。記録を1回なめるだけで数える。
int _farJourneyCount(List<ScoredVisit> scored) {
  final bowls = <String, int>{};
  GeoPoint? home;
  var homeBowls = 0;
  var count = 0;
  for (final entry in scored.where(_isEaten)) {
    final latitude = entry.shop.latitude;
    final longitude = entry.shop.longitude;
    if (latitude == null || longitude == null) continue;
    final here = GeoPoint(latitude, longitude);
    if (home != null && distanceMeters(home, here) >= _farJourneyMeters) {
      count++;
    }
    final n = bowls.update(entry.shop.id, (n) => n + 1, ifAbsent: () => 1);
    if (n > homeBowls) {
      homeBowls = n;
      home = here;
    }
  }
  return count;
}

int _newYearEveCount(List<ScoredVisit> scored) => scored
    .where(
      (e) =>
          _isEaten(e) &&
          e.visit.eatenAt.month == 12 &&
          e.visit.eatenAt.day == 31,
    )
    .length;

int _summerColdCount(List<ScoredVisit> scored) => scored
    .where(
      (e) =>
          _isEaten(e) &&
          (e.visit.eatenAt.month == 7 || e.visit.eatenAt.month == 8) &&
          (e.visit.style == RamenStyle.tsukemen ||
              e.visit.style == RamenStyle.shirunashi),
    )
    .length;

/// 食べたことのある都道府県の数。
int _prefectureCount(List<ScoredVisit> scored) => {
  for (final entry in scored)
    if (_isEaten(entry)) ?entry.prefecture,
}.length;

int _overseasCount(List<ScoredVisit> scored) =>
    scored.where((e) => _isEaten(e) && e.isOverseas).length;
