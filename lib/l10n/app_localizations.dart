import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ja')];

  /// No description provided for @appName.
  ///
  /// In ja, this message translates to:
  /// **'麺印帳'**
  String get appName;

  /// No description provided for @homeEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ記録がありません\n真ん中の「麺」から最初の一杯を記録しましょう'**
  String get homeEmpty;

  /// No description provided for @homeLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'記録を読み込めませんでした'**
  String get homeLoadFailed;

  /// No description provided for @addRecord.
  ///
  /// In ja, this message translates to:
  /// **'記録する・並ぶ'**
  String get addRecord;

  /// No description provided for @arriveSeal.
  ///
  /// In ja, this message translates to:
  /// **'着丼したら押す'**
  String get arriveSeal;

  /// No description provided for @arriveSealLabel.
  ///
  /// In ja, this message translates to:
  /// **'着丼'**
  String get arriveSealLabel;

  /// No description provided for @startEatenTitle.
  ///
  /// In ja, this message translates to:
  /// **'着丼した'**
  String get startEatenTitle;

  /// No description provided for @startEatenBody.
  ///
  /// In ja, this message translates to:
  /// **'写真を撮って記録する'**
  String get startEatenBody;

  /// No description provided for @sharedPlaceRecordTitle.
  ///
  /// In ja, this message translates to:
  /// **'ここで着丼した'**
  String get sharedPlaceRecordTitle;

  /// No description provided for @sharedPlaceRecordBody.
  ///
  /// In ja, this message translates to:
  /// **'この店で食べた一杯を記録する'**
  String get sharedPlaceRecordBody;

  /// No description provided for @sharedPlaceWishTitle.
  ///
  /// In ja, this message translates to:
  /// **'願を掛ける'**
  String get sharedPlaceWishTitle;

  /// No description provided for @sharedPlaceWishBody.
  ///
  /// In ja, this message translates to:
  /// **'行きたい店として書き留める'**
  String get sharedPlaceWishBody;

  /// No description provided for @startQueueTitle.
  ///
  /// In ja, this message translates to:
  /// **'いま並んでいる'**
  String get startQueueTitle;

  /// No description provided for @startQueueBody.
  ///
  /// In ja, this message translates to:
  /// **'並び始めから着丼までの時間を測ります'**
  String get startQueueBody;

  /// No description provided for @recordTitle.
  ///
  /// In ja, this message translates to:
  /// **'記録する'**
  String get recordTitle;

  /// No description provided for @recordSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存できませんでした。もう一度お試しください'**
  String get recordSaveFailed;

  /// No description provided for @save.
  ///
  /// In ja, this message translates to:
  /// **'着丼！'**
  String get save;

  /// No description provided for @takePhoto.
  ///
  /// In ja, this message translates to:
  /// **'カメラで撮る'**
  String get takePhoto;

  /// No description provided for @retakePhoto.
  ///
  /// In ja, this message translates to:
  /// **'撮り直す'**
  String get retakePhoto;

  /// No description provided for @pickFromGallery.
  ///
  /// In ja, this message translates to:
  /// **'ギャラリーから選ぶ'**
  String get pickFromGallery;

  /// No description provided for @shopSection.
  ///
  /// In ja, this message translates to:
  /// **'店'**
  String get shopSection;

  /// No description provided for @shopSearching.
  ///
  /// In ja, this message translates to:
  /// **'近くの店を探しています…'**
  String get shopSearching;

  /// No description provided for @shopNoLocation.
  ///
  /// In ja, this message translates to:
  /// **'現在地がわかりませんでした。店名を入力してください'**
  String get shopNoLocation;

  /// No description provided for @shopSearchFailed.
  ///
  /// In ja, this message translates to:
  /// **'店を検索できませんでした。店名を入力してください'**
  String get shopSearchFailed;

  /// No description provided for @shopSearchPartial.
  ///
  /// In ja, this message translates to:
  /// **'店を検索できなかったため、記録済みの店だけを表示しています'**
  String get shopSearchPartial;

  /// No description provided for @shopNoCandidates.
  ///
  /// In ja, this message translates to:
  /// **'近くに候補が見つかりませんでした。店名を入力してください'**
  String get shopNoCandidates;

  /// No description provided for @shopSearchAfterPhoto.
  ///
  /// In ja, this message translates to:
  /// **'写真を選ぶと、近くの店を探します'**
  String get shopSearchAfterPhoto;

  /// No description provided for @shopNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'店名を入力'**
  String get shopNameLabel;

  /// No description provided for @shopNameHint.
  ///
  /// In ja, this message translates to:
  /// **'候補にないときはここに入力'**
  String get shopNameHint;

  /// No description provided for @shopVisited.
  ///
  /// In ja, this message translates to:
  /// **'記録あり'**
  String get shopVisited;

  /// No description provided for @distanceMeters.
  ///
  /// In ja, this message translates to:
  /// **'{meters}m'**
  String distanceMeters(int meters);

  /// No description provided for @shopSearchAttribution.
  ///
  /// In ja, this message translates to:
  /// **'© OpenStreetMap contributors ／ 出典: OpenPOI API（https://openpoiapi.com/attribution.html）'**
  String get shopSearchAttribution;

  /// No description provided for @ratingSection.
  ///
  /// In ja, this message translates to:
  /// **'評価'**
  String get ratingSection;

  /// No description provided for @ratingUnrated.
  ///
  /// In ja, this message translates to:
  /// **'未評価'**
  String get ratingUnrated;

  /// No description provided for @ratingPrompt.
  ///
  /// In ja, this message translates to:
  /// **'{shop} はどうでしたか？'**
  String ratingPrompt(String shop);

  /// No description provided for @ratingStar.
  ///
  /// In ja, this message translates to:
  /// **'★{stars}'**
  String ratingStar(int stars);

  /// No description provided for @styleSection.
  ///
  /// In ja, this message translates to:
  /// **'系統'**
  String get styleSection;

  /// No description provided for @styleShoyu.
  ///
  /// In ja, this message translates to:
  /// **'醤油'**
  String get styleShoyu;

  /// No description provided for @styleMiso.
  ///
  /// In ja, this message translates to:
  /// **'味噌'**
  String get styleMiso;

  /// No description provided for @styleShio.
  ///
  /// In ja, this message translates to:
  /// **'塩'**
  String get styleShio;

  /// No description provided for @styleTonkotsu.
  ///
  /// In ja, this message translates to:
  /// **'豚骨'**
  String get styleTonkotsu;

  /// No description provided for @styleIekei.
  ///
  /// In ja, this message translates to:
  /// **'家系'**
  String get styleIekei;

  /// No description provided for @styleJiro.
  ///
  /// In ja, this message translates to:
  /// **'二郎系'**
  String get styleJiro;

  /// No description provided for @styleTsukemen.
  ///
  /// In ja, this message translates to:
  /// **'つけ麺'**
  String get styleTsukemen;

  /// No description provided for @styleShirunashi.
  ///
  /// In ja, this message translates to:
  /// **'汁なし'**
  String get styleShirunashi;

  /// No description provided for @styleOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get styleOther;

  /// No description provided for @limitedSection.
  ///
  /// In ja, this message translates to:
  /// **'限定'**
  String get limitedSection;

  /// No description provided for @isLimited.
  ///
  /// In ja, this message translates to:
  /// **'限定メニュー'**
  String get isLimited;

  /// No description provided for @memoLabel.
  ///
  /// In ja, this message translates to:
  /// **'この一杯について'**
  String get memoLabel;

  /// No description provided for @memoHint.
  ///
  /// In ja, this message translates to:
  /// **'麺かため。前よりスープが濃い'**
  String get memoHint;

  /// No description provided for @memoHelper.
  ///
  /// In ja, this message translates to:
  /// **'この日の一杯の感想'**
  String get memoHelper;

  /// No description provided for @draftResumed.
  ///
  /// In ja, this message translates to:
  /// **'下書きから再開しました'**
  String get draftResumed;

  /// No description provided for @draftDiscard.
  ///
  /// In ja, this message translates to:
  /// **'下書きを捨てて新しく'**
  String get draftDiscard;

  /// No description provided for @draftDiscardTitle.
  ///
  /// In ja, this message translates to:
  /// **'下書きが残っています。破棄して新しく記録しますか？'**
  String get draftDiscardTitle;

  /// No description provided for @draftDiscardMessage.
  ///
  /// In ja, this message translates to:
  /// **'破棄すると、下書きの写真や店名などは消えます。記録した杯には影響しません'**
  String get draftDiscardMessage;

  /// No description provided for @draftDiscardConfirm.
  ///
  /// In ja, this message translates to:
  /// **'破棄して新しく記録する'**
  String get draftDiscardConfirm;

  /// No description provided for @draftDiscardCancel.
  ///
  /// In ja, this message translates to:
  /// **'下書きの続きから記録する'**
  String get draftDiscardCancel;

  /// No description provided for @leaveRecordTitle.
  ///
  /// In ja, this message translates to:
  /// **'記録をやめますか？'**
  String get leaveRecordTitle;

  /// No description provided for @leaveRecordMessage.
  ///
  /// In ja, this message translates to:
  /// **'下書きに残すと、次に記録の画面を開いたときに続きから記録できます'**
  String get leaveRecordMessage;

  /// No description provided for @leaveRecordKeepDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書きに残してやめる'**
  String get leaveRecordKeepDraft;

  /// No description provided for @leaveRecordDiscard.
  ///
  /// In ja, this message translates to:
  /// **'破棄してやめる'**
  String get leaveRecordDiscard;

  /// No description provided for @leaveRecordCancel.
  ///
  /// In ja, this message translates to:
  /// **'続ける'**
  String get leaveRecordCancel;

  /// No description provided for @cancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get cancel;

  /// No description provided for @edit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get delete;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'この記録を削除しますか？'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In ja, this message translates to:
  /// **'写真も削除されます。元に戻せません'**
  String get deleteConfirmMessage;

  /// No description provided for @deleteFailed.
  ///
  /// In ja, this message translates to:
  /// **'削除できませんでした'**
  String get deleteFailed;

  /// No description provided for @visitNotFound.
  ///
  /// In ja, this message translates to:
  /// **'記録が見つかりません'**
  String get visitNotFound;

  /// No description provided for @editTitle.
  ///
  /// In ja, this message translates to:
  /// **'記録を編集'**
  String get editTitle;

  /// No description provided for @editSave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get editSave;

  /// No description provided for @editSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存できませんでした。もう一度お試しください'**
  String get editSaveFailed;

  /// No description provided for @editShopName.
  ///
  /// In ja, this message translates to:
  /// **'店名'**
  String get editShopName;

  /// No description provided for @editEatenAt.
  ///
  /// In ja, this message translates to:
  /// **'食べた日時'**
  String get editEatenAt;

  /// No description provided for @editRemovePhoto.
  ///
  /// In ja, this message translates to:
  /// **'写真を外す'**
  String get editRemovePhoto;

  /// No description provided for @editPhotoFailed.
  ///
  /// In ja, this message translates to:
  /// **'写真を読み込めませんでした'**
  String get editPhotoFailed;

  /// No description provided for @editShopRepick.
  ///
  /// In ja, this message translates to:
  /// **'店を選び直す'**
  String get editShopRepick;

  /// No description provided for @editShopRepickTitle.
  ///
  /// In ja, this message translates to:
  /// **'どの店の記録ですか？'**
  String get editShopRepickTitle;

  /// No description provided for @editShopRepickNoLocation.
  ///
  /// In ja, this message translates to:
  /// **'店の位置も現在地もわかりませんでした。店名で探してください'**
  String get editShopRepickNoLocation;

  /// No description provided for @editShopRepickFailed.
  ///
  /// In ja, this message translates to:
  /// **'近くの店を検索できませんでした。店名で探すか、店名を書き換えてください'**
  String get editShopRepickFailed;

  /// No description provided for @editShopRepickNone.
  ///
  /// In ja, this message translates to:
  /// **'近くに候補が見つかりませんでした。店名で探してください'**
  String get editShopRepickNone;

  /// No description provided for @editShopRepickByName.
  ///
  /// In ja, this message translates to:
  /// **'店名で全国の店から探す'**
  String get editShopRepickByName;

  /// No description provided for @limitedBadge.
  ///
  /// In ja, this message translates to:
  /// **'限定'**
  String get limitedBadge;

  /// No description provided for @checkinTitle.
  ///
  /// In ja, this message translates to:
  /// **'並んだ店を選ぶ'**
  String get checkinTitle;

  /// No description provided for @checkinDone.
  ///
  /// In ja, this message translates to:
  /// **'{shop} に並びました。着丼したら真ん中の「着」を押す'**
  String checkinDone(String shop);

  /// No description provided for @checkinFailed.
  ///
  /// In ja, this message translates to:
  /// **'チェックインできませんでした。もう一度お試しください'**
  String get checkinFailed;

  /// No description provided for @checkinTooFar.
  ///
  /// In ja, this message translates to:
  /// **'100m以内に近づくとチェックインできます'**
  String get checkinTooFar;

  /// No description provided for @checkinNoLocation.
  ///
  /// In ja, this message translates to:
  /// **'現在地がわからないため、チェックインできません。位置情報をオンにして、もう一度お試しください'**
  String get checkinNoLocation;

  /// No description provided for @checkinSearchFailed.
  ///
  /// In ja, this message translates to:
  /// **'店を検索できませんでした。店名を入力してチェックインできます'**
  String get checkinSearchFailed;

  /// No description provided for @checkinNoCandidates.
  ///
  /// In ja, this message translates to:
  /// **'近くに候補が見つかりませんでした。店名を入力してチェックインできます'**
  String get checkinNoCandidates;

  /// No description provided for @checkinRetry.
  ///
  /// In ja, this message translates to:
  /// **'もう一度探す'**
  String get checkinRetry;

  /// No description provided for @checkinManualButton.
  ///
  /// In ja, this message translates to:
  /// **'この店名でチェックイン'**
  String get checkinManualButton;

  /// No description provided for @checkinBanner.
  ///
  /// In ja, this message translates to:
  /// **'{shop} に並び中'**
  String checkinBanner(String shop);

  /// No description provided for @checkinWaiting.
  ///
  /// In ja, this message translates to:
  /// **'並び始めてから {minutes}分'**
  String checkinWaiting(int minutes);

  /// No description provided for @checkinNotificationBody.
  ///
  /// In ja, this message translates to:
  /// **'{time} から並んでいます。着丼したらアプリの真ん中の「着」を押しましょう'**
  String checkinNotificationBody(String time);

  /// No description provided for @streakWeeks.
  ///
  /// In ja, this message translates to:
  /// **'{weeks}週連続で着丼中'**
  String streakWeeks(int weeks);

  /// No description provided for @streakAtRisk.
  ///
  /// In ja, this message translates to:
  /// **'今週はまだ'**
  String get streakAtRisk;

  /// No description provided for @streakReminderTitle.
  ///
  /// In ja, this message translates to:
  /// **'{weeks}週連続の記録が途切れそう'**
  String streakReminderTitle(String weeks);

  /// No description provided for @checkinCancel.
  ///
  /// In ja, this message translates to:
  /// **'取り消す'**
  String get checkinCancel;

  /// No description provided for @checkinBannerHint.
  ///
  /// In ja, this message translates to:
  /// **'着丼したら、真ん中の「着」を押す'**
  String get checkinBannerHint;

  /// No description provided for @checkinCancelTitle.
  ///
  /// In ja, this message translates to:
  /// **'チェックインを取り消しますか？'**
  String get checkinCancelTitle;

  /// No description provided for @checkinCancelMessage.
  ///
  /// In ja, this message translates to:
  /// **'並んだ記録は残りません'**
  String get checkinCancelMessage;

  /// No description provided for @checkinKeep.
  ///
  /// In ja, this message translates to:
  /// **'並び続ける'**
  String get checkinKeep;

  /// No description provided for @retreat.
  ///
  /// In ja, this message translates to:
  /// **'撤退'**
  String get retreat;

  /// No description provided for @retreatTitle.
  ///
  /// In ja, this message translates to:
  /// **'撤退を記録しますか？'**
  String get retreatTitle;

  /// No description provided for @retreatMessage.
  ///
  /// In ja, this message translates to:
  /// **'食べられなかった記録として残します。次に同じ店で食べると「再挑戦成功」になります'**
  String get retreatMessage;

  /// No description provided for @retreatReasonSoldOut.
  ///
  /// In ja, this message translates to:
  /// **'売り切れ'**
  String get retreatReasonSoldOut;

  /// No description provided for @retreatReasonClosed.
  ///
  /// In ja, this message translates to:
  /// **'臨時休業'**
  String get retreatReasonClosed;

  /// No description provided for @retreatReasonNoTime.
  ///
  /// In ja, this message translates to:
  /// **'時間切れ'**
  String get retreatReasonNoTime;

  /// No description provided for @retreatMemoLabel.
  ///
  /// In ja, this message translates to:
  /// **'メモ（任意）'**
  String get retreatMemoLabel;

  /// No description provided for @retreatConfirm.
  ///
  /// In ja, this message translates to:
  /// **'撤退を記録'**
  String get retreatConfirm;

  /// No description provided for @retreatSaved.
  ///
  /// In ja, this message translates to:
  /// **'撤退を記録し、願掛け帳に入れました'**
  String get retreatSaved;

  /// No description provided for @retreatFailed.
  ///
  /// In ja, this message translates to:
  /// **'記録できませんでした。もう一度お試しください'**
  String get retreatFailed;

  /// No description provided for @retreatBadge.
  ///
  /// In ja, this message translates to:
  /// **'撤退'**
  String get retreatBadge;

  /// No description provided for @waitTime.
  ///
  /// In ja, this message translates to:
  /// **'着丼まで {minutes}分'**
  String waitTime(int minutes);

  /// No description provided for @rankApprentice.
  ///
  /// In ja, this message translates to:
  /// **'入門'**
  String get rankApprentice;

  /// No description provided for @rankFirstDan.
  ///
  /// In ja, this message translates to:
  /// **'初段'**
  String get rankFirstDan;

  /// No description provided for @rankKyu.
  ///
  /// In ja, this message translates to:
  /// **'{number}級'**
  String rankKyu(String number);

  /// No description provided for @rankDan.
  ///
  /// In ja, this message translates to:
  /// **'{number}段'**
  String rankDan(String number);

  /// No description provided for @rankMaster.
  ///
  /// In ja, this message translates to:
  /// **'師範代'**
  String get rankMaster;

  /// No description provided for @rankGrandmaster.
  ///
  /// In ja, this message translates to:
  /// **'免許皆伝'**
  String get rankGrandmaster;

  /// No description provided for @points.
  ///
  /// In ja, this message translates to:
  /// **'{points}点'**
  String points(int points);

  /// No description provided for @pointsGained.
  ///
  /// In ja, this message translates to:
  /// **'+{points}点'**
  String pointsGained(int points);

  /// No description provided for @pointsSection.
  ///
  /// In ja, this message translates to:
  /// **'修行点'**
  String get pointsSection;

  /// No description provided for @pointsBase.
  ///
  /// In ja, this message translates to:
  /// **'基本'**
  String get pointsBase;

  /// No description provided for @pointsWait.
  ///
  /// In ja, this message translates to:
  /// **'着丼まで {minutes}分'**
  String pointsWait(int minutes);

  /// No description provided for @pointsFirstVisit.
  ///
  /// In ja, this message translates to:
  /// **'初訪問'**
  String get pointsFirstVisit;

  /// No description provided for @pointsRetry.
  ///
  /// In ja, this message translates to:
  /// **'再挑戦成功'**
  String get pointsRetry;

  /// No description provided for @pointsExpedition.
  ///
  /// In ja, this message translates to:
  /// **'遠征（{km}km以上）'**
  String pointsExpedition(int km);

  /// No description provided for @pointsNewPrefecture.
  ///
  /// In ja, this message translates to:
  /// **'初めての都道府県（{name}）'**
  String pointsNewPrefecture(String name);

  /// No description provided for @pointsNewArea.
  ///
  /// In ja, this message translates to:
  /// **'初めての市区町村（{name}）'**
  String pointsNewArea(String name);

  /// No description provided for @pointsRegular.
  ///
  /// In ja, this message translates to:
  /// **'常連（この店で{count}杯目）'**
  String pointsRegular(int count);

  /// No description provided for @pointsStreak.
  ///
  /// In ja, this message translates to:
  /// **'連続記録（{weeks}週目）'**
  String pointsStreak(int weeks);

  /// No description provided for @pointsFamous.
  ///
  /// In ja, this message translates to:
  /// **'名店'**
  String get pointsFamous;

  /// No description provided for @pointsEarly.
  ///
  /// In ja, this message translates to:
  /// **'朝ラー'**
  String get pointsEarly;

  /// No description provided for @pointsLateNight.
  ///
  /// In ja, this message translates to:
  /// **'深夜'**
  String get pointsLateNight;

  /// No description provided for @pointsRetreat.
  ///
  /// In ja, this message translates to:
  /// **'撤退の記録に修行点はつきません'**
  String get pointsRetreat;

  /// No description provided for @totalPoints.
  ///
  /// In ja, this message translates to:
  /// **'修行点 {points}'**
  String totalPoints(int points);

  /// No description provided for @nextRank.
  ///
  /// In ja, this message translates to:
  /// **'{rank}まで あと {points}点'**
  String nextRank(String rank, int points);

  /// No description provided for @maxRank.
  ///
  /// In ja, this message translates to:
  /// **'免許皆伝に至りました'**
  String get maxRank;

  /// No description provided for @nextRankReady.
  ///
  /// In ja, this message translates to:
  /// **'次の一杯で{rank}'**
  String nextRankReady(String rank);

  /// No description provided for @rankHistoryReady.
  ///
  /// In ja, this message translates to:
  /// **'次の一杯で上がる'**
  String get rankHistoryReady;

  /// No description provided for @rankUp.
  ///
  /// In ja, this message translates to:
  /// **'昇段！'**
  String get rankUp;

  /// No description provided for @rankUpKyu.
  ///
  /// In ja, this message translates to:
  /// **'昇級！'**
  String get rankUpKyu;

  /// No description provided for @rankHistoryTitle.
  ///
  /// In ja, this message translates to:
  /// **'昇段の記録'**
  String get rankHistoryTitle;

  /// No description provided for @rankHistoryAchievedAt.
  ///
  /// In ja, this message translates to:
  /// **'{date}　{shop}にて達成'**
  String rankHistoryAchievedAt(String date, String shop);

  /// No description provided for @rankHistoryNoRecord.
  ///
  /// In ja, this message translates to:
  /// **'最初の一杯から修行が始まります'**
  String get rankHistoryNoRecord;

  /// No description provided for @rankHistoryRemaining.
  ///
  /// In ja, this message translates to:
  /// **'あと {points}点'**
  String rankHistoryRemaining(int points);

  /// No description provided for @rankHistoryHidden.
  ///
  /// In ja, this message translates to:
  /// **'？？'**
  String get rankHistoryHidden;

  /// No description provided for @resultTitle.
  ///
  /// In ja, this message translates to:
  /// **'着丼！'**
  String get resultTitle;

  /// No description provided for @resultOk.
  ///
  /// In ja, this message translates to:
  /// **'印帳にもどる'**
  String get resultOk;

  /// No description provided for @resultShare.
  ///
  /// In ja, this message translates to:
  /// **'共有する'**
  String get resultShare;

  /// No description provided for @navRecords.
  ///
  /// In ja, this message translates to:
  /// **'印帳'**
  String get navRecords;

  /// No description provided for @questStanding.
  ///
  /// In ja, this message translates to:
  /// **'型'**
  String get questStanding;

  /// No description provided for @questSpot.
  ///
  /// In ja, this message translates to:
  /// **'秘伝'**
  String get questSpot;

  /// No description provided for @questLevelTotal.
  ///
  /// In ja, this message translates to:
  /// **'段の合計 {total}'**
  String questLevelTotal(int total);

  /// No description provided for @questSpotSummary.
  ///
  /// In ja, this message translates to:
  /// **'会得 {achieved} / {total}'**
  String questSpotSummary(int achieved, int total);

  /// No description provided for @questLevel.
  ///
  /// In ja, this message translates to:
  /// **'{level}段'**
  String questLevel(String level);

  /// No description provided for @questMaxLevel.
  ///
  /// In ja, this message translates to:
  /// **'極み'**
  String get questMaxLevel;

  /// No description provided for @questCleared.
  ///
  /// In ja, this message translates to:
  /// **'会得'**
  String get questCleared;

  /// No description provided for @questNext.
  ///
  /// In ja, this message translates to:
  /// **'{current}／{target}{unit}'**
  String questNext(int current, int target, String unit);

  /// No description provided for @questCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}{unit}'**
  String questCount(int count, String unit);

  /// No description provided for @questLevelUp.
  ///
  /// In ja, this message translates to:
  /// **'型 昇段！'**
  String get questLevelUp;

  /// No description provided for @questLevelReached.
  ///
  /// In ja, this message translates to:
  /// **'{title} {level}段'**
  String questLevelReached(String title, String level);

  /// No description provided for @questAchieved.
  ///
  /// In ja, this message translates to:
  /// **'秘伝会得！'**
  String get questAchieved;

  /// No description provided for @statsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'記録が増えると、ここに統計が出ます'**
  String get statsEmpty;

  /// No description provided for @bowls.
  ///
  /// In ja, this message translates to:
  /// **'{count}杯'**
  String bowls(int count);

  /// No description provided for @statsStyles.
  ///
  /// In ja, this message translates to:
  /// **'系統の割合'**
  String get statsStyles;

  /// No description provided for @styleUnset.
  ///
  /// In ja, this message translates to:
  /// **'系統なし'**
  String get styleUnset;

  /// No description provided for @percent.
  ///
  /// In ja, this message translates to:
  /// **'{percent}%'**
  String percent(int percent);

  /// No description provided for @statsFrequent.
  ///
  /// In ja, this message translates to:
  /// **'よく行く店'**
  String get statsFrequent;

  /// No description provided for @statsFrequentNone.
  ///
  /// In ja, this message translates to:
  /// **'2杯以上食べた店が、ここに並びます'**
  String get statsFrequentNone;

  /// No description provided for @shopMemoSection.
  ///
  /// In ja, this message translates to:
  /// **'店の覚え書き'**
  String get shopMemoSection;

  /// No description provided for @shopMemoHelper.
  ///
  /// In ja, this message translates to:
  /// **'次に来るときのために、店のことを書いておく'**
  String get shopMemoHelper;

  /// No description provided for @shopFamousToggle.
  ///
  /// In ja, this message translates to:
  /// **'名店の印をつける'**
  String get shopFamousToggle;

  /// No description provided for @shopFamousNeedsShop.
  ///
  /// In ja, this message translates to:
  /// **'店を決めると付けられます'**
  String get shopFamousNeedsShop;

  /// No description provided for @shopMemoEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだありません'**
  String get shopMemoEmpty;

  /// No description provided for @shopMemoHint.
  ///
  /// In ja, this message translates to:
  /// **'券売機は現金のみ／11時前に着けば一巡目'**
  String get shopMemoHint;

  /// No description provided for @shopMemoNeedsShop.
  ///
  /// In ja, this message translates to:
  /// **'店を決めると書けます'**
  String get shopMemoNeedsShop;

  /// No description provided for @shopMemoEdit.
  ///
  /// In ja, this message translates to:
  /// **'店の覚え書きを書く'**
  String get shopMemoEdit;

  /// No description provided for @shopMemoInline.
  ///
  /// In ja, this message translates to:
  /// **'店の覚え書き: {memo}'**
  String shopMemoInline(String memo);

  /// No description provided for @navWishes.
  ///
  /// In ja, this message translates to:
  /// **'願掛け'**
  String get navWishes;

  /// No description provided for @wishTitle.
  ///
  /// In ja, this message translates to:
  /// **'願掛け帳'**
  String get wishTitle;

  /// No description provided for @wishSealChar.
  ///
  /// In ja, this message translates to:
  /// **'願'**
  String get wishSealChar;

  /// No description provided for @wishPendingTab.
  ///
  /// In ja, this message translates to:
  /// **'まだの願 {count}'**
  String wishPendingTab(int count);

  /// No description provided for @wishFulfilledTab.
  ///
  /// In ja, this message translates to:
  /// **'叶った願 {count}'**
  String wishFulfilledTab(int count);

  /// No description provided for @wishPendingEmpty.
  ///
  /// In ja, this message translates to:
  /// **'行きたい店を書き留めておきましょう。\n地図の灰色のピンや店のページから願を掛けられます。右下の＋なら店名だけで書き留められます'**
  String get wishPendingEmpty;

  /// No description provided for @wishFulfilledEmpty.
  ///
  /// In ja, this message translates to:
  /// **'願を掛けた店で「着丼！」すると、ここに並びます'**
  String get wishFulfilledEmpty;

  /// No description provided for @wishAddTitle.
  ///
  /// In ja, this message translates to:
  /// **'願を掛ける'**
  String get wishAddTitle;

  /// No description provided for @wishEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'願を書き直す'**
  String get wishEditTitle;

  /// No description provided for @wishAddButton.
  ///
  /// In ja, this message translates to:
  /// **'願を掛ける'**
  String get wishAddButton;

  /// No description provided for @wishMakeButton.
  ///
  /// In ja, this message translates to:
  /// **'願を掛ける（行きたい）'**
  String get wishMakeButton;

  /// No description provided for @wishAlready.
  ///
  /// In ja, this message translates to:
  /// **'この店には願を掛けています'**
  String get wishAlready;

  /// No description provided for @wishShopName.
  ///
  /// In ja, this message translates to:
  /// **'店名'**
  String get wishShopName;

  /// No description provided for @wishTrigger.
  ///
  /// In ja, this message translates to:
  /// **'きっかけ（任意）'**
  String get wishTrigger;

  /// No description provided for @wishTriggerHint.
  ///
  /// In ja, this message translates to:
  /// **'同僚に聞いた・テレビで見た など'**
  String get wishTriggerHint;

  /// No description provided for @wishNote.
  ///
  /// In ja, this message translates to:
  /// **'ひとこと（任意）'**
  String get wishNote;

  /// No description provided for @wishNoteHint.
  ///
  /// In ja, this message translates to:
  /// **'限定の煮干しを食べたい など'**
  String get wishNoteHint;

  /// No description provided for @wishLink.
  ///
  /// In ja, this message translates to:
  /// **'リンク（任意）'**
  String get wishLink;

  /// No description provided for @wishLinkHint.
  ///
  /// In ja, this message translates to:
  /// **'Google マップや YouTube の URL'**
  String get wishLinkHint;

  /// No description provided for @wishLinkOpen.
  ///
  /// In ja, this message translates to:
  /// **'リンクを開く（{host}）'**
  String wishLinkOpen(String host);

  /// No description provided for @wishLinkOpenFailed.
  ///
  /// In ja, this message translates to:
  /// **'リンクを開けませんでした'**
  String get wishLinkOpenFailed;

  /// No description provided for @wishPlaceNone.
  ///
  /// In ja, this message translates to:
  /// **'場所: まだ決めていません（決めなくても掛けられます）'**
  String get wishPlaceNone;

  /// No description provided for @wishPlaceLooking.
  ///
  /// In ja, this message translates to:
  /// **'場所: 住所から調べています…'**
  String get wishPlaceLooking;

  /// No description provided for @wishPlaceFromLink.
  ///
  /// In ja, this message translates to:
  /// **'場所: リンクに書かれた位置'**
  String get wishPlaceFromLink;

  /// No description provided for @wishPlaceFromAddress.
  ///
  /// In ja, this message translates to:
  /// **'場所: 住所から決めました'**
  String get wishPlaceFromAddress;

  /// No description provided for @wishPlaceFromSearch.
  ///
  /// In ja, this message translates to:
  /// **'場所: 店名で探した店'**
  String get wishPlaceFromSearch;

  /// No description provided for @wishTriggerGoogleMaps.
  ///
  /// In ja, this message translates to:
  /// **'Google マップ'**
  String get wishTriggerGoogleMaps;

  /// No description provided for @wishTriggerAppleMaps.
  ///
  /// In ja, this message translates to:
  /// **'Apple マップ'**
  String get wishTriggerAppleMaps;

  /// No description provided for @wishTriggerYouTube.
  ///
  /// In ja, this message translates to:
  /// **'YouTube'**
  String get wishTriggerYouTube;

  /// No description provided for @wishTriggerLine.
  ///
  /// In ja, this message translates to:
  /// **'きっかけ: {trigger}'**
  String wishTriggerLine(String trigger);

  /// No description provided for @wishFulfilledLine.
  ///
  /// In ja, this message translates to:
  /// **'{date} 願成就（{days}日越し）'**
  String wishFulfilledLine(String date, int days);

  /// No description provided for @wishAdded.
  ///
  /// In ja, this message translates to:
  /// **'{name} に願を掛けました'**
  String wishAdded(String name);

  /// No description provided for @wishSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'願を書き留められませんでした'**
  String get wishSaveFailed;

  /// No description provided for @wishDeleteConfirm.
  ///
  /// In ja, this message translates to:
  /// **'{name} の願を消しますか？'**
  String wishDeleteConfirm(String name);

  /// No description provided for @wishFulfilled.
  ///
  /// In ja, this message translates to:
  /// **'願成就'**
  String get wishFulfilled;

  /// No description provided for @wishFulfilledSealChar.
  ///
  /// In ja, this message translates to:
  /// **'叶'**
  String get wishFulfilledSealChar;

  /// No description provided for @wishFulfillPrompt.
  ///
  /// In ja, this message translates to:
  /// **'{name} の願を、この一杯で叶えたことにしますか？'**
  String wishFulfillPrompt(String name);

  /// No description provided for @wishFulfillButton.
  ///
  /// In ja, this message translates to:
  /// **'叶えた'**
  String get wishFulfillButton;

  /// No description provided for @shopWished.
  ///
  /// In ja, this message translates to:
  /// **'願掛け中'**
  String get shopWished;

  /// No description provided for @wishFulfilledAfter.
  ///
  /// In ja, this message translates to:
  /// **'願を掛けてから {days}日、ついに着丼'**
  String wishFulfilledAfter(String days);

  /// No description provided for @wishFulfilledSameDay.
  ///
  /// In ja, this message translates to:
  /// **'願を掛けたその日に着丼'**
  String get wishFulfilledSameDay;

  /// No description provided for @mapWished.
  ///
  /// In ja, this message translates to:
  /// **'願掛け中の店'**
  String get mapWished;

  /// No description provided for @mapWishedLabel.
  ///
  /// In ja, this message translates to:
  /// **'願掛け中の店 {name}'**
  String mapWishedLabel(String name);

  /// No description provided for @journalTitle.
  ///
  /// In ja, this message translates to:
  /// **'道中記'**
  String get journalTitle;

  /// No description provided for @shareTitle.
  ///
  /// In ja, this message translates to:
  /// **'この一杯を共有'**
  String get shareTitle;

  /// No description provided for @shareIncludePhoto.
  ///
  /// In ja, this message translates to:
  /// **'写真を入れる'**
  String get shareIncludePhoto;

  /// No description provided for @shareIncludeJournal.
  ///
  /// In ja, this message translates to:
  /// **'道中記を入れる'**
  String get shareIncludeJournal;

  /// No description provided for @shareIncludePoints.
  ///
  /// In ja, this message translates to:
  /// **'修行点を入れる'**
  String get shareIncludePoints;

  /// No description provided for @shareNote.
  ///
  /// In ja, this message translates to:
  /// **'店の場所（地図）は入りません。共有を押したときだけ、選んだ相手やアプリに送られます'**
  String get shareNote;

  /// No description provided for @shareButton.
  ///
  /// In ja, this message translates to:
  /// **'共有する'**
  String get shareButton;

  /// No description provided for @shareFailed.
  ///
  /// In ja, this message translates to:
  /// **'共有できませんでした'**
  String get shareFailed;

  /// No description provided for @journeyToggle.
  ///
  /// In ja, this message translates to:
  /// **'旅路'**
  String get journeyToggle;

  /// No description provided for @journeyAllYears.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get journeyAllYears;

  /// No description provided for @journeyYear.
  ///
  /// In ja, this message translates to:
  /// **'{year}年'**
  String journeyYear(int year);

  /// No description provided for @journeySummary.
  ///
  /// In ja, this message translates to:
  /// **'{shops}軒をめぐる麺の道 {km}km'**
  String journeySummary(int shops, String km);

  /// No description provided for @journeyEmpty.
  ///
  /// In ja, this message translates to:
  /// **'位置のわかる店で食べると、旅路が引かれます'**
  String get journeyEmpty;

  /// No description provided for @journeyReplay.
  ///
  /// In ja, this message translates to:
  /// **'旅路を再生'**
  String get journeyReplay;

  /// No description provided for @journeyStop.
  ///
  /// In ja, this message translates to:
  /// **'止める'**
  String get journeyStop;

  /// No description provided for @journeyExpeditions.
  ///
  /// In ja, this message translates to:
  /// **'遠征'**
  String get journeyExpeditions;

  /// No description provided for @journeyExpeditionsTitle.
  ///
  /// In ja, this message translates to:
  /// **'遠征の記録'**
  String get journeyExpeditionsTitle;

  /// No description provided for @journeyExpeditionsNone.
  ///
  /// In ja, this message translates to:
  /// **'拠点から80km以上離れた店で食べた日が、遠征として並びます'**
  String get journeyExpeditionsNone;

  /// No description provided for @homeBaseLine.
  ///
  /// In ja, this message translates to:
  /// **'今の拠点: {name}'**
  String homeBaseLine(String name);

  /// No description provided for @homeBaseNone.
  ///
  /// In ja, this message translates to:
  /// **'拠点を決めると、遠くの一杯が「遠征」になります'**
  String get homeBaseNone;

  /// No description provided for @homeBaseSealChar.
  ///
  /// In ja, this message translates to:
  /// **'拠'**
  String get homeBaseSealChar;

  /// No description provided for @homeBasePinLabel.
  ///
  /// In ja, this message translates to:
  /// **'今の拠点（{name}）'**
  String homeBasePinLabel(String name);

  /// No description provided for @homeBaseTitle.
  ///
  /// In ja, this message translates to:
  /// **'拠点'**
  String get homeBaseTitle;

  /// No description provided for @homeBaseNotSet.
  ///
  /// In ja, this message translates to:
  /// **'まだ決めていません'**
  String get homeBaseNotSet;

  /// No description provided for @homeBaseIntro.
  ///
  /// In ja, this message translates to:
  /// **'地図を動かして、ふだん暮らしているあたりを真ん中の「拠」に合わせてください。家の場所でなくても、駅や街のあたりで十分です。拠点から80km以上離れた店で食べると「遠征」になります。変えても、変えた日から後の記録にだけ効きます。'**
  String get homeBaseIntro;

  /// No description provided for @homeBaseUseCenter.
  ///
  /// In ja, this message translates to:
  /// **'ここを拠点にする'**
  String get homeBaseUseCenter;

  /// No description provided for @homeBaseCenterLabel.
  ///
  /// In ja, this message translates to:
  /// **'地図の真ん中。ここが拠点になります'**
  String get homeBaseCenterLabel;

  /// No description provided for @homeBaseUseHere.
  ///
  /// In ja, this message translates to:
  /// **'現在地を拠点にする'**
  String get homeBaseUseHere;

  /// No description provided for @homeBaseNameTitle.
  ///
  /// In ja, this message translates to:
  /// **'拠点の呼び名'**
  String get homeBaseNameTitle;

  /// No description provided for @homeBaseNameDefault.
  ///
  /// In ja, this message translates to:
  /// **'このあたり'**
  String get homeBaseNameDefault;

  /// No description provided for @homeBaseNameHint.
  ///
  /// In ja, this message translates to:
  /// **'駅や街の名前など（例: 新宿、札幌）'**
  String get homeBaseNameHint;

  /// No description provided for @homeBaseDecide.
  ///
  /// In ja, this message translates to:
  /// **'決める'**
  String get homeBaseDecide;

  /// No description provided for @homeBaseHereFailed.
  ///
  /// In ja, this message translates to:
  /// **'現在地がわかりませんでした'**
  String get homeBaseHereFailed;

  /// No description provided for @homeBaseSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'拠点を保存できませんでした'**
  String get homeBaseSaveFailed;

  /// No description provided for @homeBaseSaved.
  ///
  /// In ja, this message translates to:
  /// **'拠点を{name}にしました'**
  String homeBaseSaved(String name);

  /// No description provided for @homeBaseHistoryTitle.
  ///
  /// In ja, this message translates to:
  /// **'これまでの拠点'**
  String get homeBaseHistoryTitle;

  /// No description provided for @homeBaseHistoryFrom.
  ///
  /// In ja, this message translates to:
  /// **'{date}から'**
  String homeBaseHistoryFrom(String date);

  /// No description provided for @homeBaseEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'拠点を直す'**
  String get homeBaseEditTitle;

  /// No description provided for @homeBaseEditDate.
  ///
  /// In ja, this message translates to:
  /// **'日付（この日から効きます）'**
  String get homeBaseEditDate;

  /// No description provided for @homeBaseEditName.
  ///
  /// In ja, this message translates to:
  /// **'呼び名'**
  String get homeBaseEditName;

  /// No description provided for @homeBaseEditPlace.
  ///
  /// In ja, this message translates to:
  /// **'場所'**
  String get homeBaseEditPlace;

  /// No description provided for @homeBaseEditPlaceHint.
  ///
  /// In ja, this message translates to:
  /// **'地図を動かして直す'**
  String get homeBaseEditPlaceHint;

  /// No description provided for @homeBaseRelocateIntro.
  ///
  /// In ja, this message translates to:
  /// **'地図を動かして、{name}の場所を真ん中の「拠」に合わせてください。'**
  String homeBaseRelocateIntro(String name);

  /// No description provided for @homeBaseRelocateLine.
  ///
  /// In ja, this message translates to:
  /// **'{name}の場所を直します'**
  String homeBaseRelocateLine(String name);

  /// No description provided for @homeBaseRelocateHere.
  ///
  /// In ja, this message translates to:
  /// **'この場所に直す'**
  String get homeBaseRelocateHere;

  /// No description provided for @homeBaseRelocated.
  ///
  /// In ja, this message translates to:
  /// **'{name}の場所を直しました'**
  String homeBaseRelocated(String name);

  /// No description provided for @homeBaseDelete.
  ///
  /// In ja, this message translates to:
  /// **'この拠点を消す'**
  String get homeBaseDelete;

  /// No description provided for @homeBaseDeleteConfirm.
  ///
  /// In ja, this message translates to:
  /// **'拠点「{name}」を消しますか？'**
  String homeBaseDeleteConfirm(String name);

  /// No description provided for @homeBaseDeleteToPrevious.
  ///
  /// In ja, this message translates to:
  /// **'{date}から後の記録は、ひとつ前の拠点（{previous}）から遠征かどうかを決め直します。'**
  String homeBaseDeleteToPrevious(String date, String previous);

  /// No description provided for @homeBaseDeleteToNone.
  ///
  /// In ja, this message translates to:
  /// **'これより前の拠点が無いので、{date}から次の拠点までの記録は遠征になりません。'**
  String homeBaseDeleteToNone(String date);

  /// No description provided for @homeBaseDeleteLast.
  ///
  /// In ja, this message translates to:
  /// **'拠点がひとつも無くなり、遠征になる記録も、秘伝「拠点を構える」も無くなります。'**
  String get homeBaseDeleteLast;

  /// No description provided for @homeBaseDeleted.
  ///
  /// In ja, this message translates to:
  /// **'拠点「{name}」を消しました'**
  String homeBaseDeleted(String name);

  /// No description provided for @homeBaseHidenGained.
  ///
  /// In ja, this message translates to:
  /// **'秘伝「拠点を構える」を会得！\n修行タブの「型と秘伝」で見られます'**
  String get homeBaseHidenGained;

  /// No description provided for @homeBaseHidenOk.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get homeBaseHidenOk;

  /// No description provided for @journeyExpeditionName.
  ///
  /// In ja, this message translates to:
  /// **'{month}月{day}日の遠征（{shop}）'**
  String journeyExpeditionName(int month, int day, String shop);

  /// No description provided for @memoryYearsAgo.
  ///
  /// In ja, this message translates to:
  /// **'{years}年前の今日'**
  String memoryYearsAgo(String years);

  /// No description provided for @memoryLine.
  ///
  /// In ja, this message translates to:
  /// **'{shop}で着丼していました'**
  String memoryLine(String shop);

  /// No description provided for @memoryNotSince.
  ///
  /// In ja, this message translates to:
  /// **'あれから一度も行っていません。久しぶりにどうですか'**
  String get memoryNotSince;

  /// No description provided for @memoryDismiss.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get memoryDismiss;

  /// No description provided for @queueSuggestion.
  ///
  /// In ja, this message translates to:
  /// **'{shop} に並んだ？'**
  String queueSuggestion(String shop);

  /// No description provided for @queueSuggestionWished.
  ///
  /// In ja, this message translates to:
  /// **'願掛けの {shop} に並んだ？'**
  String queueSuggestionWished(String shop);

  /// No description provided for @queueSuggestionYes.
  ///
  /// In ja, this message translates to:
  /// **'並んだ'**
  String get queueSuggestionYes;

  /// No description provided for @queueSuggestionDismiss.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get queueSuggestionDismiss;

  /// No description provided for @queueSuggestionFailed.
  ///
  /// In ja, this message translates to:
  /// **'並んだ時刻を残せませんでした'**
  String get queueSuggestionFailed;

  /// No description provided for @nameSearchOpen.
  ///
  /// In ja, this message translates to:
  /// **'店名から探す'**
  String get nameSearchOpen;

  /// No description provided for @nameSearchTitle.
  ///
  /// In ja, this message translates to:
  /// **'店名で探す'**
  String get nameSearchTitle;

  /// No description provided for @nameSearchButton.
  ///
  /// In ja, this message translates to:
  /// **'探す'**
  String get nameSearchButton;

  /// No description provided for @nameSearchNone.
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした。店名を短くして探してみてください'**
  String get nameSearchNone;

  /// No description provided for @nameSearchFailed.
  ///
  /// In ja, this message translates to:
  /// **'探せませんでした。電波のよいところでもう一度試してください'**
  String get nameSearchFailed;

  /// No description provided for @nameSearchDistance.
  ///
  /// In ja, this message translates to:
  /// **'{km}km'**
  String nameSearchDistance(String km);

  /// No description provided for @shopLocate.
  ///
  /// In ja, this message translates to:
  /// **'地図に載せる（店名で探す）'**
  String get shopLocate;

  /// No description provided for @shopLocated.
  ///
  /// In ja, this message translates to:
  /// **'地図に載せました'**
  String get shopLocated;

  /// No description provided for @openInMaps.
  ///
  /// In ja, this message translates to:
  /// **'地図アプリで開く'**
  String get openInMaps;

  /// No description provided for @openInMapsFailed.
  ///
  /// In ja, this message translates to:
  /// **'地図アプリを開けませんでした'**
  String get openInMapsFailed;

  /// No description provided for @locationPickTitle.
  ///
  /// In ja, this message translates to:
  /// **'店の場所を指す'**
  String get locationPickTitle;

  /// No description provided for @locationPickIntro.
  ///
  /// In ja, this message translates to:
  /// **'地図を動かして、「{name}」の場所に真ん中のピンの先を合わせてください。'**
  String locationPickIntro(String name);

  /// No description provided for @locationPickUseCenter.
  ///
  /// In ja, this message translates to:
  /// **'ここを店の場所にする'**
  String get locationPickUseCenter;

  /// No description provided for @locationPickCenterLabel.
  ///
  /// In ja, this message translates to:
  /// **'地図の真ん中。ピンの先が店の場所になります'**
  String get locationPickCenterLabel;

  /// No description provided for @locationPickSealChar.
  ///
  /// In ja, this message translates to:
  /// **'店'**
  String get locationPickSealChar;

  /// No description provided for @locationPickOpen.
  ///
  /// In ja, this message translates to:
  /// **'地図で場所を指す'**
  String get locationPickOpen;

  /// No description provided for @locationPicked.
  ///
  /// In ja, this message translates to:
  /// **'場所: 地図で指定済み'**
  String get locationPicked;

  /// No description provided for @locationPickRedo.
  ///
  /// In ja, this message translates to:
  /// **'指し直す'**
  String get locationPickRedo;

  /// No description provided for @locationPickClear.
  ///
  /// In ja, this message translates to:
  /// **'外す'**
  String get locationPickClear;

  /// No description provided for @shopRelocate.
  ///
  /// In ja, this message translates to:
  /// **'店の場所を直す'**
  String get shopRelocate;

  /// No description provided for @yahooAttribution.
  ///
  /// In ja, this message translates to:
  /// **'Web Services by Yahoo! JAPAN（https://developer.yahoo.co.jp/sitemap/）'**
  String get yahooAttribution;

  /// No description provided for @creditsYahoo.
  ///
  /// In ja, this message translates to:
  /// **'店の情報: Web Services by Yahoo! JAPAN（https://developer.yahoo.co.jp/sitemap/）'**
  String get creditsYahoo;

  /// No description provided for @backupTitle.
  ///
  /// In ja, this message translates to:
  /// **'バックアップ'**
  String get backupTitle;

  /// No description provided for @creditsTitle.
  ///
  /// In ja, this message translates to:
  /// **'出典・ライセンス'**
  String get creditsTitle;

  /// No description provided for @creditsServicesHeading.
  ///
  /// In ja, this message translates to:
  /// **'地図と店の情報'**
  String get creditsServicesHeading;

  /// No description provided for @creditsOsm.
  ///
  /// In ja, this message translates to:
  /// **'地図と店の情報: © OpenStreetMap contributors（ODbL）'**
  String get creditsOsm;

  /// No description provided for @creditsGsi.
  ///
  /// In ja, this message translates to:
  /// **'ラーメン二郎の店の位置: 住所から国土地理院の住所検索で求めたもの'**
  String get creditsGsi;

  /// No description provided for @creditsPrefectures.
  ///
  /// In ja, this message translates to:
  /// **'都道府県の境界: 出典 国土数値情報（行政区域データ）（国土交通省）（https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2024.html）を加工して作成（CC BY 4.0）'**
  String get creditsPrefectures;

  /// No description provided for @creditsOpenPoi.
  ///
  /// In ja, this message translates to:
  /// **'店の情報: 出典 OpenPOI API（https://openpoiapi.com/attribution.html）'**
  String get creditsOpenPoi;

  /// No description provided for @creditsSavedShopsHeading.
  ///
  /// In ja, this message translates to:
  /// **'記録した店の出典'**
  String get creditsSavedShopsHeading;

  /// No description provided for @creditsSavedShopsNote.
  ///
  /// In ja, this message translates to:
  /// **'OpenPOI API で見つけて記録した店の情報の出どころです'**
  String get creditsSavedShopsNote;

  /// No description provided for @creditsLicenses.
  ///
  /// In ja, this message translates to:
  /// **'ライセンス: {licenses}'**
  String creditsLicenses(String licenses);

  /// No description provided for @creditsAppHeading.
  ///
  /// In ja, this message translates to:
  /// **'アプリで使っている部品'**
  String get creditsAppHeading;

  /// No description provided for @creditsAppLicenses.
  ///
  /// In ja, this message translates to:
  /// **'部品とフォントのライセンスを見る'**
  String get creditsAppLicenses;

  /// No description provided for @backupDescription.
  ///
  /// In ja, this message translates to:
  /// **'記録と写真を一つのファイル（zip）にまとめて書き出します。機種変更のときは、新しいスマホでこのファイルを読み込んでください。'**
  String get backupDescription;

  /// No description provided for @backupExport.
  ///
  /// In ja, this message translates to:
  /// **'書き出す'**
  String get backupExport;

  /// No description provided for @backupExportNote.
  ///
  /// In ja, this message translates to:
  /// **'書き出したファイルは、「ファイル」アプリやクラウド、メールなどに保存してください'**
  String get backupExportNote;

  /// No description provided for @backupImport.
  ///
  /// In ja, this message translates to:
  /// **'読み込む'**
  String get backupImport;

  /// No description provided for @backupImportNote.
  ///
  /// In ja, this message translates to:
  /// **'書き出したファイルを選ぶと、このスマホに無い記録だけを足します。今ある記録は消えません。ファイル名は「ramen-in-cho-（日付）.zip」です'**
  String get backupImportNote;

  /// No description provided for @backupExportFailed.
  ///
  /// In ja, this message translates to:
  /// **'書き出せませんでした。もう一度お試しください'**
  String get backupExportFailed;

  /// No description provided for @backupExportSent.
  ///
  /// In ja, this message translates to:
  /// **'保存先に送りました。ドライブなどにファイルがあるか確かめてください'**
  String get backupExportSent;

  /// No description provided for @backupImportDone.
  ///
  /// In ja, this message translates to:
  /// **'{added}件の記録を読み込みました（ファイルの記録 {total}件のうち、このスマホに無かったもの）'**
  String backupImportDone(int added, int total);

  /// No description provided for @backupImportInvalid.
  ///
  /// In ja, this message translates to:
  /// **'麺印帳のバックアップとして読めないファイルです'**
  String get backupImportInvalid;

  /// No description provided for @backupImportFailed.
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした。もう一度お試しください'**
  String get backupImportFailed;

  /// No description provided for @backupFileType.
  ///
  /// In ja, this message translates to:
  /// **'バックアップ（zip）'**
  String get backupFileType;

  /// No description provided for @statsBests.
  ///
  /// In ja, this message translates to:
  /// **'自己ベスト'**
  String get statsBests;

  /// No description provided for @bestLongestWait.
  ///
  /// In ja, this message translates to:
  /// **'着丼までがいちばん長かった一杯'**
  String get bestLongestWait;

  /// No description provided for @bestHighestPoints.
  ///
  /// In ja, this message translates to:
  /// **'一杯の最高の修行点'**
  String get bestHighestPoints;

  /// No description provided for @bestMostRetreats.
  ///
  /// In ja, this message translates to:
  /// **'いちばん手ごわい店'**
  String get bestMostRetreats;

  /// No description provided for @minutes.
  ///
  /// In ja, this message translates to:
  /// **'{minutes}分'**
  String minutes(int minutes);

  /// No description provided for @retreatCount.
  ///
  /// In ja, this message translates to:
  /// **'撤退 {count}回'**
  String retreatCount(int count);

  /// No description provided for @bestDetail.
  ///
  /// In ja, this message translates to:
  /// **'{shop}（{date}）'**
  String bestDetail(String shop, String date);

  /// No description provided for @statsShopRanks.
  ///
  /// In ja, this message translates to:
  /// **'店ランク'**
  String get statsShopRanks;

  /// No description provided for @navMap.
  ///
  /// In ja, this message translates to:
  /// **'地図'**
  String get navMap;

  /// No description provided for @mapAttribution.
  ///
  /// In ja, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get mapAttribution;

  /// No description provided for @openPoiAttribution.
  ///
  /// In ja, this message translates to:
  /// **'出典: OpenPOI API（https://openpoiapi.com/attribution.html）'**
  String get openPoiAttribution;

  /// No description provided for @mapTitle.
  ///
  /// In ja, this message translates to:
  /// **'ラーメン地図'**
  String get mapTitle;

  /// No description provided for @mapSearching.
  ///
  /// In ja, this message translates to:
  /// **'このあたりのラーメン店を探しています…'**
  String get mapSearching;

  /// No description provided for @mapLocating.
  ///
  /// In ja, this message translates to:
  /// **'現在地を確かめています…'**
  String get mapLocating;

  /// No description provided for @mapEmpty.
  ///
  /// In ja, this message translates to:
  /// **'行った店はまだ地図にありません。「このあたりのラーメン店を探す」で、まわりの店を探せます'**
  String get mapEmpty;

  /// No description provided for @mapSearchHere.
  ///
  /// In ja, this message translates to:
  /// **'このあたりのラーメン店を探す'**
  String get mapSearchHere;

  /// No description provided for @mapMyLocation.
  ///
  /// In ja, this message translates to:
  /// **'現在地'**
  String get mapMyLocation;

  /// No description provided for @mapNoLocation.
  ///
  /// In ja, this message translates to:
  /// **'現在地がわかりませんでした。位置情報をオンにしてください'**
  String get mapNoLocation;

  /// No description provided for @mapNearbyFound.
  ///
  /// In ja, this message translates to:
  /// **'まだ行っていない店が {count}軒 見つかりました'**
  String mapNearbyFound(int count);

  /// No description provided for @mapNearbyNone.
  ///
  /// In ja, this message translates to:
  /// **'このあたりに、まだ行っていないラーメン店は見つかりませんでした'**
  String get mapNearbyNone;

  /// No description provided for @mapSearchFailed.
  ///
  /// In ja, this message translates to:
  /// **'店を検索できませんでした。少し待ってから、もう一度お試しください'**
  String get mapSearchFailed;

  /// No description provided for @mapUnvisited.
  ///
  /// In ja, this message translates to:
  /// **'まだ行っていない店'**
  String get mapUnvisited;

  /// No description provided for @mapDistanceFromHere.
  ///
  /// In ja, this message translates to:
  /// **'現在地から {meters}m'**
  String mapDistanceFromHere(int meters);

  /// No description provided for @mapShopBowls.
  ///
  /// In ja, this message translates to:
  /// **'{count}杯'**
  String mapShopBowls(int count);

  /// No description provided for @mapShopRetreats.
  ///
  /// In ja, this message translates to:
  /// **'撤退 {count}回'**
  String mapShopRetreats(int count);

  /// No description provided for @mapOpenShopPage.
  ///
  /// In ja, this message translates to:
  /// **'この店のページを見る'**
  String get mapOpenShopPage;

  /// No description provided for @mapLastVisit.
  ///
  /// In ja, this message translates to:
  /// **'最後に行った日 {date}'**
  String mapLastVisit(String date);

  /// No description provided for @mapListButton.
  ///
  /// In ja, this message translates to:
  /// **'地図の店の一覧'**
  String get mapListButton;

  /// No description provided for @mapListTitle.
  ///
  /// In ja, this message translates to:
  /// **'画面に見えている店 {count}軒'**
  String mapListTitle(int count);

  /// No description provided for @mapClusterTitle.
  ///
  /// In ja, this message translates to:
  /// **'このあたりの店 {count}軒'**
  String mapClusterTitle(int count);

  /// No description provided for @mapClusterLabel.
  ///
  /// In ja, this message translates to:
  /// **'{count}軒の店。タップで寄ります'**
  String mapClusterLabel(int count);

  /// No description provided for @mapListSortHint.
  ///
  /// In ja, this message translates to:
  /// **'地図の真ん中から近い順'**
  String get mapListSortHint;

  /// No description provided for @mapListFilterAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get mapListFilterAll;

  /// No description provided for @mapListFilterVisited.
  ///
  /// In ja, this message translates to:
  /// **'行った店'**
  String get mapListFilterVisited;

  /// No description provided for @mapListFilterUnvisited.
  ///
  /// In ja, this message translates to:
  /// **'まだ'**
  String get mapListFilterUnvisited;

  /// No description provided for @mapListFilterWished.
  ///
  /// In ja, this message translates to:
  /// **'願'**
  String get mapListFilterWished;

  /// No description provided for @mapListEmpty.
  ///
  /// In ja, this message translates to:
  /// **'この中に当てはまる店はありません'**
  String get mapListEmpty;

  /// No description provided for @mapListVisited.
  ///
  /// In ja, this message translates to:
  /// **'行った店'**
  String get mapListVisited;

  /// No description provided for @mapFamous.
  ///
  /// In ja, this message translates to:
  /// **'名店'**
  String get mapFamous;

  /// No description provided for @mapListMeters.
  ///
  /// In ja, this message translates to:
  /// **'{meters}m'**
  String mapListMeters(int meters);

  /// No description provided for @mapListKilometers.
  ///
  /// In ja, this message translates to:
  /// **'{km}km'**
  String mapListKilometers(String km);

  /// No description provided for @mapShopRank.
  ///
  /// In ja, this message translates to:
  /// **'店ランク {rank}'**
  String mapShopRank(String rank);

  /// No description provided for @statsBestPoints.
  ///
  /// In ja, this message translates to:
  /// **'最高 {points}点'**
  String statsBestPoints(int points);

  /// No description provided for @shopRankS.
  ///
  /// In ja, this message translates to:
  /// **'極'**
  String get shopRankS;

  /// No description provided for @shopRankA.
  ///
  /// In ja, this message translates to:
  /// **'妙'**
  String get shopRankA;

  /// No description provided for @shopRankB.
  ///
  /// In ja, this message translates to:
  /// **'秀'**
  String get shopRankB;

  /// No description provided for @shopRankC.
  ///
  /// In ja, this message translates to:
  /// **'良'**
  String get shopRankC;

  /// No description provided for @inkanRetry.
  ///
  /// In ja, this message translates to:
  /// **'雪辱'**
  String get inkanRetry;

  /// No description provided for @inkanRetreat.
  ///
  /// In ja, this message translates to:
  /// **'敗'**
  String get inkanRetreat;

  /// No description provided for @inkanTop.
  ///
  /// In ja, this message translates to:
  /// **'{rank}　{kind}'**
  String inkanTop(String rank, String kind);

  /// No description provided for @kanjiMonthDay.
  ///
  /// In ja, this message translates to:
  /// **'{month}月{day}日'**
  String kanjiMonthDay(String month, String day);

  /// No description provided for @shopStamps.
  ///
  /// In ja, this message translates to:
  /// **'この道場の印'**
  String get shopStamps;

  /// No description provided for @recordPhotoDate.
  ///
  /// In ja, this message translates to:
  /// **'食べた日時: {date}（写真の撮影日時）'**
  String recordPhotoDate(String date);

  /// No description provided for @kanjiEraDate.
  ///
  /// In ja, this message translates to:
  /// **'{era}{year}年\n{month}月{day}日'**
  String kanjiEraDate(String era, String year, String month, String day);

  /// No description provided for @inchoMonth.
  ///
  /// In ja, this message translates to:
  /// **'{era}{eraYear}年 {month}月'**
  String inchoMonth(String era, String eraYear, String month);

  /// No description provided for @eraReiwa.
  ///
  /// In ja, this message translates to:
  /// **'令和'**
  String get eraReiwa;

  /// No description provided for @eraHeisei.
  ///
  /// In ja, this message translates to:
  /// **'平成'**
  String get eraHeisei;

  /// No description provided for @eraFirstYear.
  ///
  /// In ja, this message translates to:
  /// **'元'**
  String get eraFirstYear;

  /// No description provided for @waitMinutesLabel.
  ///
  /// In ja, this message translates to:
  /// **'着丼までの時間'**
  String get waitMinutesLabel;

  /// No description provided for @waitMinutesUnit.
  ///
  /// In ja, this message translates to:
  /// **'分'**
  String get waitMinutesUnit;

  /// No description provided for @questLocked.
  ///
  /// In ja, this message translates to:
  /// **'未'**
  String get questLocked;

  /// No description provided for @inkanNoStyle.
  ///
  /// In ja, this message translates to:
  /// **'拉麺'**
  String get inkanNoStyle;

  /// No description provided for @inkanOverseas.
  ///
  /// In ja, this message translates to:
  /// **'海外'**
  String get inkanOverseas;

  /// No description provided for @inkanStyleShoyu.
  ///
  /// In ja, this message translates to:
  /// **'醤油'**
  String get inkanStyleShoyu;

  /// No description provided for @inkanStyleMiso.
  ///
  /// In ja, this message translates to:
  /// **'味噌'**
  String get inkanStyleMiso;

  /// No description provided for @inkanStyleShio.
  ///
  /// In ja, this message translates to:
  /// **'塩'**
  String get inkanStyleShio;

  /// No description provided for @inkanStyleTonkotsu.
  ///
  /// In ja, this message translates to:
  /// **'豚骨'**
  String get inkanStyleTonkotsu;

  /// No description provided for @inkanStyleIekei.
  ///
  /// In ja, this message translates to:
  /// **'家系'**
  String get inkanStyleIekei;

  /// No description provided for @inkanStyleJiro.
  ///
  /// In ja, this message translates to:
  /// **'二郎'**
  String get inkanStyleJiro;

  /// No description provided for @inkanStyleTsukemen.
  ///
  /// In ja, this message translates to:
  /// **'つけ麺'**
  String get inkanStyleTsukemen;

  /// No description provided for @inkanStyleTsukemenKana.
  ///
  /// In ja, this message translates to:
  /// **'つけ'**
  String get inkanStyleTsukemenKana;

  /// No description provided for @inkanStyleTsukemenMain.
  ///
  /// In ja, this message translates to:
  /// **'麺'**
  String get inkanStyleTsukemenMain;

  /// No description provided for @inkanStyleShirunashi.
  ///
  /// In ja, this message translates to:
  /// **'汁無'**
  String get inkanStyleShirunashi;

  /// No description provided for @inkanStyleOther.
  ///
  /// In ja, this message translates to:
  /// **'麺'**
  String get inkanStyleOther;

  /// No description provided for @navShugyo.
  ///
  /// In ja, this message translates to:
  /// **'修行'**
  String get navShugyo;

  /// No description provided for @shugyoTitle.
  ///
  /// In ja, this message translates to:
  /// **'修行'**
  String get shugyoTitle;

  /// No description provided for @healthyLifeTitle.
  ///
  /// In ja, this message translates to:
  /// **'毎日ラーメン健康生活'**
  String get healthyLifeTitle;

  /// No description provided for @healthyLifeBest.
  ///
  /// In ja, this message translates to:
  /// **'最高 {days}日連続'**
  String healthyLifeBest(int days);

  /// No description provided for @healthyLifeRevealNote.
  ///
  /// In ja, this message translates to:
  /// **'七日続けて着丼した'**
  String get healthyLifeRevealNote;

  /// No description provided for @shugyorokuTitle.
  ///
  /// In ja, this message translates to:
  /// **'修行録'**
  String get shugyorokuTitle;

  /// No description provided for @shugyorokuOpen.
  ///
  /// In ja, this message translates to:
  /// **'これまでの一杯を、物語で読み返す'**
  String get shugyorokuOpen;

  /// No description provided for @prefectureBookTitle.
  ///
  /// In ja, this message translates to:
  /// **'都道府県の印帳'**
  String get prefectureBookTitle;

  /// No description provided for @prefectureBookOpen.
  ///
  /// In ja, this message translates to:
  /// **'四十七の印を集める'**
  String get prefectureBookOpen;

  /// No description provided for @prefectureBookProgress.
  ///
  /// In ja, this message translates to:
  /// **'{count} / 47'**
  String prefectureBookProgress(int count);

  /// No description provided for @prefectureBookNote.
  ///
  /// In ja, this message translates to:
  /// **'店の位置から都道府県を決めます。位置のわからない店は入りません'**
  String get prefectureBookNote;

  /// No description provided for @prefectureBookRegionHokkaido.
  ///
  /// In ja, this message translates to:
  /// **'北海道'**
  String get prefectureBookRegionHokkaido;

  /// No description provided for @prefectureBookRegionTohoku.
  ///
  /// In ja, this message translates to:
  /// **'東北'**
  String get prefectureBookRegionTohoku;

  /// No description provided for @prefectureBookRegionKanto.
  ///
  /// In ja, this message translates to:
  /// **'関東'**
  String get prefectureBookRegionKanto;

  /// No description provided for @prefectureBookRegionKoshinetsu.
  ///
  /// In ja, this message translates to:
  /// **'甲信越'**
  String get prefectureBookRegionKoshinetsu;

  /// No description provided for @prefectureBookRegionHokuriku.
  ///
  /// In ja, this message translates to:
  /// **'北陸'**
  String get prefectureBookRegionHokuriku;

  /// No description provided for @prefectureBookRegionTokai.
  ///
  /// In ja, this message translates to:
  /// **'東海'**
  String get prefectureBookRegionTokai;

  /// No description provided for @prefectureBookRegionKinki.
  ///
  /// In ja, this message translates to:
  /// **'近畿'**
  String get prefectureBookRegionKinki;

  /// No description provided for @prefectureBookRegionChugoku.
  ///
  /// In ja, this message translates to:
  /// **'中国'**
  String get prefectureBookRegionChugoku;

  /// No description provided for @prefectureBookRegionShikoku.
  ///
  /// In ja, this message translates to:
  /// **'四国'**
  String get prefectureBookRegionShikoku;

  /// No description provided for @prefectureBookRegionKyushu.
  ///
  /// In ja, this message translates to:
  /// **'九州'**
  String get prefectureBookRegionKyushu;

  /// No description provided for @prefectureBookRegionOkinawa.
  ///
  /// In ja, this message translates to:
  /// **'沖縄'**
  String get prefectureBookRegionOkinawa;

  /// No description provided for @prefectureBookOverseas.
  ///
  /// In ja, this message translates to:
  /// **'海外'**
  String get prefectureBookOverseas;

  /// No description provided for @prefectureBookFirst.
  ///
  /// In ja, this message translates to:
  /// **'初 {date}'**
  String prefectureBookFirst(String date);

  /// No description provided for @prefectureBookBowls.
  ///
  /// In ja, this message translates to:
  /// **'{count}杯'**
  String prefectureBookBowls(int count);

  /// No description provided for @prefectureBookEntry.
  ///
  /// In ja, this message translates to:
  /// **'{date}　{shop}'**
  String prefectureBookEntry(String date, String shop);

  /// No description provided for @shugyorokuEmpty.
  ///
  /// In ja, this message translates to:
  /// **'最初の一杯から、修行録が始まります'**
  String get shugyorokuEmpty;

  /// No description provided for @shugyorokuChapter.
  ///
  /// In ja, this message translates to:
  /// **'{year}年 {month}月'**
  String shugyorokuChapter(int year, int month);

  /// No description provided for @shugyorokuEntryTitle.
  ///
  /// In ja, this message translates to:
  /// **'{month}月{day}日　{shop}'**
  String shugyorokuEntryTitle(int month, int day, String shop);

  /// No description provided for @settingsSection.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsSection;

  /// No description provided for @moreActions.
  ///
  /// In ja, this message translates to:
  /// **'そのほか'**
  String get moreActions;

  /// No description provided for @statsBowls.
  ///
  /// In ja, this message translates to:
  /// **'杯数'**
  String get statsBowls;

  /// No description provided for @statsBowlsLine.
  ///
  /// In ja, this message translates to:
  /// **'今年 {thisYear}杯　通算 {total}杯'**
  String statsBowlsLine(int thisYear, int total);

  /// No description provided for @wishTriggerRetreat.
  ///
  /// In ja, this message translates to:
  /// **'撤退した店'**
  String get wishTriggerRetreat;

  /// No description provided for @questSpotNone.
  ///
  /// In ja, this message translates to:
  /// **'まだ会得した秘伝はありません'**
  String get questSpotNone;

  /// No description provided for @reviewListTitle.
  ///
  /// In ja, this message translates to:
  /// **'年の振り返り'**
  String get reviewListTitle;

  /// No description provided for @reviewEntry.
  ///
  /// In ja, this message translates to:
  /// **'{year}年の振り返り'**
  String reviewEntry(int year);

  /// No description provided for @reviewInvite.
  ///
  /// In ja, this message translates to:
  /// **'{year}年の修行を振り返りませんか'**
  String reviewInvite(int year);

  /// No description provided for @reviewInviteSub.
  ///
  /// In ja, this message translates to:
  /// **'この一年の杯数・最高の一杯・会得した型をめくって見られます'**
  String get reviewInviteSub;

  /// No description provided for @reviewDismiss.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get reviewDismiss;

  /// No description provided for @reviewCoverEra.
  ///
  /// In ja, this message translates to:
  /// **'{era}{eraYear}年の修行'**
  String reviewCoverEra(String era, String eraYear);

  /// No description provided for @reviewCoverYear.
  ///
  /// In ja, this message translates to:
  /// **'{year}年'**
  String reviewCoverYear(int year);

  /// No description provided for @reviewCoverHint.
  ///
  /// In ja, this message translates to:
  /// **'左へめくって、一年を振り返る'**
  String get reviewCoverHint;

  /// No description provided for @reviewCoverEmpty.
  ///
  /// In ja, this message translates to:
  /// **'この年の記録はありません'**
  String get reviewCoverEmpty;

  /// No description provided for @reviewCountsTitle.
  ///
  /// In ja, this message translates to:
  /// **'この一年で'**
  String get reviewCountsTitle;

  /// No description provided for @reviewBowls.
  ///
  /// In ja, this message translates to:
  /// **'食べた杯数'**
  String get reviewBowls;

  /// No description provided for @reviewShops.
  ///
  /// In ja, this message translates to:
  /// **'訪ねた店'**
  String get reviewShops;

  /// No description provided for @reviewShopCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}軒'**
  String reviewShopCount(int count);

  /// No description provided for @reviewRetreats.
  ///
  /// In ja, this message translates to:
  /// **'撤退'**
  String get reviewRetreats;

  /// No description provided for @reviewRetreatCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}回'**
  String reviewRetreatCount(int count);

  /// No description provided for @reviewPoints.
  ///
  /// In ja, this message translates to:
  /// **'得た修行点'**
  String get reviewPoints;

  /// No description provided for @reviewFavoriteTitle.
  ///
  /// In ja, this message translates to:
  /// **'いちばん通った店'**
  String get reviewFavoriteTitle;

  /// No description provided for @reviewFavoriteLine.
  ///
  /// In ja, this message translates to:
  /// **'この一年で {count}杯'**
  String reviewFavoriteLine(int count);

  /// No description provided for @reviewBestTitle.
  ///
  /// In ja, this message translates to:
  /// **'最高の一杯'**
  String get reviewBestTitle;

  /// No description provided for @reviewWaitTitle.
  ///
  /// In ja, this message translates to:
  /// **'着丼までがいちばん長かった一杯'**
  String get reviewWaitTitle;

  /// No description provided for @reviewMonthlyTitle.
  ///
  /// In ja, this message translates to:
  /// **'月ごとの杯数'**
  String get reviewMonthlyTitle;

  /// No description provided for @reviewMonth.
  ///
  /// In ja, this message translates to:
  /// **'{month}月'**
  String reviewMonth(int month);

  /// No description provided for @reviewMonthBowls.
  ///
  /// In ja, this message translates to:
  /// **'{month}月 {count}杯'**
  String reviewMonthBowls(int month, int count);

  /// No description provided for @reviewAchievementsTitle.
  ///
  /// In ja, this message translates to:
  /// **'この一年の成果'**
  String get reviewAchievementsTitle;

  /// No description provided for @reviewRanks.
  ///
  /// In ja, this message translates to:
  /// **'上がった段位'**
  String get reviewRanks;

  /// No description provided for @reviewQuests.
  ///
  /// In ja, this message translates to:
  /// **'会得した型と秘伝'**
  String get reviewQuests;

  /// No description provided for @reviewWishes.
  ///
  /// In ja, this message translates to:
  /// **'叶った願'**
  String get reviewWishes;

  /// No description provided for @reviewWishCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}軒'**
  String reviewWishCount(int count);

  /// No description provided for @reviewExpeditions.
  ///
  /// In ja, this message translates to:
  /// **'遠征'**
  String get reviewExpeditions;

  /// No description provided for @reviewExpeditionCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}回'**
  String reviewExpeditionCount(int count);

  /// No description provided for @reviewClosingTitle.
  ///
  /// In ja, this message translates to:
  /// **'締めのひとこと'**
  String get reviewClosingTitle;

  /// No description provided for @reviewSummaryLine.
  ///
  /// In ja, this message translates to:
  /// **'{bowls}杯・{shops}軒・{points}点'**
  String reviewSummaryLine(int bowls, int shops, int points);

  /// No description provided for @questSpotAchievedShop.
  ///
  /// In ja, this message translates to:
  /// **'{shop}にて会得'**
  String questSpotAchievedShop(String shop);

  /// No description provided for @questSpotOpenShop.
  ///
  /// In ja, this message translates to:
  /// **'その一杯を見る'**
  String get questSpotOpenShop;

  /// No description provided for @questSpotAchievedHomeBase.
  ///
  /// In ja, this message translates to:
  /// **'{name}に拠点を構えて会得'**
  String questSpotAchievedHomeBase(String name);

  /// No description provided for @onboardingClose.
  ///
  /// In ja, this message translates to:
  /// **'案内を閉じる'**
  String get onboardingClose;

  /// No description provided for @onboardingLater.
  ///
  /// In ja, this message translates to:
  /// **'また今度'**
  String get onboardingLater;

  /// No description provided for @onboardingNext.
  ///
  /// In ja, this message translates to:
  /// **'先へ進む'**
  String get onboardingNext;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In ja, this message translates to:
  /// **'門を叩く'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In ja, this message translates to:
  /// **'麺印帳は、麺の道を歩む者のための修行の帳面である。\n食べた一杯ごとに印を授かり、並んだ時間も、遠い店への道のりも、すべて修行点として刻まれていく。\n\n始め方は三つある。'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingWelcomeRecord.
  ///
  /// In ja, this message translates to:
  /// **'写真から一杯を刻む'**
  String get onboardingWelcomeRecord;

  /// No description provided for @onboardingWelcomeQueue.
  ///
  /// In ja, this message translates to:
  /// **'いま行列に並んでいる'**
  String get onboardingWelcomeQueue;

  /// No description provided for @onboardingWelcomeBackup.
  ///
  /// In ja, this message translates to:
  /// **'前の帳面を引き継ぐ（バックアップ）'**
  String get onboardingWelcomeBackup;

  /// No description provided for @onboardingRecordTitle.
  ///
  /// In ja, this message translates to:
  /// **'最初の一杯を刻む'**
  String get onboardingRecordTitle;

  /// No description provided for @onboardingRecordBody.
  ///
  /// In ja, this message translates to:
  /// **'撮りためた一杯の写真が一枚あれば足りる。撮影した日時と場所から、店の候補を探し出す。\n\n次の画面で「ギャラリーから選ぶ」を押し、店を選んで「着丼！」を押す。これで一杯目が刻まれる。'**
  String get onboardingRecordBody;

  /// No description provided for @onboardingRecordButton.
  ///
  /// In ja, this message translates to:
  /// **'写真を選んで刻む'**
  String get onboardingRecordButton;

  /// No description provided for @onboardingShareTitle.
  ///
  /// In ja, this message translates to:
  /// **'一杯目の印'**
  String get onboardingShareTitle;

  /// No description provided for @onboardingShareBody.
  ///
  /// In ja, this message translates to:
  /// **'刻んだ一杯は、このような印となって帳面に並ぶ。長く並び、遠くまで足を運び、通い詰めた一杯ほど、修行点は高くなり、印は格を増していく。\n\n写真と印と店の名を一枚の絵にまとめ、同じ道を行く者に見せることもできる。'**
  String get onboardingShareBody;

  /// No description provided for @onboardingShareButton.
  ///
  /// In ja, this message translates to:
  /// **'絵にして分かち合う'**
  String get onboardingShareButton;

  /// No description provided for @onboardingWishTitle.
  ///
  /// In ja, this message translates to:
  /// **'次なる一杯に願を掛ける'**
  String get onboardingWishTitle;

  /// No description provided for @onboardingWishBody.
  ///
  /// In ja, this message translates to:
  /// **'行きたい店を願掛け帳に記しておけば、その店で食べた日に願が成就する。\n\n地図の右下の「探す」を押すと、近くのまだ訪れていない店が灰色の印で現れる。気になる店に触れ、「願を掛ける」を押す。'**
  String get onboardingWishBody;

  /// No description provided for @onboardingWishNotYet.
  ///
  /// In ja, this message translates to:
  /// **'まだ願は掛かっていない。店の名からも掛けられる。'**
  String get onboardingWishNotYet;

  /// No description provided for @onboardingWishMap.
  ///
  /// In ja, this message translates to:
  /// **'地図で近くの店を探す'**
  String get onboardingWishMap;

  /// No description provided for @onboardingWishByName.
  ///
  /// In ja, this message translates to:
  /// **'店の名で願を掛ける'**
  String get onboardingWishByName;

  /// No description provided for @onboardingFinishTitle.
  ///
  /// In ja, this message translates to:
  /// **'あとは精進あるのみ'**
  String get onboardingFinishTitle;

  /// No description provided for @onboardingFinishBody.
  ///
  /// In ja, this message translates to:
  /// **'「修行」では、段位、型と秘伝、修行録、一年の振り返りを見ることができる。\n\n一杯ごとに印は増え、段位は上がっていく。\nいざ、麺の道へ。'**
  String get onboardingFinishBody;

  /// No description provided for @onboardingFinishShugyo.
  ///
  /// In ja, this message translates to:
  /// **'修行の間をのぞく'**
  String get onboardingFinishShugyo;

  /// No description provided for @onboardingFinishRecords.
  ///
  /// In ja, this message translates to:
  /// **'印帳を開く'**
  String get onboardingFinishRecords;

  /// No description provided for @onboardingReplay.
  ///
  /// In ja, this message translates to:
  /// **'使い方をもう一度見る'**
  String get onboardingReplay;

  /// No description provided for @onboardingScroll.
  ///
  /// In ja, this message translates to:
  /// **'入門の心得'**
  String get onboardingScroll;

  /// No description provided for @onboardingWelcomeChapter.
  ///
  /// In ja, this message translates to:
  /// **'其の一　入門'**
  String get onboardingWelcomeChapter;

  /// No description provided for @onboardingRecordChapter.
  ///
  /// In ja, this message translates to:
  /// **'其の二　初陣'**
  String get onboardingRecordChapter;

  /// No description provided for @onboardingShareChapter.
  ///
  /// In ja, this message translates to:
  /// **'其の三　授印'**
  String get onboardingShareChapter;

  /// No description provided for @onboardingWishChapter.
  ///
  /// In ja, this message translates to:
  /// **'其の四　願掛'**
  String get onboardingWishChapter;

  /// No description provided for @onboardingHomeBaseChapter.
  ///
  /// In ja, this message translates to:
  /// **'其の五　拠点'**
  String get onboardingHomeBaseChapter;

  /// No description provided for @onboardingHomeBaseTitle.
  ///
  /// In ja, this message translates to:
  /// **'拠点を構える'**
  String get onboardingHomeBaseTitle;

  /// No description provided for @onboardingHomeBaseBody.
  ///
  /// In ja, this message translates to:
  /// **'ふだん暮らす駅や街を、修行の拠点と定める。\n\n拠点から80km以上離れた店で食べた一杯は「遠征」となり、修行点が上乗せされる。拠点はあとから設定で変えられ、変えた日から後の一杯にだけ効く。'**
  String get onboardingHomeBaseBody;

  /// No description provided for @onboardingHomeBaseButton.
  ///
  /// In ja, this message translates to:
  /// **'拠点を決める'**
  String get onboardingHomeBaseButton;

  /// No description provided for @onboardingHomeBaseLater.
  ///
  /// In ja, this message translates to:
  /// **'あとで決める'**
  String get onboardingHomeBaseLater;

  /// No description provided for @onboardingFinishChapter.
  ///
  /// In ja, this message translates to:
  /// **'其の六　精進'**
  String get onboardingFinishChapter;

  /// No description provided for @locationBlockedTitle.
  ///
  /// In ja, this message translates to:
  /// **'現在地が使えません'**
  String get locationBlockedTitle;

  /// No description provided for @locationDeniedForeverBody.
  ///
  /// In ja, this message translates to:
  /// **'麺印帳に位置情報の利用が許可されていません。スマホの設定で、麺印帳の位置情報を「アプリの使用中のみ許可」にしてください。'**
  String get locationDeniedForeverBody;

  /// No description provided for @locationServiceOffBody.
  ///
  /// In ja, this message translates to:
  /// **'スマホの位置情報がオフになっています。設定で位置情報をオンにしてください。'**
  String get locationServiceOffBody;

  /// No description provided for @locationOpenSettings.
  ///
  /// In ja, this message translates to:
  /// **'設定を開く'**
  String get locationOpenSettings;

  /// No description provided for @notificationSettings.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get notificationSettings;

  /// No description provided for @notificationSettingsNote.
  ///
  /// In ja, this message translates to:
  /// **'どんなときに知らせるかを選べます'**
  String get notificationSettingsNote;

  /// No description provided for @notificationNotPermitted.
  ///
  /// In ja, this message translates to:
  /// **'通知が許可されていません'**
  String get notificationNotPermitted;

  /// No description provided for @notificationNotPermittedNote.
  ///
  /// In ja, this message translates to:
  /// **'タップして、スマホの設定で麺印帳の通知を許可してください'**
  String get notificationNotPermittedNote;

  /// No description provided for @notificationKindCheckin.
  ///
  /// In ja, this message translates to:
  /// **'並び中'**
  String get notificationKindCheckin;

  /// No description provided for @notificationKindCheckinNote.
  ///
  /// In ja, this message translates to:
  /// **'並んでいる時間をリアルタイムで表示します'**
  String get notificationKindCheckinNote;

  /// No description provided for @notificationKindStreak.
  ///
  /// In ja, this message translates to:
  /// **'連続記録'**
  String get notificationKindStreak;

  /// No description provided for @notificationKindStreakNote.
  ///
  /// In ja, this message translates to:
  /// **'連続記録が途切れそうなときにお知らせします'**
  String get notificationKindStreakNote;

  /// No description provided for @notificationKindRating.
  ///
  /// In ja, this message translates to:
  /// **'★の付け忘れ'**
  String get notificationKindRating;

  /// No description provided for @notificationKindMonthly.
  ///
  /// In ja, this message translates to:
  /// **'今月の一杯'**
  String get notificationKindMonthly;

  /// No description provided for @notificationKindMonthlyNote.
  ///
  /// In ja, this message translates to:
  /// **'ラーメンを食べ忘れていないかお知らせします'**
  String get notificationKindMonthlyNote;

  /// No description provided for @notificationKindSeasonal.
  ///
  /// In ja, this message translates to:
  /// **'季節のお知らせ'**
  String get notificationKindSeasonal;

  /// No description provided for @notificationKindSeasonalNote.
  ///
  /// In ja, this message translates to:
  /// **'年の瀬・年始・行事の日にお知らせします'**
  String get notificationKindSeasonalNote;

  /// No description provided for @ratingReminderTitle.
  ///
  /// In ja, this message translates to:
  /// **'{shop}はどうでしたか？'**
  String ratingReminderTitle(String shop);

  /// No description provided for @yearReviewReminderTitle.
  ///
  /// In ja, this message translates to:
  /// **'{year}年の振り返り'**
  String yearReviewReminderTitle(int year);

  /// No description provided for @newYearWishReminderTitle.
  ///
  /// In ja, this message translates to:
  /// **'年始の願掛け'**
  String get newYearWishReminderTitle;

  /// No description provided for @monthlyReminderTitle.
  ///
  /// In ja, this message translates to:
  /// **'{month}月の一杯'**
  String monthlyReminderTitle(int month);

  /// No description provided for @eventReminderTitle.
  ///
  /// In ja, this message translates to:
  /// **'{event, select, valentine{バレンタインデー} whiteDay{ホワイトデー} tanabata{七夕} ramenDay{ラーメンの日} halloween{ハロウィン} christmas{クリスマス} newYearsEve{大晦日} other{今日の一杯}}'**
  String eventReminderTitle(String event);

  /// No description provided for @notificationDebugTitle.
  ///
  /// In ja, this message translates to:
  /// **'（開発用）予約中の通知'**
  String get notificationDebugTitle;

  /// No description provided for @notificationDebugNote.
  ///
  /// In ja, this message translates to:
  /// **'タップすると、その通知が5秒後に届きます'**
  String get notificationDebugNote;

  /// No description provided for @notificationStreakTime.
  ///
  /// In ja, this message translates to:
  /// **'連続記録を知らせる曜日と時刻'**
  String get notificationStreakTime;

  /// No description provided for @notificationStreakTimeValue.
  ///
  /// In ja, this message translates to:
  /// **'{weekday}曜日 {time}'**
  String notificationStreakTimeValue(String weekday, String time);

  /// No description provided for @weekdayShort.
  ///
  /// In ja, this message translates to:
  /// **'{weekday, select, 1{月} 2{火} 3{水} 4{木} 5{金} 6{土} other{日}}'**
  String weekdayShort(String weekday);

  /// No description provided for @notificationQuietNight.
  ///
  /// In ja, this message translates to:
  /// **'夜（22時〜8時）は知らせない'**
  String get notificationQuietNight;

  /// No description provided for @notificationQuietNightNote.
  ///
  /// In ja, this message translates to:
  /// **'夜にかかる知らせは、その日の21時か朝8時に動かします'**
  String get notificationQuietNightNote;

  /// No description provided for @notificationOsSettings.
  ///
  /// In ja, this message translates to:
  /// **'スマホの通知の設定'**
  String get notificationOsSettings;

  /// No description provided for @notificationOsSettingsNote.
  ///
  /// In ja, this message translates to:
  /// **'スマホの設定で、麺印帳の通知を切り替えます'**
  String get notificationOsSettingsNote;

  /// No description provided for @notificationOsSettingsKindsNote.
  ///
  /// In ja, this message translates to:
  /// **'通知の種類ごとのオン・オフは、ここで切り替えます'**
  String get notificationOsSettingsKindsNote;

  /// No description provided for @nameSearchPickOnMap.
  ///
  /// In ja, this message translates to:
  /// **'見つからないときは、地図で場所を指す'**
  String get nameSearchPickOnMap;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
