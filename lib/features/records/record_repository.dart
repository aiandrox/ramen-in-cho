import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../backup/backup_codec.dart';
import '../database/app_database.dart';
import '../home_base/home_base_repository.dart';
import '../shop_search/found_shop.dart';
import '../shop_search/geo.dart';
import 'models.dart';

final recordRepositoryProvider = Provider<RecordRepository>(
  (ref) => RecordRepository(ref.watch(appDatabaseProvider)),
);

final visitsProvider = StreamProvider<List<VisitWithShop>>(
  (ref) => ref.watch(recordRepositoryProvider).watchVisits(),
);

/// 記録につける店の指定。既存の店・OpenStreetMapの店・手入力の店のどれか。
class ShopInput {
  const ShopInput({
    this.shopId,
    this.osmId,
    required this.name,
    this.latitude,
    this.longitude,
    this.dataSource,
    this.wishId,
    this.locationPinned = false,
  });

  final String? shopId;
  final String? osmId;
  final String name;
  final double? latitude;
  final double? longitude;
  final ShopSource? dataSource;

  /// 願掛け帳の店を選んだときの願。食べた記録を保存すると、この願が叶う。
  final String? wishId;

  /// 位置が地図で指した場所か。同じ店（OpenStreetMap 以外）が見つかれば、その店の位置も直す。
  final bool locationPinned;
}

class RecordRepository {
  RecordRepository(this._db, {this._uuid = const Uuid()});

  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<VisitWithShop>> watchVisits() {
    final query = _db.select(_db.visits).join([
      innerJoin(_db.shops, _db.shops.id.equalsExp(_db.visits.shopId)),
    ])..orderBy([OrderingTerm.desc(_db.visits.eatenAt)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          VisitWithShop(
            visit: row.readTable(_db.visits),
            shop: row.readTable(_db.shops),
          ),
      ],
    );
  }

  Future<List<Shop>> allShops() => _db.select(_db.shops).get();

  Future<BackupData> exportAll() async => BackupData(
    shops: await _db.select(_db.shops).get(),
    visits: await _db.select(_db.visits).get(),
    wishes: await _db.select(_db.wishes).get(),
    homeBases: await _db.select(_db.homeBaseSettings).get(),
  );

  /// バックアップの記録（店・願・拠点・記録）を足す。同じIDのものがすでにあれば、端末の方を残す。
  /// 足した記録の件数を返す。
  Future<int> importAll(BackupData data) {
    return _db.transaction(() async {
      final shopIds = {
        for (final shop in await _db.select(_db.shops).get()) shop.id,
      };
      for (final shop in data.shops) {
        if (!shopIds.add(shop.id)) continue;
        await _db
            .into(_db.shops)
            .insert(
              ShopsCompanion.insert(
                id: shop.id,
                name: shop.name,
                latitude: Value(shop.latitude),
                longitude: Value(shop.longitude),
                osmId: Value(shop.osmId),
                isFamous: Value(shop.isFamous),
                strategyMemo: Value(shop.strategyMemo),
                dataSource: Value(shop.dataSource),
                area: Value(shop.area),
                createdAt: shop.createdAt,
              ),
            );
      }
      final wishIds = {
        for (final wish in await _db.select(_db.wishes).get()) wish.id,
      };
      for (final wish in data.wishes) {
        if (!wishIds.add(wish.id)) continue;
        await _db
            .into(_db.wishes)
            .insert(
              WishesCompanion.insert(
                id: wish.id,
                shopId: Value(wish.shopId),
                osmId: Value(wish.osmId),
                name: wish.name,
                latitude: Value(wish.latitude),
                longitude: Value(wish.longitude),
                dataSource: Value(wish.dataSource),
                trigger: Value(wish.trigger),
                note: Value(wish.note),
                createdAt: wish.createdAt,
                fulfilledVisitId: Value(wish.fulfilledVisitId),
              ),
            );
      }
      final homeBaseIds = {
        for (final base in await _db.select(_db.homeBaseSettings).get())
          base.id,
      };
      for (final base in data.homeBases) {
        if (!homeBaseIds.add(base.id)) continue;
        await _db.into(_db.homeBaseSettings).insert(base.toCompanion());
      }
      final visitIds = {
        for (final visit in await _db.select(_db.visits).get()) visit.id,
      };
      var added = 0;
      for (final visit in data.visits) {
        if (!shopIds.contains(visit.shopId) || !visitIds.add(visit.id)) {
          continue;
        }
        await _insertVisit(visit);
        added++;
      }
      return added;
    });
  }

  Stream<Checkin?> watchActiveCheckin() => _db
      .select(_db.activeCheckins)
      .watchSingleOrNull()
      .map((row) => row == null ? null : _toCheckin(row));

  Future<Checkin?> activeCheckin() async {
    final row = await _db.select(_db.activeCheckins).getSingleOrNull();
    return row == null ? null : _toCheckin(row);
  }

  Checkin _toCheckin(ActiveCheckin row) => Checkin(
    shopId: row.shopId,
    osmId: row.osmId,
    name: row.name,
    latitude: row.latitude,
    longitude: row.longitude,
    dataSource: row.dataSource,
    checkedInAt: row.checkedInAt,
  );

  /// 並び始める。すでにチェックイン中なら置き換える。
  Future<void> checkIn({required ShopInput shop, required DateTime at}) {
    return _db
        .into(_db.activeCheckins)
        .insertOnConflictUpdate(
          ActiveCheckinsCompanion.insert(
            id: const Value(activeCheckinId),
            shopId: Value(shop.shopId),
            osmId: Value(shop.osmId),
            name: shop.name.trim(),
            latitude: Value(shop.latitude),
            longitude: Value(shop.longitude),
            dataSource: Value(shop.dataSource),
            checkedInAt: at,
          ),
        );
  }

  Future<void> cancelCheckin() => _db.delete(_db.activeCheckins).go();

  /// 並んだが食べられなかった記録を残し、チェックインを終える。
  /// [wishTrigger]を渡すと、その店を願掛け帳に入れる（まだの願が無いときだけ）。
  /// 次にその店で食べると、願が叶ったことになる。
  Future<Visit> saveRetreat({
    required Checkin checkin,
    String memo = '',
    String? wishTrigger,
    required DateTime now,
  }) {
    return _db.transaction(() async {
      final shopId = await _resolveShop(_shopInputOf(checkin), now);
      final visit = Visit(
        id: _uuid.v4(),
        shopId: shopId,
        result: VisitResult.retreated,
        checkedInAt: checkin.checkedInAt,
        eatenAt: now,
        isLimited: false,
        hasTicket: false,
        memo: memo,
        createdAt: now,
      );
      await _insertVisit(visit);
      await cancelCheckin();
      if (wishTrigger != null) {
        await _wishAfterRetreat(checkin, shopId, wishTrigger, now);
      }
      return visit;
    });
  }

  Future<void> _wishAfterRetreat(
    Checkin checkin,
    String shopId,
    String trigger,
    DateTime now,
  ) async {
    final pending =
        await (_db.select(_db.wishes)
              ..where(
                (w) => w.fulfilledVisitId.isNull() & w.shopId.equals(shopId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (pending != null) return;
    await _db
        .into(_db.wishes)
        .insert(
          WishesCompanion.insert(
            id: _uuid.v4(),
            shopId: Value(shopId),
            osmId: Value(checkin.osmId),
            name: checkin.name.trim(),
            latitude: Value(checkin.latitude),
            longitude: Value(checkin.longitude),
            dataSource: Value(checkin.dataSource),
            trigger: Value(trigger),
            createdAt: now,
          ),
        );
  }

  ShopInput _shopInputOf(Checkin checkin) => ShopInput(
    shopId: checkin.shopId,
    osmId: checkin.osmId,
    name: checkin.name,
    latitude: checkin.latitude,
    longitude: checkin.longitude,
    dataSource: checkin.dataSource,
  );

  Future<void> _insertVisit(Visit visit) => _db
      .into(_db.visits)
      .insert(
        VisitsCompanion.insert(
          id: visit.id,
          shopId: visit.shopId,
          result: visit.result,
          photoPath: Value(visit.photoPath),
          checkedInAt: Value(visit.checkedInAt),
          eatenAt: visit.eatenAt,
          style: Value(visit.style),
          rating: Value(visit.rating),
          isLimited: Value(visit.isLimited),
          hasTicket: Value(visit.hasTicket),
          memo: Value(visit.memo),
          createdAt: visit.createdAt,
        ),
      );

  /// [endsCheckin]がtrueなら、チェックインを終える
  /// （省略時は[checkedInAt]を渡したとき）。待ち時間を手で入れたときはfalseにする。
  /// [shopMemo]を渡すと、記録をつけた店の覚え書きをそれに書き換える。
  Future<Visit> saveEatenVisit({
    required ShopInput shop,
    required DateTime eatenAt,
    int? rating,
    String? photoPath,
    DateTime? checkedInAt,
    bool? endsCheckin,
    RamenStyle? style,
    bool isLimited = false,
    bool hasTicket = false,
    String memo = '',
    String? shopMemo,
    required DateTime now,
  }) {
    return _db.transaction(() async {
      final shopId = await _resolveShop(shop, now);
      if (shopMemo != null) await setShopMemo(shopId, shopMemo);
      final visit = Visit(
        id: _uuid.v4(),
        shopId: shopId,
        result: VisitResult.eaten,
        photoPath: photoPath,
        checkedInAt: checkedInAt,
        eatenAt: eatenAt,
        style: style,
        rating: rating,
        isLimited: isLimited,
        hasTicket: hasTicket,
        memo: memo,
        createdAt: now,
      );
      await _insertVisit(visit);
      await _fulfillWish(shop, shopId: shopId, visitId: visit.id);
      if (endsCheckin ?? checkedInAt != null) await cancelCheckin();
      return visit;
    });
  }

  /// 選んだ願か、IDで同じ店とわかるまだの願を、この1杯で叶える。名前が似ているだけでは叶えない
  /// （別の支店で叶ってしまわないよう。そのときは店のページから手で叶える）。
  Future<void> _fulfillWish(
    ShopInput shop, {
    required String shopId,
    required String visitId,
  }) async {
    final osmId = shop.osmId;
    final wish =
        await (_db.select(_db.wishes)
              ..where(
                (w) =>
                    w.fulfilledVisitId.isNull() &
                    (shop.wishId != null
                        ? w.id.equals(shop.wishId!)
                        : w.shopId.equals(shopId) |
                              (osmId == null
                                  ? const Constant(false)
                                  : w.osmId.equals(osmId))),
              )
              ..orderBy([(w) => OrderingTerm.asc(w.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (wish == null) return;
    await fulfillWish(wish.id, visitId: visitId, shopId: shopId);
  }

  /// 願を、この1杯で叶えたことにする。
  Future<void> fulfillWish(
    String wishId, {
    required String visitId,
    required String shopId,
  }) => (_db.update(_db.wishes)..where((w) => w.id.equals(wishId))).write(
    WishesCompanion(fulfilledVisitId: Value(visitId), shopId: Value(shopId)),
  );

  /// 店に位置を付ける・直す（店名で探した店の位置か、地図で指した場所）。
  /// 市区町村は新しい位置で調べ直すよう空に戻す。
  Future<void> setShopLocation(
    String shopId, {
    required double latitude,
    required double longitude,
    String? osmId,
    ShopSource? dataSource,
  }) => (_db.update(_db.shops)..where((s) => s.id.equals(shopId))).write(
    ShopsCompanion(
      latitude: Value(latitude),
      longitude: Value(longitude),
      osmId: osmId == null ? const Value.absent() : Value(osmId),
      dataSource: dataSource == null ? const Value.absent() : Value(dataSource),
      area: const Value(null),
    ),
  );

  /// [latitude]・[longitude]を渡すと、調べている間に位置が直されていたら書かない。
  Future<void> setShopArea(
    String shopId,
    String area, {
    double? latitude,
    double? longitude,
  }) =>
      (_db.update(_db.shops)..where(
            (s) =>
                s.id.equals(shopId) &
                (latitude == null
                    ? const Constant(true)
                    : s.latitude.equals(latitude)) &
                (longitude == null
                    ? const Constant(true)
                    : s.longitude.equals(longitude)),
          ))
          .write(ShopsCompanion(area: Value(area)));

  Future<void> setShopMemo(String shopId, String memo) =>
      (_db.update(_db.shops)..where((s) => s.id.equals(shopId))).write(
        ShopsCompanion(strategyMemo: Value(memo.trim())),
      );

  Future<void> setShopFamous(String shopId, bool isFamous) =>
      (_db.update(_db.shops)..where((s) => s.id.equals(shopId))).write(
        ShopsCompanion(isFamous: Value(isFamous)),
      );

  Future<void> setRating(String visitId, int rating) =>
      (_db.update(_db.visits)..where((v) => v.id.equals(visitId))).write(
        VisitsCompanion(rating: Value(rating)),
      );

  /// 店名を変えたときは、この記録だけを別の店に付け替える。ただし手入力の店でほかに記録が
  /// 無ければ、位置を失わないよう店の名前を直す。[pickedShop]（候補や店名検索で選び直した店）を
  /// 渡すと、店名ではなくその店に付け替える。
  /// [changesPhoto]がtrueなら写真を[photoPath]に替え、ほかの記録が使っていない前の写真の
  /// パスを返す（ファイルの削除は呼び出し側で行う）。
  /// [shopMemo]を渡すと、付け替えたあとの店の覚え書きをそれに書き換える。
  Future<String?> updateVisit({
    required String visitId,
    required String shopName,
    required DateTime eatenAt,
    required DateTime? checkedInAt,
    required int? rating,
    required RamenStyle? style,
    required bool isLimited,
    required bool hasTicket,
    required String memo,
    ShopInput? pickedShop,
    bool changesPhoto = false,
    String? photoPath,
    String? shopMemo,
    required DateTime now,
  }) {
    return _db.transaction(() async {
      final visit = await (_db.select(
        _db.visits,
      )..where((v) => v.id.equals(visitId))).getSingle();
      final shop = await (_db.select(
        _db.shops,
      )..where((s) => s.id.equals(visit.shopId))).getSingle();
      final name = shopName.trim();
      var shopId = shop.id;
      if (pickedShop != null) {
        shopId = await _resolveShop(pickedShop, now);
      } else if (name.isNotEmpty && name != shop.name) {
        final sameName = await _findShop(
          ShopInput(
            name: name,
            latitude: shop.latitude,
            longitude: shop.longitude,
          ),
        );
        final hasOtherVisits = await _visitCount(shop.id) > 1;
        if (sameName != null) {
          shopId = sameName.id;
        } else if (hasOtherVisits || shop.osmId != null) {
          shopId = await _resolveShop(ShopInput(name: name), now);
        } else {
          await (_db.update(_db.shops)..where((s) => s.id.equals(shop.id)))
              .write(ShopsCompanion(name: Value(name)));
        }
      }
      await (_db.update(_db.visits)..where((v) => v.id.equals(visitId))).write(
        VisitsCompanion(
          shopId: Value(shopId),
          eatenAt: Value(eatenAt),
          checkedInAt: Value(checkedInAt),
          rating: Value(rating),
          style: Value(style),
          isLimited: Value(isLimited),
          hasTicket: Value(hasTicket),
          memo: Value(memo),
          photoPath: changesPhoto ? Value(photoPath) : const Value.absent(),
        ),
      );
      if (shopMemo != null) await setShopMemo(shopId, shopMemo);
      if (shopId != shop.id) {
        // 前の店で叶えた願は、まだの願に戻す。付け替えた先の店の願なら叶え直す。
        await (_db.update(_db.wishes)
              ..where((w) => w.fulfilledVisitId.equals(visitId)))
            .write(const WishesCompanion(fulfilledVisitId: Value(null)));
        if (visit.result == VisitResult.eaten) {
          await _fulfillWish(
            pickedShop ?? ShopInput(name: name),
            shopId: shopId,
            visitId: visitId,
          );
        }
        await _deleteShopIfUnused(shop.id);
      }
      final oldPhoto = visit.photoPath;
      if (!changesPhoto || oldPhoto == null || oldPhoto == photoPath) {
        return null;
      }
      return await _isPhotoUsed(oldPhoto) ? null : oldPhoto;
    });
  }

  Future<bool> _isPhotoUsed(String photoPath) async {
    final used =
        await (_db.select(_db.visits)
              ..where((v) => v.photoPath.equals(photoPath))
              ..limit(1))
            .getSingleOrNull();
    return used != null;
  }

  /// 削除した記録の写真のパスを返す（ファイルの削除は呼び出し側で行う）。
  Future<String?> deleteVisit(String visitId) {
    return _db.transaction(() async {
      final visit = await (_db.select(
        _db.visits,
      )..where((v) => v.id.equals(visitId))).getSingleOrNull();
      if (visit == null) return null;
      await (_db.delete(_db.visits)..where((v) => v.id.equals(visitId))).go();
      // 叶えた1杯を消したら、願はまだの願に戻す。
      await (_db.update(_db.wishes)
            ..where((w) => w.fulfilledVisitId.equals(visitId)))
          .write(const WishesCompanion(fulfilledVisitId: Value(null)));
      await _deleteShopIfUnused(visit.shopId);
      return visit.photoPath;
    });
  }

  Future<int> _visitCount(String shopId) async {
    final count = _db.visits.id.count();
    final query = _db.selectOnly(_db.visits)
      ..addColumns([count])
      ..where(_db.visits.shopId.equals(shopId));
    return await query.map((row) => row.read(count)).getSingle() ?? 0;
  }

  Future<void> _deleteShopIfUnused(String shopId) async {
    if (await _visitCount(shopId) > 0) return;
    await (_db.delete(_db.shops)..where((s) => s.id.equals(shopId))).go();
    // 願と並んでいる店は名前と位置を持っているので、消えた店のIDだけを外して残す。
    await (_db.update(_db.wishes)..where((w) => w.shopId.equals(shopId))).write(
      const WishesCompanion(shopId: Value(null)),
    );
    await (_db.update(_db.activeCheckins)
          ..where((c) => c.shopId.equals(shopId)))
        .write(const ActiveCheckinsCompanion(shopId: Value(null)));
  }

  Future<String> _resolveShop(ShopInput input, DateTime now) async {
    final existing = await _findShop(input);
    if (existing != null) {
      // 手入力で記録した店をあとから検索結果で選んだときは、同じ店として位置とIDを補う。
      final adoptsOsm = existing.osmId == null && input.osmId != null;
      final adoptsSource =
          existing.dataSource == null && input.dataSource != null;
      // 位置のわからない店に、店名で探した店などの位置が来たら、地図に載るよう位置を補う。
      final adoptsLocation =
          existing.latitude == null &&
          input.latitude != null &&
          input.longitude != null;
      // 地図で指した場所は利用者が直した位置なので、OpenStreetMap 以外の店ならその位置に移す。
      final movesToPin =
          input.locationPinned &&
          existing.osmId == null &&
          input.latitude != null &&
          input.longitude != null &&
          (existing.latitude != input.latitude ||
              existing.longitude != input.longitude);
      final setsLocation = adoptsOsm || adoptsLocation || movesToPin;
      if (setsLocation || adoptsSource) {
        await (_db.update(
          _db.shops,
        )..where((s) => s.id.equals(existing.id))).write(
          ShopsCompanion(
            osmId: adoptsOsm ? Value(input.osmId) : const Value.absent(),
            latitude: setsLocation
                ? Value(input.latitude)
                : const Value.absent(),
            longitude: setsLocation
                ? Value(input.longitude)
                : const Value.absent(),
            area: movesToPin ? const Value(null) : const Value.absent(),
            dataSource: adoptsSource
                ? Value(input.dataSource)
                : const Value.absent(),
          ),
        );
      }
      return existing.id;
    }
    final id = _uuid.v4();
    await _db
        .into(_db.shops)
        .insert(
          ShopsCompanion.insert(
            id: id,
            name: input.name.trim(),
            latitude: Value(input.latitude),
            longitude: Value(input.longitude),
            osmId: Value(input.osmId),
            dataSource: Value(input.dataSource),
            createdAt: now,
          ),
        );
    return id;
  }

  Future<Shop?> _findShop(ShopInput input) async {
    final shopId = input.shopId;
    if (shopId != null) {
      return (_db.select(
        _db.shops,
      )..where((s) => s.id.equals(shopId))).getSingleOrNull();
    }
    final osmId = input.osmId;
    if (osmId != null) {
      final byOsmId =
          await (_db.select(_db.shops)
                ..where((s) => s.osmId.equals(osmId))
                ..limit(1))
              .getSingleOrNull();
      if (byOsmId != null) return byOsmId;
      final lookAlike = await _lookAlikeShopWithoutOsmId(input);
      if (lookAlike != null) return lookAlike;
    }
    final sameName = await (_db.select(
      _db.shops,
    )..where((s) => s.name.equals(input.name.trim()))).get();
    return _nearestSameShop(input, [
      for (final shop in sameName)
        if (osmId == null || shop.osmId == null) shop,
    ]);
  }

  /// OpenPOI で選んだ店（OpenStreetMap の ID なし）を、表記の少し違う OpenStreetMap の同じ店として見つける。
  Future<Shop?> _lookAlikeShopWithoutOsmId(ShopInput input) async {
    final latitude = input.latitude;
    final longitude = input.longitude;
    if (latitude == null || longitude == null) return null;
    final here = GeoPoint(latitude, longitude);
    final shops = await (_db.select(
      _db.shops,
    )..where((s) => s.osmId.isNull() & s.latitude.isNotNull())).get();
    for (final shop in shops) {
      if (looksLikeSameShop(
        input.name,
        here,
        shop.name,
        GeoPoint(shop.latitude!, shop.longitude!),
      )) {
        return shop;
      }
    }
    return null;
  }

  /// 同じ名前でも離れていれば別の店（支店）として扱う。どちらかの位置がわからないときは
  /// 同じ店とみなす。
  Shop? _nearestSameShop(ShopInput input, List<Shop> sameName) {
    final latitude = input.latitude;
    final longitude = input.longitude;
    Shop? best;
    var bestDistance = double.infinity;
    for (final shop in sameName) {
      var distance = _sameShopRadiusMeters;
      if (latitude != null &&
          longitude != null &&
          shop.latitude != null &&
          shop.longitude != null) {
        distance = distanceMeters(
          GeoPoint(latitude, longitude),
          GeoPoint(shop.latitude!, shop.longitude!),
        );
      }
      if (distance > _sameShopRadiusMeters) continue;
      if (distance < bestDistance) {
        best = shop;
        bestDistance = distance;
      }
    }
    return best;
  }

  static const _sameShopRadiusMeters = 300.0;
}
