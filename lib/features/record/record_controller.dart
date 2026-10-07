import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';
import '../checkin/checkin_rules.dart';
import '../error_reporting/error_reporting.dart';
import '../records/clock.dart';
import '../records/models.dart';
import '../records/photo_rotation.dart';
import '../records/photo_storage.dart';
import '../records/record_repository.dart';
import '../shop_search/found_shop.dart';
import '../shop_search/geo.dart';
import '../shop_search/location_service.dart';
import '../shop_search/ramen_in_cho_api.dart';
import '../shop_search/shop_candidate.dart';
import '../shop_search/shop_search_service.dart';
import '../wishes/shared_wish.dart';
import '../wishes/wish_repository.dart';
import '../wishes/wishes.dart';
import 'photo_metadata.dart';
import 'photo_picker.dart';
import 'record_draft.dart';
import 'record_state.dart';

final recordControllerProvider =
    NotifierProvider.autoDispose<RecordController, RecordState>(
      RecordController.new,
    );

class RecordController extends Notifier<RecordState> {
  List<Shop> _knownShops = const [];
  List<Wish> _pendingWishes = const [];
  Future<void>? _knownShopsLoad;
  GeoPoint? _here;

  /// 店を探さずに取った現在地。店名で探すときの基準にだけ使う。
  GeoPoint? _quietHere;
  int _searchGeneration = 0;

  /// 下書きを読み終えるまでは書かない（空の入力で下書きを消してしまうため）。
  bool _draftReady = false;

  /// 記録できたあとは下書きに書かない。
  bool _draftClosed = false;
  String? _lastDraftJson;

  /// 下書きから戻した店。検索の候補に同じ店があれば、候補の方に選び替える。
  ShopCandidate? _restoredShop;

  /// 下書きから戻した写真を撮り直したら、前に開いたときの時刻ではなく今の時刻にする。
  bool _photoFromDraft = false;

  /// 開いたときに渡された写真（取り戻した写真・共有された写真）を写した先。
  String? _incomingPhoto;

  /// 保存先にある並び。下書きから戻した並びとは区別する（下書きを捨てたら、こちらに戻す）。
  Checkin? _activeCheckin;

  /// この画面を開くときに「着」を押した時刻。
  DateTime? _tappedArrivedAt;

  /// 統計に送る、記録を始めたきっかけと時刻。
  RecordEntry _entry = RecordEntry.plain;
  DateTime? _startedAt;
  bool _sharedPhoto = false;

  /// 選んでいる店を「店名から探す」で見つけたか。
  bool _pickedByNameSearch = false;

  /// 保存できた記録の入力の様子（統計に送る）。
  RecordSaveSummary? lastSaveSummary;

  @override
  RecordState build() {
    listenSelf((_, next) => _writeDraft(next));
    return const RecordState();
  }

  RecordDraftStore get _draftStore => ref.read(recordDraftStoreProvider);

  void _writeDraft(RecordState next) {
    if (!_draftReady || _draftClosed) return;
    final draft = RecordDraft.fromState(next);
    final json = draft.isEmpty ? '' : jsonEncode(draft.toJson());
    if (json == _lastDraftJson) return;
    _lastDraftJson = json;
    _draftStore.save(draft).catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'Draft save failed');
    });
  }

  /// 保存せずに閉じた入力が残っているか。
  Future<bool> hasDraft() async {
    try {
      final draft = await _draftStore.load();
      return draft != null && !draft.isEmpty;
    } catch (e) {
      debugPrint('Draft load failed: $e');
      return false;
    }
  }

  /// 「着」を押してカメラを開いたまま、写真がまだ入っていない下書きか
  /// （カメラの最中にアプリが終わらされ、写真を取り戻したときはこの下書きの続きにする）。
  Future<bool> draftAwaitsArrivalPhoto() async {
    try {
      final draft = await _draftStore.load();
      return draft != null &&
          draft.arrivedAt != null &&
          draft.photoPath == null;
    } catch (e) {
      debugPrint('Draft load failed: $e');
      return false;
    }
  }

  /// 記録を始める。近くの店は写真を選んでから探す。カメラは「着」から開いたときだけ自動で開く。
  /// 保存せずに閉じた入力があれば、そこから再開する（[startOver]なら捨てて新しく始める）。
  /// [sharedPhoto]は、[recoveredPhotoPath]がほかのアプリから共有された写真のとき。
  /// [arrivedAt]は、並んでいる最中に「着」を押した時刻。並んだ店を選び、すぐにカメラを開く。
  Future<void> start({
    String? recoveredPhotoPath,
    bool sharedPhoto = false,
    bool startOver = false,
    DateTime? arrivedAt,
    SharedWish? sharedPlace,
  }) async {
    _tappedArrivedAt = arrivedAt;
    _startedAt = ref.read(clockProvider)();
    _sharedPhoto = sharedPhoto;
    _entry = arrivedAt != null
        ? RecordEntry.arrival
        : sharedPlace != null
        ? RecordEntry.shareMap
        : recoveredPhotoPath != null
        ? (sharedPhoto ? RecordEntry.sharePhoto : RecordEntry.recovered)
        : RecordEntry.plain;
    _knownShopsLoad = _loadKnownShops();
    await _loadCheckin();
    if (!ref.mounted) return;
    if (startOver) {
      await _clearDraftStore();
    } else {
      await _restoreDraft();
    }
    if (!ref.mounted) return;
    final analytics = ref.read(analyticsProvider);
    unawaited(
      analytics.log(
        AnalyticsEvents.recordStarted(
          entry: _entry,
          resumedDraft: state.resumedFromDraft,
        ),
      ),
    );
    // 下書きに前の「着」が残っていれば、そちらの時刻を使う（そのときに着丼していたため）。
    final arrives =
        arrivedAt != null && state.checkin != null && state.arrivedAt == null;
    // 「着」を押したら、下書きで直した日時よりその時刻を使う。
    if (arrives) {
      state = state.copyWith(arrivedAt: arrivedAt, chosenEatenAt: null);
    }
    _draftReady = true;
    // カメラの最中にアプリが終わらされても「着」の時刻が残るよう、先に下書きへ書く。
    if (arrives) {
      final draft = RecordDraft.fromState(state);
      _lastDraftJson = jsonEncode(draft.toJson());
      try {
        await _draftStore.save(draft);
      } catch (e, st) {
        reportError(e, st, reason: 'Draft save failed');
      }
      if (!ref.mounted) return;
    }
    if (arrivedAt != null && state.photoPath == null) unawaited(takePhoto());
    // 下書きの続きにするとき、共有された写真は元のアプリに残っているので、下書きの写真を優先する。
    // 取り戻した写真は、この下書きを書いている途中に撮った写真（ほかに控えが無い）なので入れ替える。
    final keepDraftPhoto = sharedPhoto && state.photoPath != null;
    if (recoveredPhotoPath != null && !keepDraftPhoto) {
      // 取り戻した写真はカメラとギャラリーのどちらのものか区別できない。
      await _setGalleryPhoto(recoveredPhotoPath, incoming: true);
      if (!ref.mounted) return;
    }
    if (sharedPlace != null) {
      await _useSharedPlace(sharedPlace);
      if (!ref.mounted) return;
    }
    // 開いただけでは探さない。下書きの写真に店が決まっていなければ、その写真で探し直す。

    if (state.photoPath != null &&
        state.selectedShop == null &&
        state.searchStatus == ShopSearchStatus.idle) {
      await searchShops(requestPermission: state.photoLocation == null);
    } else {
      unawaited(_loadQuietHere());
    }
  }

  /// 下書きで店が決まっているか。並んでいる店が選ばれているだけなら、共有された店に替える。
  bool get _keepsChosenShop {
    final selected = state.selectedShop;
    if (selected != null) return !identical(selected, state.checkinShop);
    return state.manualName.trim().isNotEmpty;
  }

  /// 地図アプリから共有された店を選んだ状態にする。下書きに店が決まっていれば、下書きのままにする。
  /// 位置はリンクに書かれた座標、無ければ住所をサーバーで位置にしたもの。記録済みの店や願の店と
  /// 同じ店なら、そちらを選ぶ。位置がわからなければ店名だけ入れ、店名から探す・地図で指すに任せる。
  Future<void> _useSharedPlace(SharedWish shared) async {
    final name = shared.name.trim();
    if (name.isEmpty || _keepsChosenShop) return;
    final address = shared.address;
    final location =
        shared.location ?? (address == null ? null : await _geocode(address));
    await _knownShopsLoad;
    // 調べている間に店を選んだり打ったりしていれば、そちらを優先する。
    if (!ref.mounted || _keepsChosenShop) return;
    final incoming = ShopCandidate(name: name, location: location);
    final checkinShop = state.checkinShop;
    if (checkinShop != null && isSameShop(checkinShop, incoming)) {
      selectShop(checkinShop);
      return;
    }
    // 名前が似ているだけでは願を叶えないよう、位置のわからない願は店名がそろうときだけ選ぶ。
    final wish = _pendingWishes.where((w) {
      if (wishLocation(w) == null && w.osmId == null) {
        return normalizeShopName(w.name) == normalizeShopName(name);
      }
      return wishMatchesPlace(w, name: name, location: location);
    }).firstOrNull;
    final known = _knownShops
        .map(ShopCandidate.fromShop)
        .where((shop) => isSameShop(shop, incoming))
        .firstOrNull;
    final match = wish == null
        ? known
        : ShopCandidate(
            shopId: wish.shopId ?? known?.shopId,
            osmId: wish.osmId,
            name: wish.name,
            location: wishLocation(wish) ?? location,
            dataSource: wish.dataSource,
            wishId: wish.id,
          );
    if (match != null) {
      selectShop(match);
    } else if (location != null) {
      selectShop(incoming);
    } else {
      setManualName(name);
    }
  }

  Future<GeoPoint?> _geocode(String address) async {
    final analytics = ref.read(analyticsProvider);
    final location = await ref.read(addressGeocoderProvider)(address);
    unawaited(analytics.log(AnalyticsEvents.geocode(found: location != null)));
    return location;
  }

  /// 位置情報を許可済みなら、店名で探すときの基準に現在地を黙って取っておく（店は探さない）。
  Future<void> _loadQuietHere() async {
    final location = ref.read(locationServiceProvider);
    if (!await location.isReady()) return;
    final here = await location.currentPosition(requestPermission: false);
    if (ref.mounted) _quietHere = here;
  }

  /// 並んでいる店があれば、その店を選んだ状態で始める。
  Future<void> _loadCheckin() async {
    try {
      final checkin = await ref.read(recordRepositoryProvider).activeCheckin();
      if (!ref.mounted || checkin == null) return;
      if (isCheckinExpired(checkin, ref.read(clockProvider)())) return;
      _activeCheckin = checkin;
      await _useCheckin(checkin);
    } catch (e) {
      debugPrint('Checkin load failed: $e');
    }
  }

  Future<void> _useCheckin(Checkin checkin) async {
    // 記録済みの店なら、店の覚え書きも引き継ぐため店から作る。
    final known = checkin.shopId == null
        ? null
        : (await ref.read(recordRepositoryProvider).allShops())
              .where((shop) => shop.id == checkin.shopId)
              .firstOrNull;
    if (!ref.mounted) return;
    final latitude = checkin.latitude;
    final longitude = checkin.longitude;
    final shop = known != null
        ? ShopCandidate.fromShop(known)
        : ShopCandidate(
            shopId: checkin.shopId,
            osmId: checkin.osmId,
            name: checkin.name,
            dataSource: checkin.dataSource,
            location: latitude != null && longitude != null
                ? GeoPoint(latitude, longitude)
                : null,
          );
    state = state.copyWith(
      checkin: checkin,
      checkinShop: shop,
      selectedShop: shop,
      shopMemo: shop.strategyMemo,
      shopMemoOriginal: shop.strategyMemo,
      shopFamous: shop.isFamous,
      shopFamousOriginal: shop.isFamous,
    );
  }

  /// 下書きの「着」を使えるか。同じ並びが続いていれば使い、並びが終わっていれば下書きの並びで続ける。
  /// 別の並びが始まっていれば使わない。
  Future<bool> _restoreArrival(RecordDraft draft) async {
    final arrivedAt = draft.arrivedAt;
    final arrival = draft.arrivedCheckin;
    if (arrivedAt == null || arrival == null) return false;
    final active = state.checkin;
    if (active != null) return active.checkedInAt == arrival.checkedInAt;
    if (arrivedAt.isBefore(arrival.checkedInAt) ||
        isCheckinExpired(arrival, arrivedAt)) {
      return false;
    }
    try {
      await _useCheckin(arrival);
    } catch (e) {
      debugPrint('Arrival restore failed: $e');
      return false;
    }
    return ref.mounted;
  }

  Future<void> _restoreDraft() async {
    RecordDraft? draft;
    try {
      draft = await _draftStore.load();
    } catch (e) {
      debugPrint('Draft load failed: $e');
    }
    if (!ref.mounted || draft == null || draft.isEmpty) return;
    if (!await _restoreArrival(draft)) draft = draft.withoutArrival();
    if (!ref.mounted || draft.isEmpty) return;
    _lastDraftJson = jsonEncode(draft.toJson());
    _restoredShop = draft.selectedShop;
    _photoFromDraft = draft.photoPath != null;
    final typedName = draft.manualName.trim().isNotEmpty;
    final keepsShop = draft.selectedShop == null && !typedName;
    final shopMemoEdited =
        draft.shopMemo.trim() != draft.shopMemoOriginal.trim();
    final shopFamousEdited = draft.shopFamous != draft.shopFamousOriginal;
    state = state.copyWith(
      photoPath: draft.photoPath,
      photoTakenAt: draft.photoTakenAt,
      photoQuarterTurns: draft.photoQuarterTurns,
      photoFromCamera: draft.photoFromCamera,
      photoDateFromPhoto: draft.photoDateFromPhoto,
      photoLocation: draft.photoLocation,
      pinnedLocation: draft.pinnedLocation,
      // 店名を打っていたときは、並んでいる店の選択も外れていた。
      selectedShop:
          draft.selectedShop ?? (typedName ? null : state.selectedShop),
      manualName: draft.manualName,
      rating: draft.rating,
      style: draft.style,
      isLimited: draft.isLimited,
      memo: draft.memo,
      // 覚え書きに触っていなければ、選んでいる店（並んでいる店など）の今の覚え書きを出す。
      shopMemo: keepsShop && !shopMemoEdited ? state.shopMemo : draft.shopMemo,
      shopMemoOriginal: keepsShop && !shopMemoEdited
          ? state.shopMemoOriginal
          : draft.shopMemoOriginal,
      shopFamous: keepsShop && !shopFamousEdited
          ? state.shopFamous
          : draft.shopFamous,
      shopFamousOriginal: keepsShop && !shopFamousEdited
          ? state.shopFamousOriginal
          : draft.shopFamousOriginal,
      manualWaitMinutes: draft.manualWaitMinutes,
      arrivedAt: draft.arrivedAt,
      chosenEatenAt: draft.chosenEatenAt,
      resumedFromDraft: true,
    );
  }

  /// 下書きを捨てて、何も入れていない状態からやり直す。
  /// 開いたときに渡された写真（共有された写真など）は、新しい記録に使うので残す。
  Future<void> discardDraft() async {
    unawaited(
      ref
          .read(analyticsProvider)
          .log(AnalyticsEvents.draftDiscarded('restart')),
    );
    _pickedByNameSearch = false;
    final previous = state;
    final keepPhoto =
        _incomingPhoto != null && previous.photoPath == _incomingPhoto;
    // 下書きから戻した並びは下書きと一緒に捨て、保存先の並びに戻す。
    final active = _activeCheckin;
    final checkinShop = active == null ? null : previous.checkinShop;
    _restoredShop = null;
    _lastDraftJson = null;
    // 消してから新しい入力を書くよう、先に頼んでおく。
    final cleared = _draftStore.clear(
      keepPhoto: keepPhoto ? previous.photoPath : null,
    );
    state = RecordState(
      photoPath: keepPhoto ? previous.photoPath : null,
      photoTakenAt: keepPhoto ? previous.photoTakenAt : null,
      photoQuarterTurns: keepPhoto ? previous.photoQuarterTurns : 0,
      photoFromCamera: keepPhoto && previous.photoFromCamera,
      photoDateFromPhoto: keepPhoto && previous.photoDateFromPhoto,
      photoLocation: keepPhoto ? previous.photoLocation : null,
      searchStatus: previous.searchStatus,
      searchFailure: previous.searchFailure,
      candidates: previous.candidates,
      checkin: active,
      checkinShop: checkinShop,
      selectedShop: checkinShop,
      shopMemo: checkinShop?.strategyMemo ?? '',
      shopMemoOriginal: checkinShop?.strategyMemo ?? '',
      shopFamous: checkinShop?.isFamous ?? false,
      shopFamousOriginal: checkinShop?.isFamous ?? false,
      arrivedAt: active == null ? null : _tappedArrivedAt,
    );
    // 写真ごと捨てたら、その写真で探した候補も消す（写真を選ぶまで探さない）。
    if (!keepPhoto) {
      _searchGeneration++;
      _here = null;
      state = state.copyWith(
        searchStatus: ShopSearchStatus.idle,
        searchFailure: null,
        candidates: const [],
      );
    }
    try {
      await cleared;
    } catch (e) {
      debugPrint('Draft clear failed: $e');
    }
  }

  /// 記録をやめるときに、下書きと下書きの写真を消す。このあとの入力は下書きに書かない。
  Future<void> abandonDraft() async {
    unawaited(
      ref.read(analyticsProvider).log(AnalyticsEvents.draftDiscarded('leave')),
    );
    _draftClosed = true;
    await _clearDraftStore();
  }

  Future<void> _clearDraftStore() async {
    try {
      await _draftStore.clear();
    } catch (e) {
      debugPrint('Draft clear failed: $e');
    }
  }

  /// 一時ファイルの写真を、下書きとして残せるよう documents に写す。写せなければそのまま使う。
  Future<String> _keepPhoto(String path) async {
    try {
      return await _draftStore.keepPhoto(path);
    } catch (e) {
      debugPrint('Draft photo keep failed: $e');
      return path;
    }
  }

  Future<void> _loadKnownShops() async {
    try {
      _knownShops = await ref.read(recordRepositoryProvider).allShops();
    } catch (e) {
      debugPrint('Known shops load failed: $e');
    }
    try {
      _pendingWishes = await ref.read(wishRepositoryProvider).pendingWishes();
    } catch (e) {
      debugPrint('Wishes load failed: $e');
    }
  }

  Future<void> takePhoto() async {
    final taken = await ref.read(photoPickerProvider).takePhoto();
    if (!ref.mounted || taken == null) return;
    final path = await _keepPhoto(taken);
    if (!ref.mounted) return;
    _setPhoto(path, fromCamera: true);
  }

  Future<void> pickFromGallery() async {
    final path = await ref.read(photoPickerProvider).pickFromGallery();
    if (!ref.mounted || path == null) return;
    await _setGalleryPhoto(path);
  }

  /// 過去の写真から記録できるよう、写真の撮影日時を食べた日時にし、撮影場所で店を探す。
  Future<void> _setGalleryPhoto(String picked, {bool incoming = false}) async {
    final metadata = await ref.read(photoMetadataReaderProvider).read(picked);
    if (!ref.mounted) return;
    final path = await _keepPhoto(picked);
    if (!ref.mounted) return;
    if (incoming) _incomingPhoto = path;
    _setPhoto(path, fromCamera: false, metadata: metadata);
  }

  void _setPhoto(
    String path, {
    required bool fromCamera,
    PhotoMetadata metadata = PhotoMetadata.empty,
  }) {
    final takenAt = metadata.takenAt;
    final now = ref.read(clockProvider)();
    state = state.copyWith(
      photoPath: path,
      photoQuarterTurns: 0,
      // 撮り直しても、待ち時間が食べている時間だけ延びないよう最初の時刻を残す。
      // 前の写真の撮影日時を使っていたときは、今撮ったので今の時刻にする。
      photoTakenAt:
          takenAt ??
          (state.photoDateFromPhoto || _photoFromDraft
              ? now
              : state.photoTakenAt ?? now),
      photoDateFromPhoto: takenAt != null,
      photoLocation: metadata.location,
      photoFromCamera: fromCamera,
      // 写真を選び直したら、その写真の日時に戻す。
      chosenEatenAt: null,
    );
    _photoFromDraft = false;
    // 写真を選ぶたびに、撮影場所（無ければ現在地）で探し直す。並んだ店などを選んでいれば、選んだままにする。
    unawaited(
      searchShops(requestPermission: metadata.location == null, force: true),
    );
  }

  /// 写真に撮影場所があればそこで、無ければ現在地で探す。
  Future<void> searchShops({
    required bool requestPermission,
    bool force = false,
  }) async {
    if (!force && state.searchStatus == ShopSearchStatus.searching) return;
    final generation = ++_searchGeneration;
    final near = state.photoLocation;
    // 前の写真の場所が、探し終えるまでの間に手入力の店の位置にならないよう消しておく。
    _here = null;
    state = state.copyWith(
      searchStatus: ShopSearchStatus.searching,
      searchFailure: null,
    );
    final result = await ref
        .read(shopSearchServiceProvider)
        .search(requestPermission: requestPermission, near: near);
    if (!ref.mounted || generation != _searchGeneration) return;
    _here = result.here;
    final restored = _restoredShop;
    final selected = state.selectedShop;
    final match = restored != null && identical(selected, restored)
        ? result.candidates
              .where((c) => _sameSavedShop(c, restored))
              .firstOrNull
        : null;
    unawaited(
      ref
          .read(analyticsProvider)
          .log(AnalyticsEvents.shopSearch(purpose: 'record', result: result)),
    );
    state = state.copyWith(
      searchStatus: ShopSearchStatus.done,
      searchFailure: result.failure,
      candidates: result.candidates,
      selectedShop: match ?? selected,
    );
  }

  /// 下書きから戻した店と、検索の候補が同じ店か（同じ店が2つ並ばないようにする）。
  bool _sameSavedShop(ShopCandidate candidate, ShopCandidate restored) {
    if (restored.shopId != null) return candidate.shopId == restored.shopId;
    if (restored.osmId != null) return candidate.osmId == restored.osmId;
    final a = candidate.location;
    final b = restored.location;
    return candidate.shopId == null &&
        candidate.name == restored.name &&
        a != null &&
        b != null &&
        a.latitude == b.latitude &&
        a.longitude == b.longitude;
  }

  /// 店名で探すときに近い順に並べる基準（写真の撮影場所か現在地）。
  GeoPoint? get searchCenter => state.photoLocation ?? _here ?? _quietHere;

  /// 店を選び替えたら、店の覚え書きと名店の印はその店のものに入れ替える（前の店に書きかけた分は捨てる）。
  void selectShop(ShopCandidate shop) {
    _pickedByNameSearch = false;
    final memo = _shopMemoOf(shop);
    final famous = _shopFamousOf(shop);
    state = state.copyWith(
      selectedShop: shop,
      manualName: '',
      nameMatches: const [],
      shopMemo: memo,
      shopMemoOriginal: memo,
      shopFamous: famous,
      shopFamousOriginal: famous,
    );
  }

  /// 選んだ店の名店の印。願や検索の候補は印を持たないので、記録済みの店から引く。
  bool _shopFamousOf(ShopCandidate shop) =>
      _knownShops.where((s) => s.id == shop.shopId).firstOrNull?.isFamous ??
      shop.isFamous;

  /// 選んだ店の覚え書き。願や検索の候補は覚え書きを持たないので、記録済みの店から引く。
  String _shopMemoOf(ShopCandidate shop) {
    if (shop.strategyMemo.isNotEmpty) return shop.strategyMemo;
    final shopId = shop.shopId;
    if (shopId == null) return '';
    return _knownShops.where((s) => s.id == shopId).firstOrNull?.strategyMemo ??
        '';
  }

  /// 選んだ店を「店名から探す」で見つけたこと（統計に送る）。
  void markPickedByNameSearch() => _pickedByNameSearch = true;

  /// 店名を打っている間、覚え書きに触っていなければ、同じ名前の記録済みの店の覚え書きを入れておく
  /// （保存で同じ店とわかったときに、見ていない覚え書きを上書きしないため）。
  void setManualName(String name) {
    final query = normalizeShopName(name);
    final deselects = query.isNotEmpty && state.selectedShop != null;
    if (deselects) _pickedByNameSearch = false;
    final refills =
        deselects || (state.selectedShop == null && !state.shopMemoEdited);
    final memo = refills ? _knownShopByName(query)?.strategyMemo ?? '' : null;
    final refillsFamous =
        deselects || (state.selectedShop == null && !state.shopFamousEdited);
    final famous = refillsFamous
        ? _knownShopByName(query)?.isFamous ?? false
        : null;
    state = state.copyWith(
      manualName: name,
      selectedShop: deselects ? null : state.selectedShop,
      nameMatches: query.isEmpty ? const [] : _nameMatches(query),
      shopMemo: memo,
      shopMemoOriginal: memo,
      shopFamous: famous,
      shopFamousOriginal: famous,
    );
  }

  Shop? _knownShopByName(String query) {
    if (query.isEmpty) return null;
    return _knownShops
        .where((shop) => normalizeShopName(shop.name) == query)
        .firstOrNull;
  }

  List<ShopCandidate> _nameMatches(String query) =>
      shopNameMatches(query, wishes: _pendingWishes, knownShops: _knownShops);

  /// 手入力の店の場所を地図で指す。nullで外す。
  void setPinnedLocation(GeoPoint? location) =>
      state = state.copyWith(pinnedLocation: location);

  /// 写真を時計回りに90度回す（画面ではすぐ回し、ファイルは保存のときに回す）。
  void rotatePhoto() {
    if (state.photoPath == null || state.isSaving) return;
    state = state.copyWith(
      photoQuarterTurns: nextQuarterTurn(state.photoQuarterTurns),
    );
  }

  void setRating(int rating) => state = state.copyWith(rating: rating);

  void setStyle(RamenStyle? style) => state = state.copyWith(style: style);

  void setLimited(bool value) => state = state.copyWith(isLimited: value);

  void setMemo(String memo) => state = state.copyWith(memo: memo);

  void setShopMemo(String memo) => state = state.copyWith(shopMemo: memo);

  void setShopFamous(bool value) => state = state.copyWith(shopFamous: value);

  void setEatenAt(DateTime eatenAt) =>
      state = state.copyWith(chosenEatenAt: eatenAt);

  void setWaitMinutes(int? minutes) =>
      state = state.copyWith(manualWaitMinutes: minutes);

  /// 保存できたら記録のID、できなければnullを返す。
  Future<String?> save() async {
    final draft = state;
    if (!draft.canSave) return null;
    state = draft.copyWith(isSaving: true);
    final storage = ref.read(photoStorageProvider);
    String? savedPhoto;
    try {
      final photoPath = draft.photoPath;
      if (photoPath != null) {
        savedPhoto = await _savePhoto(storage, photoPath, draft);
      }
      final now = ref.read(clockProvider)();
      // 別の店を選んだときは「着」の時刻を使わない（並んでいる間に別の記録をすることもあるため）。
      final times = draft.timesAt(now);
      final eatenAt = times.eatenAt;
      final queuedAt = times.checkedInAt;
      final manualWait = draft.manualWaitMinutes;
      final visit = await ref
          .read(recordRepositoryProvider)
          .saveEatenVisit(
            shop: _shopInput(draft),
            eatenAt: eatenAt,
            rating: draft.rating,
            photoPath: savedPhoto,
            checkedInAt:
                queuedAt ??
                (manualWait == null || draft.isCheckinShopSelected
                    ? null
                    : eatenAt.subtract(Duration(minutes: manualWait))),
            endsCheckin: queuedAt != null,
            style: draft.style,
            isLimited: draft.isLimited,
            memo: draft.memo.trim(),
            // 書き換えたときだけ店に書く（打った店名が記録済みの店でも、触らなければ前の覚え書きを残す）。
            shopMemo: draft.shopMemoEdited ? draft.shopMemo.trim() : null,
            shopFamous: draft.shopFamousEdited ? draft.shopFamous : null,
            // 同じ名前の店の印が入っていても、離れた支店などで新しい店になれば、見えていた印を付ける。
            newShopFamous: draft.shopFamous,
            now: now,
          );
      lastSaveSummary = _saveSummary(draft, now);
      _draftClosed = true;
      await _clearDraftStore();
      return visit.id;
    } catch (e, st) {
      reportError(e, st, reason: 'Record save failed');
      if (savedPhoto != null) {
        try {
          await storage.delete(savedPhoto);
        } catch (_) {}
      }
      if (ref.mounted) state = state.copyWith(isSaving: false);
      return null;
    }
  }

  RecordSaveSummary _saveSummary(RecordState draft, DateTime now) {
    final startedAt = _startedAt;
    final photoPath = draft.photoPath;
    return RecordSaveSummary(
      entry: _entry,
      photoSource: photoPath == null
          ? PhotoSource.none
          : draft.photoFromCamera
          ? PhotoSource.camera
          : photoPath == _incomingPhoto
          ? (_sharedPhoto ? PhotoSource.shared : PhotoSource.recovered)
          : PhotoSource.gallery,
      shopSource: shopSourceOf(draft.selectedShop),
      usedNameSearch: _pickedByNameSearch && draft.selectedShop != null,
      hasRating: draft.rating != null,
      hasStyle: draft.style != null,
      isLimited: draft.isLimited,
      hasManualWait: draft.manualWaitMinutes != null,
      hasMemo: draft.memo.trim().isNotEmpty,
      shopMemoEdited: draft.shopMemoEdited,
      famousChanged: draft.shopFamousEdited,
      photoRotated: draft.photoQuarterTurns != 0,
      pinnedLocation:
          draft.selectedShop == null && draft.pinnedLocation != null,
      resumedDraft: draft.resumedFromDraft,
      atCheckinShop: draft.isCheckinShopSelected,
      elapsed: startedAt == null ? Duration.zero : now.difference(startedAt),
    );
  }

  /// 回した写真は回して書く。回せない写真（読めない形式など）は、記録を止めずにもとの向きで残す。
  Future<String> _savePhoto(
    PhotoStorage storage,
    String photoPath,
    RecordState draft,
  ) async {
    try {
      return await storage.saveRotated(photoPath, draft.photoQuarterTurns);
    } catch (e) {
      if (draft.photoQuarterTurns == 0) rethrow;
      debugPrint('Photo rotate failed: $e');
      return storage.save(photoPath);
    }
  }

  ShopInput _shopInput(RecordState draft) {
    final selected = draft.selectedShop;
    if (selected != null) {
      return ShopInput(
        shopId: selected.shopId,
        osmId: selected.osmId,
        name: selected.name,
        latitude: selected.location?.latitude,
        longitude: selected.location?.longitude,
        dataSource: selected.dataSource,
        wishId: selected.wishId,
      );
    }
    // 地図で指した場所を最優先にする。ギャラリーの写真は店にいるときに選んだとは限らないため、
    // 現在地を店の位置にしない。写真に撮影場所があれば、そこを店の位置にする。
    final here =
        draft.pinnedLocation ??
        draft.photoLocation ??
        (draft.photoFromCamera ? _here : null);
    return ShopInput(
      name: draft.manualName,
      latitude: here?.latitude,
      longitude: here?.longitude,
      locationPinned: draft.pinnedLocation != null,
    );
  }
}
