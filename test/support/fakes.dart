import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/backup/backup_codec.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/notifications/notification_service.dart';
import 'package:ramen_in_cho/features/notifications/notification_settings.dart';
import 'package:ramen_in_cho/features/record/photo_metadata.dart';
import 'package:ramen_in_cho/features/record/photo_picker.dart';
import 'package:ramen_in_cho/features/record/record_draft.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';
import 'package:ramen_in_cho/features/shop_search/nearby_shop_finder.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/overpass_client.dart';
import 'package:ramen_in_cho/features/shop_search/shop_search_service.dart';

AppDatabase createTestDatabase() {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  return database;
}

Directory createTempDirectory() {
  final directory = Directory.systemTemp.createTempSync('ramen_in_cho_test');
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}

class FakeLocationService implements LocationService {
  FakeLocationService({this.position, this.ready = true});

  GeoPoint? position;
  bool ready;
  final requests = <bool>[];

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<GeoPoint?> currentPosition({required bool requestPermission}) async {
    requests.add(requestPermission);
    return position;
  }
}

class FakeShopFinder implements NearbyShopFinder {
  FakeShopFinder({this.shops = const [], this.error});

  List<FoundShop> shops;
  Object? error;
  int calls = 0;

  /// 渡すと、完了するまで検索の答えを返さない（探している最中の表示を確かめるため）。
  Completer<void>? gate;

  final radii = <int>[];
  final centers = <GeoPoint>[];

  @override
  Future<List<FoundShop>> searchNearby(
    GeoPoint center, {
    int radiusMeters = shopSearchRadiusMeters,
    Duration timeout = OverpassClient.timeout,
  }) async {
    calls++;
    radii.add(radiusMeters);
    centers.add(center);
    await gate?.future;
    final error = this.error;
    if (error != null) throw error;
    return shops;
  }
}

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.cameraPath, this.galleryPath, this.lostPath});

  String? cameraPath;
  String? galleryPath;
  String? lostPath;
  int cameraOpens = 0;

  @override
  Future<String?> takePhoto() async {
    cameraOpens++;
    return cameraPath;
  }

  @override
  Future<String?> pickFromGallery() async => galleryPath;

  @override
  Future<String?> retrieveLostPhoto() async => lostPath;
}

typedef VisitUpdate = ({
  String visitId,
  String shopName,
  DateTime eatenAt,
  DateTime? checkedInAt,
  int? rating,
  RamenStyle? style,
  bool isLimited,
  String memo,
  ShopInput? pickedShop,
  bool changesPhoto,
  String? photoPath,
  String? shopMemo,
  bool? shopFamous,
});

/// 画面のテスト用。driftを通さずに、呼ばれた内容だけを覚える。
class FakeRecordRepository implements RecordRepository {
  final updates = <VisitUpdate>[];
  final deletedVisitIds = <String>[];
  String? deletedPhotoPath;
  String? unusedPhotoPath;
  Object? error;

  @override
  Future<String?> updateVisit({
    required String visitId,
    required String shopName,
    required DateTime eatenAt,
    required DateTime? checkedInAt,
    required int? rating,
    required RamenStyle? style,
    required bool isLimited,
    required String memo,
    ShopInput? pickedShop,
    bool changesPhoto = false,
    String? photoPath,
    String? shopMemo,
    bool? shopFamous,
    required DateTime now,
  }) async {
    final error = this.error;
    if (error != null) throw error;
    updates.add((
      visitId: visitId,
      shopName: shopName,
      eatenAt: eatenAt,
      checkedInAt: checkedInAt,
      rating: rating,
      style: style,
      isLimited: isLimited,
      memo: memo,
      pickedShop: pickedShop,
      changesPhoto: changesPhoto,
      photoPath: photoPath,
      shopMemo: shopMemo,
      shopFamous: shopFamous,
    ));
    return unusedPhotoPath;
  }

  @override
  Future<String?> deleteVisit(String visitId) async {
    final error = this.error;
    if (error != null) throw error;
    deletedVisitIds.add(visitId);
    return deletedPhotoPath;
  }

  final checkins = <ShopInput>[];
  final retreatMemos = <String>[];
  final retreatWishTriggers = <String?>[];
  int cancelCount = 0;

  @override
  Future<void> checkIn({required ShopInput shop, required DateTime at}) async {
    final error = this.error;
    if (error != null) throw error;
    checkins.add(shop);
  }

  Object? importError;

  @override
  Future<int> importAll(BackupData data) async {
    final error = importError;
    if (error != null) throw error;
    return data.visits.length;
  }

  final shopMemos = <String, String>{};

  @override
  Future<void> setShopMemo(String shopId, String memo) async {
    shopMemos[shopId] = memo;
  }

  final famousShops = <String, bool>{};

  @override
  Future<void> setShopFamous(String shopId, bool isFamous) async {
    famousShops[shopId] = isFamous;
  }

  final ratings = <String, int>{};
  Object? ratingError;

  @override
  Future<void> setRating(String visitId, int rating) async {
    final error = ratingError;
    if (error != null) throw error;
    ratings[visitId] = rating;
  }

  @override
  Future<void> cancelCheckin() async {
    cancelCount++;
  }

  @override
  Future<Visit> saveRetreat({
    required Checkin checkin,
    String memo = '',
    String? wishTrigger,
    required DateTime now,
  }) async {
    final error = this.error;
    if (error != null) throw error;
    retreatMemos.add(memo);
    retreatWishTriggers.add(wishTrigger);
    return Visit(
      id: 'retreat',
      shopId: 'shop',
      result: VisitResult.retreated,
      checkedInAt: checkin.checkedInAt,
      eatenAt: now,
      isLimited: false,
      memo: memo,
      createdAt: now,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeShopSearchService implements ShopSearchService {
  FakeShopSearchService(this.result);

  ShopSearchResult result;

  /// 写真の場所で探したときの結果。nullなら[result]を返す。
  ShopSearchResult? resultNear;
  final nearPoints = <GeoPoint?>[];

  @override
  Future<ShopSearchResult> search({
    required bool requestPermission,
    GeoPoint? near,
  }) async {
    nearPoints.add(near);
    return near != null ? resultNear ?? result : result;
  }
}

class FakeNotificationService implements NotificationService {
  final shown = <String>[];
  int cancelCount = 0;

  @override
  Future<void> showCheckin({
    required String title,
    required String body,
    required DateTime checkedInAt,
  }) async {
    shown.add(title);
  }

  @override
  Future<void> cancelCheckin() async {
    cancelCount++;
  }

  int permissionRequests = 0;
  bool? permitted = true;

  /// いま予約されている通知（最後に置き換えたもの）。
  List<ScheduledNotification> scheduled = const [];
  int replaceCount = 0;

  List<DateTime> get streakReminders => [
    for (final n in scheduled)
      if (n.kind == NotificationKind.streak) n.at,
  ];

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }

  @override
  Future<bool?> isPermitted() async => permitted;

  /// スマホの設定で止められている種類（Android）。
  Set<NotificationKind> blocked = {};

  @override
  Future<Set<NotificationKind>> blockedKinds() async => blocked;

  final tapController = StreamController<String>.broadcast();
  String? launchPayload;

  @override
  Stream<String> get taps => tapController.stream;

  @override
  Future<String?> takeLaunchPayload() async {
    final payload = launchPayload;
    launchPayload = null;
    return payload;
  }

  @override
  Future<void> showSoon(ScheduledNotification notification) async {}

  @override
  Future<bool> replaceScheduled(
    List<ScheduledNotification> notifications,
  ) async {
    replaceCount++;
    scheduled = notifications;
    return true;
  }
}

class FakePhotoMetadataReader implements PhotoMetadataReader {
  PhotoMetadata metadata = PhotoMetadata.empty;
  final paths = <String>[];

  @override
  Future<PhotoMetadata> read(String path) async {
    paths.add(path);
    return metadata;
  }
}

class FakeWishRepository implements WishRepository {
  final added = <ShopInput>[];
  final triggers = <String>[];
  final links = <String?>[];

  @override
  Future<Wish> addWish({
    required ShopInput shop,
    String trigger = '',
    String note = '',
    String? link,
    required DateTime now,
  }) async {
    added.add(shop);
    triggers.add(trigger);
    links.add(link);
    return Wish(id: 'wish-${added.length}', name: shop.name, createdAt: now);
  }

  @override
  Future<void> updateWish(
    String id, {
    required String trigger,
    required String note,
    String? link,
  }) async {}

  final deleted = <String>[];

  @override
  Future<void> deleteWish(String id) async => deleted.add(id);

  @override
  Future<List<Wish>> pendingWishes() async => const [];

  @override
  Stream<List<Wish>> watchWishes() => const Stream.empty();
}

/// 下書きをメモリーに持つ（ウィジェットのテストの偽の時間ではファイルの読み書きが終わらないため）。
class MemoryRecordDraftStore implements RecordDraftStore {
  RecordDraft? draft;

  @override
  Future<RecordDraft?> load() async => draft;

  @override
  Future<String> keepPhoto(String sourcePath) async => sourcePath;

  @override
  Future<void> save(RecordDraft value) async =>
      draft = value.isEmpty ? null : value;

  @override
  Future<void> clear({String? keepPhoto}) async => draft = null;
}
