import '../records/models.dart';
import '../records/wait_time.dart';
import '../shop_search/geo.dart';
import '../shop_search/shop_candidate.dart';
import '../shop_search/shop_search_service.dart';

enum ShopSearchStatus { idle, searching, done }

const _unset = Object();

class RecordState {
  const RecordState({
    this.photoPath,
    this.photoTakenAt,
    this.photoQuarterTurns = 0,
    this.photoFromCamera = false,
    this.photoDateFromPhoto = false,
    this.photoLocation,
    this.pinnedLocation,
    this.searchStatus = ShopSearchStatus.idle,
    this.searchFailure,
    this.candidates = const [],
    this.nameMatches = const [],
    this.checkin,
    this.checkinShop,
    this.selectedShop,
    this.manualName = '',
    this.rating,
    this.style,
    this.isLimited = false,
    this.memo = '',
    this.shopMemo = '',
    this.shopMemoOriginal = '',
    this.shopFamous = false,
    this.shopFamousOriginal = false,
    this.manualWaitMinutes,
    this.arrivedAt,
    this.chosenEatenAt,
    this.isSaving = false,
    this.resumedFromDraft = false,
  });

  /// 写真のパス。ふつうは下書き用のフォルダに写したもの（record_draft.dart）。
  final String? photoPath;
  final DateTime? photoTakenAt;

  /// 「写真を回す」で回した回数（時計回りに90度ずつ、0〜3）。ファイルは保存のときに回す。
  final int photoQuarterTurns;
  final bool photoFromCamera;

  /// [photoTakenAt]が写真に記録された撮影日時か（過去の写真から記録するとき）。
  final bool photoDateFromPhoto;

  /// 写真に記録された撮影場所。あれば、現在地ではなくここで店を探す。
  final GeoPoint? photoLocation;

  /// 手入力の店の場所として地図で指した場所。撮影場所や現在地より優先する。
  final GeoPoint? pinnedLocation;

  final ShopSearchStatus searchStatus;
  final ShopSearchFailure? searchFailure;
  final List<ShopCandidate> candidates;

  /// 手入力中の店名に合う、記録済みの店。
  final List<ShopCandidate> nameMatches;

  /// 並んでいる最中のチェックインと、その店。
  final Checkin? checkin;
  final ShopCandidate? checkinShop;
  final ShopCandidate? selectedShop;
  final String manualName;
  final int? rating;
  final RamenStyle? style;
  final bool isLimited;
  final String memo;

  /// 店の覚え書きの入力欄。店を選ぶたびに、その店の覚え書きに入れ替わる。
  final String shopMemo;

  /// [shopMemo]に入れた、選んだ店のもとの覚え書き。書き換えたときだけ店に保存する。
  final String shopMemoOriginal;

  bool get shopMemoEdited => shopMemo.trim() != shopMemoOriginal.trim();

  /// 名店の印。覚え書きと同じく、店を選ぶたびにその店の印に入れ替わり、変えたときだけ店に保存する。
  final bool shopFamous;
  final bool shopFamousOriginal;

  bool get shopFamousEdited => shopFamous != shopFamousOriginal;

  /// あとから入れた待ち時間（分）。並んだ店を選んでいるときは使わない。
  final int? manualWaitMinutes;

  /// 並んでいる最中に真ん中の「着」を押した時刻。並んだ店で食べた時刻になり、待ち時間はここで決まる。
  final DateTime? arrivedAt;

  /// 記録画面で直した、食べた日時。写真の撮影日時や「着」の時刻より優先する。
  final DateTime? chosenEatenAt;
  final bool isSaving;

  /// 前に保存せずに閉じたときの入力から再開したか。
  final bool resumedFromDraft;

  /// 並んでいる店を選んでいるか。このときだけ待ち時間を記録する。
  bool get isCheckinShopSelected {
    final selected = selectedShop;
    final checkedIn = checkinShop;
    return selected != null &&
        checkedIn != null &&
        isSameShop(selected, checkedIn);
  }

  /// 保存したときの食べた日時と並んだ時刻（並んだ店を選んでいるときだけ）。
  ({DateTime eatenAt, DateTime? checkedInAt}) timesAt(DateTime now) {
    final atCheckinShop = isCheckinShopSelected;
    return recordTimes(
      now: now,
      photoTakenAt: photoTakenAt,
      arrivedAt: atCheckinShop ? arrivedAt : null,
      checkedInAt: atCheckinShop ? checkin?.checkedInAt : null,
      chosenEatenAt: chosenEatenAt,
    );
  }

  bool get hasShop => selectedShop != null || manualName.trim().isNotEmpty;

  bool get hasInput =>
      photoPath != null ||
      rating != null ||
      manualName.trim().isNotEmpty ||
      (selectedShop != null && !identical(selectedShop, checkinShop));

  /// ★は食べ終わってから付けることが多いため、店さえ決まれば保存できる。
  bool get canSave => hasShop && !isSaving;

  RecordState copyWith({
    Object? photoPath = _unset,
    Object? photoTakenAt = _unset,
    int? photoQuarterTurns,
    bool? photoFromCamera,
    bool? photoDateFromPhoto,
    Object? photoLocation = _unset,
    Object? pinnedLocation = _unset,
    ShopSearchStatus? searchStatus,
    Object? searchFailure = _unset,
    List<ShopCandidate>? candidates,
    List<ShopCandidate>? nameMatches,
    Checkin? checkin,
    ShopCandidate? checkinShop,
    Object? selectedShop = _unset,
    String? manualName,
    Object? rating = _unset,
    Object? style = _unset,
    bool? isLimited,
    String? memo,
    String? shopMemo,
    String? shopMemoOriginal,
    bool? shopFamous,
    bool? shopFamousOriginal,
    Object? manualWaitMinutes = _unset,
    Object? arrivedAt = _unset,
    Object? chosenEatenAt = _unset,
    bool? isSaving,
    bool? resumedFromDraft,
  }) {
    return RecordState(
      photoPath: photoPath == _unset ? this.photoPath : photoPath as String?,
      photoTakenAt: photoTakenAt == _unset
          ? this.photoTakenAt
          : photoTakenAt as DateTime?,
      photoQuarterTurns: photoQuarterTurns ?? this.photoQuarterTurns,
      photoFromCamera: photoFromCamera ?? this.photoFromCamera,
      photoDateFromPhoto: photoDateFromPhoto ?? this.photoDateFromPhoto,
      photoLocation: photoLocation == _unset
          ? this.photoLocation
          : photoLocation as GeoPoint?,
      pinnedLocation: pinnedLocation == _unset
          ? this.pinnedLocation
          : pinnedLocation as GeoPoint?,
      searchStatus: searchStatus ?? this.searchStatus,
      searchFailure: searchFailure == _unset
          ? this.searchFailure
          : searchFailure as ShopSearchFailure?,
      candidates: candidates ?? this.candidates,
      nameMatches: nameMatches ?? this.nameMatches,
      checkin: checkin ?? this.checkin,
      checkinShop: checkinShop ?? this.checkinShop,
      selectedShop: selectedShop == _unset
          ? this.selectedShop
          : selectedShop as ShopCandidate?,
      manualName: manualName ?? this.manualName,
      rating: rating == _unset ? this.rating : rating as int?,
      style: style == _unset ? this.style : style as RamenStyle?,
      isLimited: isLimited ?? this.isLimited,
      memo: memo ?? this.memo,
      shopMemo: shopMemo ?? this.shopMemo,
      shopMemoOriginal: shopMemoOriginal ?? this.shopMemoOriginal,
      shopFamous: shopFamous ?? this.shopFamous,
      shopFamousOriginal: shopFamousOriginal ?? this.shopFamousOriginal,
      manualWaitMinutes: manualWaitMinutes == _unset
          ? this.manualWaitMinutes
          : manualWaitMinutes as int?,
      arrivedAt: arrivedAt == _unset ? this.arrivedAt : arrivedAt as DateTime?,
      chosenEatenAt: chosenEatenAt == _unset
          ? this.chosenEatenAt
          : chosenEatenAt as DateTime?,
      isSaving: isSaving ?? this.isSaving,
      resumedFromDraft: resumedFromDraft ?? this.resumedFromDraft,
    );
  }
}
