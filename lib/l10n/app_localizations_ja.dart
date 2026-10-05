// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => '麺印帳';

  @override
  String get homeEmpty => 'まだ記録がありません\n「＋」から最初の一杯を記録しましょう';

  @override
  String get homeLoadFailed => '記録を読み込めませんでした';

  @override
  String get addRecord => '記録する';

  @override
  String get recordTitle => '記録する';

  @override
  String get recordSaveFailed => '保存できませんでした。もう一度お試しください';

  @override
  String get save => '着丼！';

  @override
  String get takePhoto => 'カメラで撮る';

  @override
  String get retakePhoto => '撮り直す';

  @override
  String get pickFromGallery => 'ギャラリーから選ぶ';

  @override
  String get shopSection => '店';

  @override
  String get shopSearching => '近くの店を探しています…';

  @override
  String get shopNoLocation => '現在地がわかりませんでした。店名を入力してください';

  @override
  String get shopSearchFailed => '店を検索できませんでした。店名を入力してください';

  @override
  String get shopSearchPartial => '店を検索できなかったため、記録済みの店だけを表示しています';

  @override
  String get shopNoCandidates => '近くに候補が見つかりませんでした。店名を入力してください';

  @override
  String get shopNameLabel => '店名を入力';

  @override
  String get shopNameHint => '候補にないときはここに入力';

  @override
  String get shopVisited => '記録あり';

  @override
  String distanceMeters(int meters) {
    return '${meters}m';
  }

  @override
  String get shopSearchAttribution =>
      '© OpenStreetMap contributors ／ 出典: OpenPOI API（https://openpoiapi.com/attribution.html）';

  @override
  String get ratingSection => '評価';

  @override
  String get ratingUnrated => '未評価';

  @override
  String ratingPrompt(String shop) {
    return '$shop はどうでしたか？';
  }

  @override
  String ratingStar(int stars) {
    return '★$stars';
  }

  @override
  String get optionalSection => 'くわしく（任意）';

  @override
  String get styleSection => '系統';

  @override
  String get styleShoyu => '醤油';

  @override
  String get styleMiso => '味噌';

  @override
  String get styleShio => '塩';

  @override
  String get styleTonkotsu => '豚骨';

  @override
  String get styleIekei => '家系';

  @override
  String get styleJiro => '二郎系';

  @override
  String get styleTsukemen => 'つけ麺';

  @override
  String get styleShirunashi => '汁なし';

  @override
  String get styleOther => 'その他';

  @override
  String get isLimited => '限定メニュー';

  @override
  String get hoursSection => '攻略しにくさ（当てはまるものすべて）';

  @override
  String get hoursLunchOnly => '昼のみ';

  @override
  String get hoursNightOnly => '夜のみ';

  @override
  String get hoursWeekdaysOnly => '平日のみ';

  @override
  String get hoursWeekendsOnly => '土日のみ';

  @override
  String get hoursFewDays => '週3日以下';

  @override
  String get hoursIrregular => '不定休';

  @override
  String get hoursBadAccess => 'アクセスが悪い';

  @override
  String get memoLabel => 'メモ';

  @override
  String get draftResumed => '下書きから再開しました';

  @override
  String get draftDiscard => '下書きを捨てて新しく';

  @override
  String get draftDiscardTitle => '下書きを捨てますか？';

  @override
  String get draftDiscardMessage => '入れた写真や店名などが消えます。記録した杯には影響しません';

  @override
  String get draftDiscardConfirm => '捨てる';

  @override
  String get draftDiscardCancel => '残す';

  @override
  String get cancel => 'キャンセル';

  @override
  String get edit => '編集';

  @override
  String get delete => '削除';

  @override
  String get deleteConfirmTitle => 'この記録を削除しますか？';

  @override
  String get deleteConfirmMessage => '写真も削除されます。元に戻せません';

  @override
  String get deleteFailed => '削除できませんでした';

  @override
  String get previousVisit => '前回の記録';

  @override
  String get visitNotFound => '記録が見つかりません';

  @override
  String get editTitle => '記録を編集';

  @override
  String get editSave => '保存';

  @override
  String get editSaveFailed => '保存できませんでした。もう一度お試しください';

  @override
  String get editShopName => '店名';

  @override
  String get editEatenAt => '食べた日時';

  @override
  String get editRemovePhoto => '写真を外す';

  @override
  String get editPhotoFailed => '写真を読み込めませんでした';

  @override
  String get limitedBadge => '限定';

  @override
  String get checkinButton => '並んだ';

  @override
  String get checkinTitle => '並んだ店を選ぶ';

  @override
  String checkinDone(String shop) {
    return '$shop に並びました';
  }

  @override
  String get checkinFailed => 'チェックインできませんでした。もう一度お試しください';

  @override
  String get checkinTooFar => '100m以内に近づくとチェックインできます';

  @override
  String get checkinNoLocation =>
      '現在地がわからないため、チェックインできません。位置情報をオンにして、もう一度お試しください';

  @override
  String get checkinSearchFailed => '店を検索できませんでした。店名を入力してチェックインできます';

  @override
  String get checkinNoCandidates => '近くに候補が見つかりませんでした。店名を入力してチェックインできます';

  @override
  String get checkinRetry => 'もう一度探す';

  @override
  String get checkinManualButton => 'この店名でチェックイン';

  @override
  String checkinBanner(String shop) {
    return '$shop に並び中';
  }

  @override
  String checkinWaiting(int minutes) {
    return '並び始めてから $minutes分';
  }

  @override
  String checkinNotificationBody(String time) {
    return '$time から並んでいます。着丼したら「＋」で記録しましょう';
  }

  @override
  String streakWeeks(int weeks) {
    return '$weeks週連続で着丼中';
  }

  @override
  String get streakAtRisk => '今週はまだ';

  @override
  String streakReminderTitle(int weeks) {
    return '$weeks週連続の記録が途切れそう';
  }

  @override
  String get checkinCancel => '取り消す';

  @override
  String get checkinCancelTitle => 'チェックインを取り消しますか？';

  @override
  String get checkinCancelMessage => '並んだ記録は残りません';

  @override
  String get checkinKeep => '並び続ける';

  @override
  String get retreat => '撤退';

  @override
  String get retreatTitle => '撤退を記録しますか？';

  @override
  String get retreatMessage => '食べられなかった記録として残します。次に同じ店で食べると「再挑戦成功」になります';

  @override
  String get retreatReasonSoldOut => '売り切れ';

  @override
  String get retreatReasonClosed => '臨時休業';

  @override
  String get retreatReasonNoTime => '時間切れ';

  @override
  String get retreatMemoLabel => 'メモ（任意）';

  @override
  String get retreatConfirm => '撤退を記録';

  @override
  String get retreatSaved => '撤退を記録し、願掛け帳に入れました';

  @override
  String get retreatFailed => '記録できませんでした。もう一度お試しください';

  @override
  String get retreatBadge => '撤退';

  @override
  String waitTime(int minutes) {
    return '待ち時間 $minutes分';
  }

  @override
  String get rankApprentice => '入門';

  @override
  String get rankFirstDan => '初段';

  @override
  String rankKyu(String number) {
    return '$number級';
  }

  @override
  String rankDan(String number) {
    return '$number段';
  }

  @override
  String get rankMaster => '師範代';

  @override
  String get rankGrandmaster => '免許皆伝';

  @override
  String points(int points) {
    return '$points点';
  }

  @override
  String pointsGained(int points) {
    return '+$points点';
  }

  @override
  String get pointsSection => '修行点';

  @override
  String get pointsBase => '基本';

  @override
  String pointsWait(int minutes) {
    return '待ち時間 $minutes分';
  }

  @override
  String get pointsFirstVisit => '初訪問';

  @override
  String get pointsRetry => '再挑戦成功';

  @override
  String get pointsExpedition => '遠征';

  @override
  String get pointsEarly => '朝ラー';

  @override
  String get pointsLateNight => '深夜';

  @override
  String pointsHours(String label) {
    return '攻略しにくさ（$label）';
  }

  @override
  String pointsMultiplier(String multiplier) {
    return '×$multiplier';
  }

  @override
  String get pointsRetreat => '撤退の記録に修行点はつきません';

  @override
  String totalPoints(int points) {
    return '修行点 $points';
  }

  @override
  String nextRank(String rank, int points) {
    return '$rankまで あと $points点';
  }

  @override
  String get maxRank => '免許皆伝に至りました';

  @override
  String nextRankReady(String rank) {
    return '次の一杯で$rank';
  }

  @override
  String get rankHistoryReady => '次の一杯で上がる';

  @override
  String get rankUp => '昇段！';

  @override
  String get rankUpKyu => '昇級！';

  @override
  String get rankHistoryTitle => '昇段の記録';

  @override
  String rankHistoryAchievedAt(String date, String shop) {
    return '$date　$shopにて達成';
  }

  @override
  String get rankHistoryNoRecord => '最初の一杯から修行が始まります';

  @override
  String rankHistoryRemaining(int points) {
    return 'あと $points点';
  }

  @override
  String get rankHistoryHidden => '？？';

  @override
  String get resultTitle => '着丼！';

  @override
  String get resultOk => '印帳にもどる';

  @override
  String get resultShare => '共有する';

  @override
  String get navRecords => '印帳';

  @override
  String get questStanding => '型';

  @override
  String get questSpot => '秘伝';

  @override
  String questLevelTotal(int total) {
    return '段の合計 $total';
  }

  @override
  String questSpotSummary(int achieved, int total) {
    return '会得 $achieved / $total';
  }

  @override
  String questLevel(int level) {
    return '$level段';
  }

  @override
  String get questMaxLevel => '極み';

  @override
  String get questCleared => '会得';

  @override
  String questNext(int current, int target, String unit) {
    return '$current／$target$unit';
  }

  @override
  String questCount(int count, String unit) {
    return '$count$unit';
  }

  @override
  String get questLevelUp => '型 昇段！';

  @override
  String questLevelReached(String title, int level) {
    return '$title $level段';
  }

  @override
  String get questAchieved => '秘伝会得！';

  @override
  String get statsEmpty => '記録が増えると、ここに統計が出ます';

  @override
  String bowls(int count) {
    return '$count杯';
  }

  @override
  String get statsStyles => '系統の割合';

  @override
  String get styleUnset => '系統なし';

  @override
  String percent(int percent) {
    return '$percent%';
  }

  @override
  String get statsFrequent => 'よく行く店';

  @override
  String get statsFrequentNone => '2杯以上食べた店が、ここに並びます';

  @override
  String get shopMemoSection => 'この店の攻略メモ';

  @override
  String get shopConditionsSection => '店の条件';

  @override
  String get shopConditionsEmpty => 'まだ入れていません';

  @override
  String get shopConditionsEdit => '店の条件を選ぶ';

  @override
  String shopConditionsFromMap(String label) {
    return '$label（地図の営業時間から）';
  }

  @override
  String mapOpeningHoursConditions(String label) {
    return '地図の営業時間では $label';
  }

  @override
  String get shopMemoEmpty => 'まだありません';

  @override
  String get shopMemoHint => '開店の何分前に着けばいいか、券売機、整理券の配り方など';

  @override
  String get shopMemoEdit => '攻略メモを書く';

  @override
  String shopMemoInline(String memo) {
    return '攻略メモ: $memo';
  }

  @override
  String get navWishes => '願掛け';

  @override
  String get wishTitle => '願掛け帳';

  @override
  String get wishSealChar => '願';

  @override
  String wishPendingTab(int count) {
    return 'まだの願 $count';
  }

  @override
  String wishFulfilledTab(int count) {
    return '叶った願 $count';
  }

  @override
  String get wishPendingEmpty =>
      '行きたい店を書き留めておきましょう。\n地図の灰色のピンや店のページから願を掛けられます。右下の＋なら店名だけで書き留められます';

  @override
  String get wishFulfilledEmpty => '願を掛けた店で「着丼！」すると、ここに並びます';

  @override
  String get wishAddTitle => '願を掛ける';

  @override
  String get wishEditTitle => '願を書き直す';

  @override
  String get wishAddButton => '願を掛ける';

  @override
  String get wishMakeButton => '願を掛ける（行きたい）';

  @override
  String get wishAlready => 'この店には願を掛けています';

  @override
  String get wishShopName => '店名';

  @override
  String get wishTrigger => 'きっかけ（任意）';

  @override
  String get wishConditions => '店の条件（わかれば）';

  @override
  String get wishTriggerHint => '同僚に聞いた・テレビで見た など';

  @override
  String get wishNote => 'ひとこと（任意）';

  @override
  String get wishNoteHint => '限定の煮干しを食べたい など';

  @override
  String wishTriggerLine(String trigger) {
    return 'きっかけ: $trigger';
  }

  @override
  String wishFulfilledLine(String date, int days) {
    return '$date 願成就（$days日越し）';
  }

  @override
  String wishAdded(String name) {
    return '$name に願を掛けました';
  }

  @override
  String get wishSaveFailed => '願を書き留められませんでした';

  @override
  String wishDeleteConfirm(String name) {
    return '$name の願を消しますか？';
  }

  @override
  String get wishFulfilled => '願成就';

  @override
  String wishFulfillPrompt(String name) {
    return '$name の願を、この1杯で叶えたことにしますか？';
  }

  @override
  String get wishFulfillButton => '叶えた';

  @override
  String get shopWished => '願掛け中';

  @override
  String wishFulfilledAfter(int days) {
    return '願を掛けてから $days日、ついに着丼';
  }

  @override
  String get wishFulfilledSameDay => '願を掛けたその日に着丼';

  @override
  String get mapWished => '願掛け中の店';

  @override
  String mapWishedLabel(String name) {
    return '願掛け中の店 $name';
  }

  @override
  String get journalTitle => '道中記';

  @override
  String get shareTitle => 'この一杯を共有';

  @override
  String get shareIncludePhoto => '写真を入れる';

  @override
  String get shareIncludeJournal => '道中記を入れる';

  @override
  String get shareIncludePoints => '修行点を入れる';

  @override
  String get shareNote => '店の場所（地図）は入りません。共有を押したときだけ、選んだ相手やアプリに送られます';

  @override
  String get shareButton => '共有する';

  @override
  String get shareFailed => '共有できませんでした';

  @override
  String get journeyToggle => '旅路';

  @override
  String get journeyAllYears => 'すべて';

  @override
  String journeyYear(int year) {
    return '$year年';
  }

  @override
  String journeySummary(int shops, String km) {
    return '$shops軒をめぐる麺の道 ${km}km';
  }

  @override
  String get journeyEmpty => '位置のわかる店で食べると、旅路が引かれます';

  @override
  String get journeyReplay => '旅路を再生';

  @override
  String get journeyStop => '止める';

  @override
  String get journeyExpeditions => '遠征';

  @override
  String get journeyExpeditionsTitle => '遠征の記録';

  @override
  String get journeyExpeditionsNone => '拠点から80km以上離れた店で食べた日が、遠征として並びます';

  @override
  String homeBaseLine(String shop, int bowls) {
    return '今の拠点: $shopのあたり（$bowls杯）';
  }

  @override
  String homeBaseNone(int bowls) {
    return '同じ地域で$bowls杯食べると拠点ができます';
  }

  @override
  String get homeBaseSealChar => '拠';

  @override
  String homeBasePinLabel(String shop) {
    return '今の拠点（$shopのあたり）';
  }

  @override
  String journeyExpeditionName(int month, int day, String shop) {
    return '$month月$day日の遠征（$shop）';
  }

  @override
  String memoryYearsAgo(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years年前の今日',
      one: '一年前の今日',
    );
    return '$_temp0';
  }

  @override
  String memoryLine(String shop) {
    return '$shopで着丼していました';
  }

  @override
  String get memoryNotSince => 'あれから一度も行っていません。久しぶりにどうですか';

  @override
  String get memoryDismiss => '閉じる';

  @override
  String queueSuggestion(String shop) {
    return '$shop に並んだ？';
  }

  @override
  String queueSuggestionWished(String shop) {
    return '願掛けの $shop に並んだ？';
  }

  @override
  String get queueSuggestionYes => '並んだ';

  @override
  String get queueSuggestionDismiss => '閉じる';

  @override
  String get queueSuggestionFailed => '並んだ時刻を残せませんでした';

  @override
  String nameSearchOpen(String name) {
    return '全国の店から「$name」を探す（地図に載せる）';
  }

  @override
  String get nameSearchTitle => '店名で探す';

  @override
  String get nameSearchButton => '探す';

  @override
  String get nameSearchNone => '見つかりませんでした。店名を短くして探してみてください';

  @override
  String get nameSearchFailed => '探せませんでした。電波のよいところでもう一度試してください';

  @override
  String nameSearchDistance(String km) {
    return '${km}km';
  }

  @override
  String get shopLocate => '地図に載せる（店名で探す）';

  @override
  String get shopLocated => '地図に載せました';

  @override
  String get openInMaps => '地図アプリで開く';

  @override
  String get openInMapsFailed => '地図アプリを開けませんでした';

  @override
  String get yahooAttribution =>
      'Web Services by Yahoo! JAPAN（https://developer.yahoo.co.jp/sitemap/）';

  @override
  String get creditsYahoo =>
      '店の情報: Web Services by Yahoo! JAPAN（https://developer.yahoo.co.jp/sitemap/）';

  @override
  String get backupTitle => 'バックアップ';

  @override
  String get creditsTitle => '出典・ライセンス';

  @override
  String get creditsServicesHeading => '地図と店の情報';

  @override
  String get creditsOsm => '地図と店の情報: © OpenStreetMap contributors（ODbL）';

  @override
  String get creditsGsi => 'ラーメン二郎の店の位置: 住所から国土地理院の住所検索で求めたもの';

  @override
  String get creditsOpenPoi =>
      '店の情報: 出典 OpenPOI API（https://openpoiapi.com/attribution.html）';

  @override
  String get creditsSavedShopsHeading => '記録した店の出典';

  @override
  String get creditsSavedShopsNote => 'OpenPOI API で見つけて記録した店の情報の出どころです';

  @override
  String creditsLicenses(String licenses) {
    return 'ライセンス: $licenses';
  }

  @override
  String get creditsAppHeading => 'アプリで使っている部品';

  @override
  String get creditsAppLicenses => '部品とフォントのライセンスを見る';

  @override
  String get backupDescription =>
      '記録と写真を1つのファイル（zip）にまとめて書き出します。機種変更のときは、新しいスマホでこのファイルを読み込んでください。';

  @override
  String get backupExport => '書き出す';

  @override
  String get backupExportNote => '書き出したファイルは、「ファイル」アプリやクラウド、メールなどに保存してください';

  @override
  String get backupImport => '読み込む';

  @override
  String get backupImportNote =>
      '書き出したファイルを選ぶと、このスマホに無い記録だけを足します。今ある記録は消えません。ファイル名は「ramen-in-cho-（日付）.zip」です';

  @override
  String get backupExportFailed => '書き出せませんでした。もう一度お試しください';

  @override
  String get backupExportSent => '保存先に送りました。ドライブなどにファイルがあるか確かめてください';

  @override
  String backupImportDone(int added, int total) {
    return '$added件の記録を読み込みました（ファイルの記録 $total件のうち、このスマホに無かったもの）';
  }

  @override
  String get backupImportInvalid => '麺印帳のバックアップとして読めないファイルです';

  @override
  String get backupImportFailed => '読み込めませんでした。もう一度お試しください';

  @override
  String get backupFileType => 'バックアップ（zip）';

  @override
  String get statsBests => '自己ベスト';

  @override
  String get bestLongestWait => '最長の待ち時間';

  @override
  String get bestHighestPoints => '1杯の最高の修行点';

  @override
  String get bestMostRetreats => 'いちばん手ごわい店';

  @override
  String minutes(int minutes) {
    return '$minutes分';
  }

  @override
  String retreatCount(int count) {
    return '撤退 $count回';
  }

  @override
  String bestDetail(String shop, String date) {
    return '$shop（$date）';
  }

  @override
  String get statsShopRanks => '店ランク';

  @override
  String get navMap => '地図';

  @override
  String get mapAttribution => '© OpenStreetMap contributors';

  @override
  String get openPoiAttribution =>
      '出典: OpenPOI API（https://openpoiapi.com/attribution.html）';

  @override
  String get mapTitle => 'ラーメン地図';

  @override
  String get mapSearching => 'このあたりのラーメン店を探しています…';

  @override
  String get mapLocating => '現在地を確かめています…';

  @override
  String get mapEmpty => '行った店はまだ地図にありません。「このあたりのラーメン店を探す」で、まわりの店を探せます';

  @override
  String get mapSearchHere => 'このあたりのラーメン店を探す';

  @override
  String get mapMyLocation => '現在地';

  @override
  String get mapNoLocation => '現在地がわかりませんでした。位置情報をオンにしてください';

  @override
  String mapNearbyFound(int count) {
    return 'まだ行っていない店が $count軒 見つかりました';
  }

  @override
  String get mapNearbyNone => 'このあたりに、まだ行っていないラーメン店は見つかりませんでした';

  @override
  String get mapSearchFailed => '店を検索できませんでした。少し待ってから、もう一度お試しください';

  @override
  String get mapUnvisited => 'まだ行っていない店';

  @override
  String mapDistanceFromHere(int meters) {
    return '現在地から ${meters}m';
  }

  @override
  String mapShopBowls(int count) {
    return '$count杯';
  }

  @override
  String mapShopRetreats(int count) {
    return '撤退 $count回';
  }

  @override
  String get mapOpenShopPage => 'この店のページを見る';

  @override
  String mapLastVisit(String date) {
    return '最後に行った日 $date';
  }

  @override
  String mapShopRank(String rank) {
    return '店ランク $rank';
  }

  @override
  String statsBestPoints(int points) {
    return '最高 $points点';
  }

  @override
  String get shopRankS => '極';

  @override
  String get shopRankA => '難';

  @override
  String get shopRankB => '厳';

  @override
  String get shopRankC => '易';

  @override
  String get inkanRetry => '雪辱';

  @override
  String get inkanRetreat => '敗';

  @override
  String inkanTop(String rank, String kind) {
    return '$rank　$kind';
  }

  @override
  String kanjiMonthDay(String month, String day) {
    return '$month月$day日';
  }

  @override
  String get shopStamps => 'この道場の印';

  @override
  String recordPhotoDate(String date) {
    return '食べた日時: $date（写真の撮影日時）';
  }

  @override
  String kanjiEraDate(String era, String year, String month, String day) {
    return '$era$year年\n$month月$day日';
  }

  @override
  String inchoMonth(String era, String eraYear, String month) {
    return '$era$eraYear年 $month月';
  }

  @override
  String get eraReiwa => '令和';

  @override
  String get eraHeisei => '平成';

  @override
  String get eraFirstYear => '元';

  @override
  String get waitMinutesLabel => '待ち時間';

  @override
  String get waitMinutesUnit => '分';

  @override
  String get questLocked => '未';

  @override
  String get inkanNoStyle => '拉麺';

  @override
  String get inkanStyleShoyu => '醤油';

  @override
  String get inkanStyleMiso => '味噌';

  @override
  String get inkanStyleShio => '塩';

  @override
  String get inkanStyleTonkotsu => '豚骨';

  @override
  String get inkanStyleIekei => '家系';

  @override
  String get inkanStyleJiro => '二郎';

  @override
  String get inkanStyleTsukemen => '沾麺';

  @override
  String get inkanStyleShirunashi => '汁無';

  @override
  String get inkanStyleOther => '麺';

  @override
  String get navShugyo => '修行';

  @override
  String get shugyoTitle => '修行';

  @override
  String get healthyLifeTitle => '毎日ラーメン健康生活';

  @override
  String healthyLifeBest(int days) {
    return '最高 $days日連続';
  }

  @override
  String get healthyLifeRevealNote => '7日続けて着丼した';

  @override
  String get shugyorokuTitle => '修行録';

  @override
  String get shugyorokuOpen => 'これまでの一杯を、物語で読み返す';

  @override
  String get shugyorokuEmpty => '最初の一杯から、修行録が始まります';

  @override
  String shugyorokuChapter(int year, int month) {
    return '$year年 $month月';
  }

  @override
  String shugyorokuEntryTitle(int month, int day, String shop) {
    return '$month月$day日　$shop';
  }

  @override
  String get settingsSection => '設定';

  @override
  String get checkinStart => 'いま並んでいる';

  @override
  String get moreActions => 'そのほか';

  @override
  String get statsBowls => '杯数';

  @override
  String statsBowlsLine(int thisYear, int total) {
    return '今年 $thisYear杯　通算 $total杯';
  }

  @override
  String get navGlyphRecords => '印';

  @override
  String get navGlyphWishes => '願';

  @override
  String get navGlyphShugyo => '修';

  @override
  String get navGlyphMap => '地';

  @override
  String get wishTriggerRetreat => '撤退した店';

  @override
  String get questSpotNone => 'まだ会得した秘伝はありません';

  @override
  String reviewEntry(int year) {
    return '$year年の振り返り';
  }

  @override
  String reviewInvite(int year) {
    return '$year年の修行を振り返りませんか';
  }

  @override
  String get reviewInviteSub => 'この一年の杯数・最高の一杯・会得した型をめくって見られます';

  @override
  String get reviewDismiss => '閉じる';

  @override
  String reviewCoverEra(String era, String eraYear) {
    return '$era$eraYear年の修行';
  }

  @override
  String reviewCoverYear(int year) {
    return '$year年';
  }

  @override
  String get reviewCoverHint => '左へめくって、一年を振り返る';

  @override
  String get reviewCoverEmpty => 'この年の記録はありません';

  @override
  String reviewYearOption(int year) {
    return '$year年';
  }

  @override
  String get reviewCountsTitle => 'この一年で';

  @override
  String get reviewBowls => '食べた杯数';

  @override
  String get reviewShops => '訪ねた店';

  @override
  String reviewShopCount(int count) {
    return '$count軒';
  }

  @override
  String get reviewRetreats => '撤退';

  @override
  String reviewRetreatCount(int count) {
    return '$count回';
  }

  @override
  String get reviewPoints => '得た修行点';

  @override
  String get reviewFavoriteTitle => 'いちばん通った店';

  @override
  String reviewFavoriteLine(int count) {
    return 'この一年で $count杯';
  }

  @override
  String get reviewBestTitle => '最高の一杯';

  @override
  String get reviewWaitTitle => 'いちばん並んだ一杯';

  @override
  String get reviewMonthlyTitle => '月ごとの杯数';

  @override
  String reviewMonth(int month) {
    return '$month月';
  }

  @override
  String reviewMonthBowls(int month, int count) {
    return '$month月 $count杯';
  }

  @override
  String get reviewAchievementsTitle => 'この一年の成果';

  @override
  String get reviewRanks => '上がった段位';

  @override
  String get reviewQuests => '会得した型と秘伝';

  @override
  String get reviewWishes => '叶った願';

  @override
  String reviewWishCount(int count) {
    return '$count軒';
  }

  @override
  String get reviewExpeditions => '遠征';

  @override
  String reviewExpeditionCount(int count) {
    return '$count回';
  }

  @override
  String get reviewClosingTitle => '締めのひとこと';

  @override
  String reviewSummaryLine(int bowls, int shops, int points) {
    return '$bowls杯・$shops軒・$points点';
  }

  @override
  String questSpotAchievedShop(String shop) {
    return '$shopにて会得';
  }

  @override
  String get questSpotOpenShop => 'その一杯を見る';

  @override
  String get onboardingClose => '案内を閉じる';

  @override
  String get onboardingLater => 'また今度';

  @override
  String get onboardingNext => '先へ進む';

  @override
  String get onboardingWelcomeTitle => '門を叩く';

  @override
  String get onboardingWelcomeBody =>
      '麺印帳は、麺の道を歩む者のための修行の帳面である。\n食べた一杯ごとに印を授かり、並んだ時間も、遠い店への道のりも、すべて修行点として刻まれていく。\n\n始め方は三つある。';

  @override
  String get onboardingWelcomeRecord => '写真から一杯を刻む';

  @override
  String get onboardingWelcomeQueue => 'いま行列に並んでいる';

  @override
  String get onboardingWelcomeBackup => '前の帳面を引き継ぐ（バックアップ）';

  @override
  String get onboardingRecordTitle => '最初の一杯を刻む';

  @override
  String get onboardingRecordBody =>
      '撮りためた一杯の写真が一枚あれば足りる。撮影した日時と場所から、店の候補を探し出す。\n\n次の画面で「ギャラリーから選ぶ」を押し、店を選んで「着丼！」を押す。これで一杯目が刻まれる。';

  @override
  String get onboardingRecordButton => '写真を選んで刻む';

  @override
  String get onboardingShareTitle => '一杯目の印';

  @override
  String get onboardingShareBody =>
      '刻んだ一杯は、このような印となって帳面に並ぶ。長く並んだ一杯ほど、攻め難い店ほど、印は格を増していく。\n\n写真と印と店の名を一枚の絵にまとめ、同じ道を行く者に見せることもできる。';

  @override
  String get onboardingShareButton => '絵にして分かち合う';

  @override
  String get onboardingWishTitle => '次なる一杯に願を掛ける';

  @override
  String get onboardingWishBody =>
      '行きたい店を願掛け帳に記しておけば、その店で食べた日に願が成就する。\n\n地図の右下の「探す」を押すと、近くのまだ訪れていない店が灰色の印で現れる。気になる店に触れ、「願を掛ける」を押す。';

  @override
  String get onboardingWishNotYet => 'まだ願は掛かっていない。店の名からも掛けられる。';

  @override
  String get onboardingWishMap => '地図で近くの店を探す';

  @override
  String get onboardingWishByName => '店の名で願を掛ける';

  @override
  String get onboardingFinishTitle => 'あとは精進あるのみ';

  @override
  String get onboardingFinishBody =>
      '「修行」では、段位、型と秘伝、修行録、一年の振り返りを見ることができる。\n\n一杯ごとに印は増え、段位は上がっていく。\nいざ、麺の道へ。';

  @override
  String get onboardingFinishShugyo => '修行の間をのぞく';

  @override
  String get onboardingFinishRecords => '印帳を開く';

  @override
  String get onboardingReplay => '使い方をもう一度見る';

  @override
  String get onboardingScroll => '入門の心得';

  @override
  String get onboardingWelcomeChapter => '其の一　入門';

  @override
  String get onboardingRecordChapter => '其の二　初陣';

  @override
  String get onboardingShareChapter => '其の三　授印';

  @override
  String get onboardingWishChapter => '其の四　願掛';

  @override
  String get onboardingFinishChapter => '其の五　精進';
}
