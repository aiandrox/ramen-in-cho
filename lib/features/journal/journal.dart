import '../inkan/inkan.dart';
import '../home_base/home_base.dart';
import '../records/models.dart';
import '../scoring/points.dart';
import '../shop_search/geo.dart';
import '../wishes/wishes.dart';
import 'journal_phrases.dart';

/// 1杯にたどり着くまでの短い物語（道中記）。保存せず、記録からその場で組み立てる。
///
/// 文のひな形は `journal_phrases.dart` にまとめる（足す・直すときはそこだけを書き換える）。
/// 同じ材料でも言い回しを数通り用意し、記録のIDで1つに決める（開くたびに変わらないように）。
/// [includeMemo]をfalseにすると、本人のメモの引用を入れない（人に送る共有カード用）。
List<String> buildJournal(
  ScoredVisit target,
  List<ScoredVisit> all, {
  bool includeMemo = true,
}) {
  final visit = target.visit;
  final before = [
    for (final entry in all)
      if (entry.visit.shopId == visit.shopId && _isBefore(entry.visit, visit))
        entry.visit,
  ];
  final eatenBefore = before.where(_isEaten).length;
  final retreats = _retreatsSinceLastEaten(before);
  final pick = _Picker(visit.id);
  // 願を掛けるより前の1杯を叶えたことにしたときは、願の話は入れない。
  final fulfilled = target.fulfilledWish;
  final wish = fulfilled != null && wishPrecedes(fulfilled, visit.eatenAt)
      ? fulfilled
      : null;
  final checkedInAt = visit.checkedInAt;
  // 撤退でも、並んだ時間は物語に入れる。
  final waited = checkedInAt == null
      ? null
      : visit.eatenAt.difference(checkedInAt).inMinutes;

  final lines = <String>[];
  if (wish != null) {
    final trigger = wish.trigger;
    final day = _monthDay(wish.createdAt, visit.eatenAt);
    lines.add(
      (trigger.isEmpty ? wishOpening : wishOpeningWithTrigger).fill({
        '日付': day,
        'きっかけ': trigger,
      }).single,
    );
  } else if (eatenBefore == 0 &&
      retreats.isEmpty &&
      visit.result == VisitResult.retreated) {
    lines.add(pick(firstRetreatOpening.fill()));
  } else if (eatenBefore == 0 && retreats.isEmpty) {
    final shops = _shopNumber(target, all);
    lines.add(pick(firstVisitOpening.fill({'軒': proseNumber(shops)})));
  } else if (eatenBefore > 0) {
    final times = eatenBefore + 1;
    lines.add(pick(repeatOpening.fill({'度': proseNumber(times)})));
  }

  // 節目・間隔・特別な日（当てはまるものを2つまで）。
  if (visit.result == VisitResult.eaten) {
    lines.addAll(_moments(target, all, eatenBefore).take(2));
  }

  if (wish == null && retreats.isEmpty) {
    // 何も起きなかった日にも彩りがあるよう、時間帯・曜日・季節の一文を添える（添えない日もある）。
    final scene = pick(_scenes(visit.eatenAt));
    if (scene.isNotEmpty) lines.add(scene);
  }

  // 地名は、あとから調べて分かることがあるため、ほかの言い回しとは別に決めて足すだけにする
  // （地名が分かっても、ほかの文は変わらない）。
  final area = target.shop.area;
  if (area != null && area.isNotEmpty) {
    final pickArea = _Picker('${visit.id}#area');
    final phrases = switch (_distanceFromHome(target, all)) {
      final m? when m >= expeditionKilometers * 1000 => expeditionArea,
      final m? when m >= _farMeters => farArea,
      _ => nearArea,
    };
    final line = pickArea(phrases.fill({'地名': area}));
    if (line.isNotEmpty) lines.add(line);
  }

  if (retreats.length == 1) {
    lines.add(
      retreatedOnceBefore.fill({'理由': _reason(retreats.single)}).single,
    );
  } else if (retreats.length > 1) {
    lines.add(
      retreatedManyBefore.fill({'回': proseNumber(retreats.length)}).single,
    );
  }

  if (visit.result == VisitResult.retreated) {
    if (waited != null && waited > 0) {
      lines.add(retreatWaited.fill({'分': waited}).single);
    }
    lines.add(retreatBlocked.fill({'理由': _reason(visit)}).single);
    lines.add(pick(retreatClosing.fill()));
    return lines;
  }

  if (waited != null && waited >= 60) {
    lines.add(pick(longWait.fill({'分': waited})));
  } else if (waited != null && waited > 0) {
    lines.add(pick(shortWait.fill({'分': waited})));
  }

  final style = flavors[visit.style];
  if (style != null) {
    final flavor = _Picker('${visit.id}#flavor')(style.fill());
    if (flavor.isNotEmpty) lines.add(flavor);
  }

  final bowlName =
      '${visit.isLimited ? '限定の' : ''}${_styleName(visit.style)}の一杯';
  final dramatic = wish != null || retreats.isNotEmpty || (waited ?? 0) >= 60;
  final points = target.points.total;
  // 共有カードで修行点を外すとき「、修行点 N」を消すので、この形は崩さない。
  final bowlValues = {'一杯': bowlName, '点': points};
  lines.add(
    dramatic
        ? pick(dramaticBowl.fill(bowlValues))
        : pick(bowl.fill(bowlValues)),
  );

  lines.addAll(_records(target, all).take(1));

  final verdict = verdicts[visit.rating];
  if (verdict != null) lines.add(pick(verdict.fill()));

  final memo = visit.memo.trim();
  if (includeMemo &&
      memo.isNotEmpty &&
      memo.length <= 20 &&
      !memo.contains('\n')) {
    lines.add(memoQuote.fill({'メモ': memo}).single);
  }

  if (wish != null) {
    final days = daysToFulfill(wish, visit.eatenAt);
    lines.add(
      days == 0
          ? wishSameDayClosing.fill().single
          : wishClosing.fill({'日': proseNumber(days)}).single,
    );
  } else if (target.isRetrySuccess) {
    lines.add(pick(retryClosing.fill()));
  } else {
    final count = _yearNumber(target, all);
    // 毎回出ると単調なので、10杯ごとの節目のほかは3杯に1杯ほどだけ添える。
    if (count % 10 == 0 ||
        (count > 1 && _Picker('${visit.id}#year').oneIn(3))) {
      lines.add(pick(yearClosing.fill({'杯': proseNumber(count)})));
    }
  }
  return lines;
}

bool _isEaten(Visit visit) => visit.result == VisitResult.eaten;

/// 遠出とみなす、いつもの店からの距離。遠征（[expeditionKilometers]）より近い。
const _farMeters = 20000;

/// この1杯の店と、いつもの店（この1杯までにいちばん多く食べた店）との距離（m）。位置が分からなければnull。
/// あとから記録を足しても過去の道中記が変わらないよう、この1杯までの記録だけで決める。
double? _distanceFromHome(ScoredVisit target, List<ScoredVisit> all) {
  final counts = <String, int>{};
  final shops = <String, Shop>{};
  for (final entry in all) {
    if (!_isEaten(entry.visit)) continue;
    if (entry != target && !_isBefore(entry.visit, target.visit)) continue;
    counts.update(entry.shop.id, (n) => n + 1, ifAbsent: () => 1);
    shops[entry.shop.id] = entry.shop;
  }
  if (counts.isEmpty) return null;
  final home =
      shops[counts.entries.reduce((a, b) => b.value > a.value ? b : a).key]!;
  final here = target.shop;
  if (home.latitude == null ||
      home.longitude == null ||
      here.latitude == null ||
      here.longitude == null) {
    return null;
  }
  return distanceMeters(
    GeoPoint(home.latitude!, home.longitude!),
    GeoPoint(here.latitude!, here.longitude!),
  );
}

bool _isBefore(Visit a, Visit b) {
  final byEaten = a.eatenAt.compareTo(b.eatenAt);
  if (byEaten != 0) return byEaten < 0;
  return a.createdAt.isBefore(b.createdAt);
}

/// 最後に食べたあとの撤退（古い順）。
List<Visit> _retreatsSinceLastEaten(List<Visit> before) {
  final retreats = <Visit>[];
  for (final visit in before) {
    if (_isEaten(visit)) {
      retreats.clear();
    } else {
      retreats.add(visit);
    }
  }
  return retreats;
}

String _reason(Visit retreat) {
  final memo = retreat.memo.trim();
  // 撤退の理由は「売り切れ」「臨時休業」など短い言葉で残る。長いメモは文に入れない。
  return memo.isNotEmpty && memo.length <= 10 ? '「$memo」' : unknownReason;
}

String _monthDay(DateTime date, DateTime now) => date.year == now.year
    ? '${kanjiNumber(date.month)}月${kanjiNumber(date.day)}日'
    : '${date.year}年${kanjiNumber(date.month)}月${kanjiNumber(date.day)}日';

/// 食べたことのある店の数を、この1杯までで数える。
int _shopNumber(ScoredVisit target, List<ScoredVisit> all) => {
  for (final entry in all)
    if (_isEaten(entry.visit) &&
        (entry == target || _isBefore(entry.visit, target.visit)))
      entry.visit.shopId,
}.length;

int _yearNumber(ScoredVisit target, List<ScoredVisit> all) => all
    .where(
      (entry) =>
          _isEaten(entry.visit) &&
          entry.visit.eatenAt.year == target.visit.eatenAt.year &&
          (entry == target || _isBefore(entry.visit, target.visit)),
    )
    .length;

/// 節目・間隔・特別な日の一文（大事な順）。
List<String> _moments(
  ScoredVisit target,
  List<ScoredVisit> all,
  int eatenBefore,
) {
  final visit = target.visit;
  final at = visit.eatenAt;
  final upTo = [
    for (final entry in all)
      if (_isEaten(entry.visit) &&
          (entry == target || _isBefore(entry.visit, visit)))
        entry.visit,
  ];
  final moments = <String>[];
  final sameDay = upTo.where((v) => _sameDate(v.eatenAt, at)).length;
  final isNewYearsFirst = at.month == 1 && at.day == 1 && sameDay == 1;
  if (isNewYearsFirst) moments.add(newYearsFirstMoment.fill().single);
  if (at.month == 12 && at.day == 31) {
    moments.add(newYearsEveMoment.fill().single);
  }
  if (!isNewYearsFirst && _yearNumber(target, all) == 1 && upTo.length > 1) {
    moments.add(firstOfYearMoment.fill().single);
  }
  if (milestoneBowls.contains(upTo.length)) {
    moments.add(milestoneMoment.fill({'杯': proseNumber(upTo.length)}).single);
  }
  if (sameDay >= 2) {
    moments.add(sameDayMoment.fill({'杯': proseNumber(sameDay)}).single);
  }
  final streak = _dayStreak(upTo, at);
  if (streak >= 3) {
    moments.add(streakMoment.fill({'日': proseNumber(streak)}).single);
  }
  // 撤退した日も、その店に行った日として数える。
  final lastHere = all
      .map((e) => e.visit)
      .where((v) => v.shopId == visit.shopId && _isBefore(v, visit))
      .map((v) => v.eatenAt)
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  if (lastHere != null) {
    final gap = _dateOnly(at).difference(_dateOnly(lastHere)).inDays;
    if (gap >= 365) {
      moments.add(yearsApartMoment.fill({'年': proseNumber(gap ~/ 365)}).single);
    } else if (gap >= 90) {
      moments.add(longGapMoment.fill().single);
    }
  }
  final times = eatenBefore + 1;
  if (times == 5) moments.add(regularMoment.fill().single);
  if (times == 10) moments.add(secondHomeMoment.fill().single);
  return moments;
}

/// この1杯までで、何日続けて食べているか（同じ日に何杯食べても1日）。
int _dayStreak(List<Visit> upTo, DateTime at) {
  final days = {for (final v in upTo) _dateOnly(v.eatenAt)};
  var day = _dateOnly(at);
  var count = 0;
  while (days.contains(day)) {
    count++;
    day = DateTime.utc(day.year, day.month, day.day - 1);
  }
  return count;
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// 夏時間のある地域でも1日を24時間として数えるため、UTCの日付で比べる。
DateTime _dateOnly(DateTime at) => DateTime.utc(at.year, at.month, at.day);

/// 記録の更新（自己最高の修行点・この店で最長の待ち・この道場の印が極に）。
List<String> _records(ScoredVisit target, List<ScoredVisit> all) {
  final visit = target.visit;
  final before = [
    for (final entry in all)
      if (_isEaten(entry.visit) && _isBefore(entry.visit, visit)) entry,
  ];
  if (before.isEmpty) return const [];
  final points = target.points.total;
  final records = <String>[];
  if (points > before.map((e) => e.points.total).reduce(_max)) {
    records.add(bestPointsRecord.fill().single);
  }
  final here = [
    for (final entry in before)
      if (entry.visit.shopId == visit.shopId) entry,
  ];
  if (here.isNotEmpty &&
      points >= _rankSPoints &&
      here.map((e) => e.points.total).reduce(_max) < _rankSPoints) {
    records.add(shopRankSRecord.fill().single);
  }
  final waited = _waitOf(visit);
  final waitsHere = [for (final e in here) ?_waitOf(e.visit)];
  if (waited != null &&
      waitsHere.isNotEmpty &&
      waited > waitsHere.reduce(_max)) {
    records.add(longestWaitRecord.fill().single);
  }
  return records;
}

/// 店ランク「極」になる修行点（ranks.dart の ShopRank.s と同じ）。
const _rankSPoints = 55;

int _max(int a, int b) => a > b ? a : b;

int? _waitOf(Visit visit) {
  final checkedInAt = visit.checkedInAt;
  return checkedInAt == null
      ? null
      : visit.eatenAt.difference(checkedInAt).inMinutes;
}

/// 食べた時間帯・曜日・季節に合う一文の候補。空文字は「添えない」。
List<String> _scenes(DateTime at) {
  final hour = at.hour;
  final time = switch (hour) {
    6 => sceneHour6,
    18 => sceneHour18,
    2 => sceneHour2,
    >= 5 && < 11 => sceneMorning,
    >= 11 && < 15 => sceneNoon,
    >= 15 && < 18 => sceneAfternoon,
    >= 18 && < 23 => sceneEvening,
    _ => sceneNight,
  };
  final weekend = switch (at.weekday) {
    DateTime.saturday || DateTime.sunday => sceneWeekend,
    DateTime.friday when hour >= 18 => sceneFridayNight,
    DateTime.monday => sceneMonday,
    _ => null,
  };
  final season = switch (at.month) {
    12 || 1 || 2 => sceneWinter,
    6 || 7 || 8 => sceneSummer,
    3 || 4 || 5 => sceneSpring,
    _ => sceneAutumn,
  };
  return [
    for (final phrases in [time, ?weekend, season, sceneSkip])
      ...phrases.fill(),
  ];
}

String _styleName(RamenStyle? style) => switch (style) {
  RamenStyle.shoyu => '醤油',
  RamenStyle.miso => '味噌',
  RamenStyle.shio => '塩',
  RamenStyle.tonkotsu => '豚骨',
  RamenStyle.iekei => '家系',
  RamenStyle.jiro => '二郎系',
  RamenStyle.tsukemen => 'つけ麺',
  RamenStyle.shirunashi => '汁なし',
  RamenStyle.other || null => 'ラーメン',
};

class _Picker {
  _Picker(String visitId)
    : _seed = visitId.codeUnits.fold<int>(
        0,
        (sum, unit) => (sum * 31 + unit) & 0x7fffffff,
      );

  int _seed;

  String call(List<String> options) {
    final chosen = options[_seed % options.length];
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return chosen;
  }

  bool oneIn(int n) => _seed % n == 0;
}
