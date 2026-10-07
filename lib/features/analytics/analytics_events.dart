import '../scoring/points.dart';
import '../scoring/ranks.dart';
import '../scoring/record_outcome.dart';
import '../quests/quests.dart';
import '../shop_search/shop_candidate.dart';
import '../shop_search/shop_search_service.dart';

/// 統計として送る1件。名前は英小文字と _ で40字まで。値は種類（英字の決まった言葉）・数・1/0 だけにし、
/// 店名・位置・写真・メモ・願の中身・リンク・記録の日時など、人が入れたものや人を見分けられるものは入れない。
/// 数は [bucket] などで幅にまとめ、細かい値から人を見分けられないようにする。
class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.parameters = const {}]);

  final String name;
  final Map<String, Object> parameters;

  @override
  String toString() => 'AnalyticsEvent($name, $parameters)';
}

int _flag(bool value) => value ? 1 : 0;

/// 数を幅にまとめる（0・1・2-4・5-9・10-19・20-49・50-99・100+）。
String bucket(int count) => switch (count) {
  <= 0 => '0',
  1 => '1',
  < 5 => '2-4',
  < 10 => '5-9',
  < 20 => '10-19',
  < 50 => '20-49',
  < 100 => '50-99',
  _ => '100+',
};

/// 記録を始めてから「着丼！」までの秒数の幅。
String elapsedBucket(Duration elapsed) => switch (elapsed.inSeconds) {
  < 15 => '0-14s',
  < 30 => '15-29s',
  < 60 => '30-59s',
  < 120 => '1-2m',
  < 300 => '2-5m',
  < 900 => '5-15m',
  < 3600 => '15-60m',
  _ => '60m+',
};

/// 1杯の修行点の幅。
String pointsBucket(int points) => switch (points) {
  < 20 => '0-19',
  < 30 => '20-29',
  < 40 => '30-39',
  < 55 => '40-54',
  < 80 => '55-79',
  < 120 => '80-119',
  _ => '120+',
};

/// 初めての記録から何日たったかの幅。
String daysBucket(int days) => switch (days) {
  <= 0 => '0',
  < 7 => '1-6',
  < 30 => '7-29',
  < 90 => '30-89',
  < 180 => '90-179',
  < 365 => '180-364',
  < 730 => '365-729',
  _ => '730+',
};

/// 印の格（良・秀・妙・極）。
String gradeName(ShopRank rank) => switch (rank) {
  ShopRank.c => 'ryo',
  ShopRank.b => 'shu',
  ShopRank.a => 'myo',
  ShopRank.s => 'kiwami',
};

/// 記録を始めたきっかけ。
enum RecordEntry { plain, arrival, sharePhoto, shareMap, recovered }

/// 記録の写真の出どころ。
enum PhotoSource { camera, gallery, shared, recovered, none }

/// 願を掛けた入口。
enum WishSource { wishBook, map, shopPage, memory, share }

/// 選んだ店の出どころ。
enum ShopSourceKind { osm, yahoo, openpoi, curated, known, wish, manual }

const _yahooAttribution = 'Yahoo! JAPAN';

/// 選んだ候補がどの検索元から来たか。選んでいなければ（店名の手入力）manual。
ShopSourceKind shopSourceOf(ShopCandidate? shop) {
  if (shop == null) return ShopSourceKind.manual;
  if (shop.wishId != null) return ShopSourceKind.wish;
  if (shop.shopId != null) return ShopSourceKind.known;
  if (shop.osmId != null) return ShopSourceKind.osm;
  final source = shop.dataSource;
  if (source == null) return ShopSourceKind.curated;
  if (source.attributions.any((a) => a.contains(_yahooAttribution))) {
    return ShopSourceKind.yahoo;
  }
  return ShopSourceKind.openpoi;
}

/// 英字の種類名（camelCase）を snake_case にする。
String snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// 記録を保存したときの、入力の様子（入れたかどうかだけ。中身は送らない）。
class RecordSaveSummary {
  const RecordSaveSummary({
    required this.entry,
    required this.photoSource,
    required this.shopSource,
    required this.usedNameSearch,
    required this.hasRating,
    required this.hasStyle,
    required this.isLimited,
    required this.hasManualWait,
    required this.hasMemo,
    required this.shopMemoEdited,
    required this.famousChanged,
    required this.photoRotated,
    required this.pinnedLocation,
    required this.resumedDraft,
    required this.atCheckinShop,
    required this.elapsed,
  });

  final RecordEntry entry;
  final PhotoSource photoSource;
  final ShopSourceKind shopSource;
  final bool usedNameSearch;
  final bool hasRating;
  final bool hasStyle;
  final bool isLimited;
  final bool hasManualWait;
  final bool hasMemo;
  final bool shopMemoEdited;
  final bool famousChanged;
  final bool photoRotated;
  final bool pinnedLocation;
  final bool resumedDraft;
  final bool atCheckinShop;
  final Duration elapsed;
}

abstract final class AnalyticsEvents {
  static AnalyticsEvent recordStarted({
    required RecordEntry entry,
    required bool resumedDraft,
  }) => AnalyticsEvent('record_started', {
    'entry': snake(entry.name),
    'resumed_draft': _flag(resumedDraft),
  });

  /// 1つのイベントに付けられる数は25までなので、点の内訳は [recordBonuses] に分ける。
  static AnalyticsEvent recordSaved(
    RecordSaveSummary summary, {
    required ScoredVisit scored,
    required int totalBowls,
  }) => AnalyticsEvent('record_saved', {
    'entry': snake(summary.entry.name),
    'photo_source': summary.photoSource.name,
    'shop_source': summary.shopSource.name,
    'name_search': _flag(summary.usedNameSearch),
    'has_rating': _flag(summary.hasRating),
    'has_style': _flag(summary.hasStyle),
    'is_limited': _flag(summary.isLimited),
    'has_wait': _flag(scored.visit.checkedInAt != null),
    'manual_wait': _flag(summary.hasManualWait),
    'at_checkin_shop': _flag(summary.atCheckinShop),
    'has_memo': _flag(summary.hasMemo),
    'shop_memo_edited': _flag(summary.shopMemoEdited),
    'famous_changed': _flag(summary.famousChanged),
    'photo_rotated': _flag(summary.photoRotated),
    'pinned_location': _flag(summary.pinnedLocation),
    'resumed_draft': _flag(summary.resumedDraft),
    'wish_fulfilled': _flag(scored.fulfilledWish != null),
    'elapsed': elapsedBucket(summary.elapsed),
    'points': pointsBucket(scored.points.total),
    'grade': gradeName(shopRankFor(scored.points.total)),
    'total_bowls': bucket(totalBowls),
  });

  static AnalyticsEvent recordBonuses(ScoredVisit scored) {
    final points = scored.points;
    return AnalyticsEvent('record_bonuses', {
      'grade': gradeName(shopRankFor(points.total)),
      'wait': _flag(points.waitBonus > 0),
      'limited': _flag(points.limitedBonus > 0),
      'first_visit': _flag(points.firstVisitBonus > 0),
      'retry': _flag(points.retryBonus > 0),
      'morning': _flag(points.earlyBonus > 0),
      'late_night': _flag(points.lateNightBonus > 0),
      'expedition': points.expeditionBonus,
      'first_prefecture': _flag(points.newPrefectureBonus > 0),
      'first_city': _flag(points.newAreaBonus > 0),
      'regular': _flag(points.regularBonus > 0),
      'streak': _flag(points.streakBonus > 0),
      'famous': _flag(points.famousBonus > 0),
    });
  }

  static AnalyticsEvent rankUp({
    required AdventurerRank rank,
    required int totalBowls,
    required int daysSinceFirstRecord,
  }) => AnalyticsEvent('rank_up', {
    'rank': rank.name,
    'total_bowls': bucket(totalBowls),
    'days_since_first': daysBucket(daysSinceFirstRecord),
  });

  static AnalyticsEvent questAchieved(
    QuestLevelUp levelUp, {
    required int totalBowls,
  }) => AnalyticsEvent('quest_achieved', {
    'quest_id': levelUp.quest.id,
    'kind': levelUp.quest.kind == QuestKind.standing ? 'kata' : 'hiden',
    'level': levelUp.level,
    'total_bowls': bucket(totalBowls),
  });

  static AnalyticsEvent healthyLifeRevealed({required int totalBowls}) =>
      AnalyticsEvent('healthy_life_revealed', {
        'total_bowls': bucket(totalBowls),
      });

  static AnalyticsEvent wishFulfilled({required int daysWaited}) =>
      AnalyticsEvent('wish_fulfilled', {'days_waited': daysBucket(daysWaited)});

  static const draftKept = AnalyticsEvent('draft_kept');

  /// [how] は restart（再開した下書きを捨ててやり直す）か leave（記録をやめて捨てる）。
  static AnalyticsEvent draftDiscarded(String how) =>
      AnalyticsEvent('draft_discarded', {'how': how});

  /// 近くの店を探した結果。[purpose]は record（記録）か checkin（並ぶ）。
  /// 候補には記録済みの店も入るので、検索元が失敗しても候補が出ることがある。
  static AnalyticsEvent shopSearch({
    required String purpose,
    required ShopSearchResult result,
  }) => AnalyticsEvent('shop_search', {
    'purpose': purpose,
    'result': switch (result.failure) {
      ShopSearchFailure.noLocation => 'no_location',
      ShopSearchFailure.searchFailed => 'failed',
      null => result.candidates.isEmpty ? 'zero' : 'found',
    },
    'count': bucket(result.candidates.length),
  });

  /// 店名から探した結果。
  /// [via]は server（麺印帳のサーバー）か device（端末から直接）。[results]は失敗ならnull。
  static AnalyticsEvent shopNameSearch({
    required String via,
    required List<Object>? results,
  }) => AnalyticsEvent('shop_name_search', {
    'via': via,
    'result': results == null
        ? 'failed'
        : results.isEmpty
        ? 'zero'
        : 'found',
    'count': bucket(results?.length ?? 0),
  });

  static AnalyticsEvent geocode({required bool found}) =>
      AnalyticsEvent('geocode', {'result': found ? 'found' : 'not_found'});

  static AnalyticsEvent checkinStarted({
    required String via,
    required ShopSourceKind shopSource,
  }) => AnalyticsEvent('checkin_started', {
    'via': via,
    'shop_source': shopSource.name,
  });

  static const checkinCanceled = AnalyticsEvent('checkin_canceled');
  static const checkinAutoCanceled = AnalyticsEvent('checkin_auto_canceled');

  static AnalyticsEvent checkinRetreated({required int waitedMinutes}) =>
      AnalyticsEvent('checkin_retreated', {
        'waited_min': bucket(waitedMinutes),
      });

  static const queueSuggestionAccepted = AnalyticsEvent(
    'queue_suggestion_accepted',
  );

  static AnalyticsEvent wishCreated({
    required WishSource source,
    required bool hasLocation,
  }) => AnalyticsEvent('wish_created', {
    'source': snake(source.name),
    'has_location': _flag(hasLocation),
  });

  static const wishLinkOpened = AnalyticsEvent('wish_link_opened');

  static AnalyticsEvent mapNearbySearch({
    required bool succeeded,
    required int count,
  }) => AnalyticsEvent('map_nearby_search', {
    'result': succeeded ? (count == 0 ? 'zero' : 'found') : 'failed',
    'count': bucket(count),
  });

  static const mapClusterTap = AnalyticsEvent('map_cluster_tap');
  static const mapListOpened = AnalyticsEvent('map_list_opened');

  static AnalyticsEvent mapFilter(String filter) =>
      AnalyticsEvent('map_filter', {'filter': filter});

  static const journeyReplay = AnalyticsEvent('journey_replay');

  /// 修行タブなどから開いた画面（quests・prefecture_book・year_review・shugyoroku・rank_history・stats など）。
  static AnalyticsEvent featureOpened(String feature) =>
      AnalyticsEvent('feature_opened', {'feature': feature});

  static AnalyticsEvent shareCard({
    required String result,
    required bool includePhoto,
    required bool includeJournal,
    required bool includePoints,
  }) => AnalyticsEvent('share_card', {
    'result': result,
    'include_photo': _flag(includePhoto),
    'include_journal': _flag(includeJournal),
    'include_points': _flag(includePoints),
  });

  static AnalyticsEvent backupExported({required String result}) =>
      AnalyticsEvent('backup_exported', {'result': result});

  static AnalyticsEvent backupImported({
    required String result,
    int added = 0,
  }) => AnalyticsEvent('backup_imported', {
    'result': result,
    'added': bucket(added),
  });

  static AnalyticsEvent homeBaseSet({required String via}) =>
      AnalyticsEvent('home_base_set', {'via': via});

  static AnalyticsEvent homeBaseEdited({required String change}) =>
      AnalyticsEvent('home_base_edited', {'change': change});

  /// [start] は最後に選んだ始め方（record・checkin・backup・browse）。選ばずに閉じたら null。
  static AnalyticsEvent onboardingFinished({
    required String? start,
    required String step,
  }) => AnalyticsEvent('onboarding_finished', {
    'start': start ?? 'closed',
    'step': step,
  });

  static const onboardingHomeBaseLater = AnalyticsEvent(
    'onboarding_home_base_later',
  );

  /// [permission] は location・notification・camera のどれか。
  static AnalyticsEvent permissionDenied(String permission) =>
      AnalyticsEvent('permission_denied', {'permission': permission});

  static AnalyticsEvent locationBlockedShown(String reason) =>
      AnalyticsEvent('location_blocked_shown', {'reason': reason});
}

/// 記録を保存した直後に送るイベント（保存・点の内訳・昇段・型と秘伝・願成就・隠し要素）。
/// [summary]が無い（入力の様子がわからない）ときは、記録の保存のイベントだけ省く。
/// [totalBowls]はこの1杯を含めた食べた杯数、[firstRecordAt]はいちばん古い記録の日時。
List<AnalyticsEvent> recordOutcomeEvents(
  RecordOutcome outcome, {
  RecordSaveSummary? summary,
  required int totalBowls,
  required DateTime firstRecordAt,
}) {
  final scored = outcome.scored;
  final eatenAt = scored.visit.eatenAt;
  final wish = scored.fulfilledWish;
  return [
    if (summary != null)
      AnalyticsEvents.recordSaved(
        summary,
        scored: scored,
        totalBowls: totalBowls,
      ),
    AnalyticsEvents.recordBonuses(scored),
    if (outcome.isRankUp)
      AnalyticsEvents.rankUp(
        rank: outcome.rankAfter,
        totalBowls: totalBowls,
        daysSinceFirstRecord: eatenAt.difference(firstRecordAt).inDays,
      ),
    for (final levelUp in outcome.questLevelUps)
      AnalyticsEvents.questAchieved(levelUp, totalBowls: totalBowls),
    if (wish != null)
      AnalyticsEvents.wishFulfilled(
        daysWaited: eatenAt.difference(wish.createdAt).inDays,
      ),
    if (outcome.revealsHealthyLife)
      AnalyticsEvents.healthyLifeRevealed(totalBowls: totalBowls),
  ];
}
