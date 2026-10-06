import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../records/models.dart';
import '../records/record_repository.dart';

final wishRepositoryProvider = Provider<WishRepository>(
  (ref) => WishRepository(ref.watch(appDatabaseProvider)),
);

/// 願掛け帳の全件（書き留めた新しい順）。
final wishesProvider = StreamProvider<List<Wish>>(
  (ref) => ref.watch(wishRepositoryProvider).watchWishes(),
);

class WishRepository {
  WishRepository(this._db, {this._uuid = const Uuid()});

  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<Wish>> watchWishes() => (_db.select(
    _db.wishes,
  )..orderBy([(w) => OrderingTerm.desc(w.createdAt)])).watch();

  Future<List<Wish>> pendingWishes() =>
      (_db.select(_db.wishes)..where((w) => w.fulfilledVisitId.isNull())).get();

  Future<Wish> addWish({
    required ShopInput shop,
    String trigger = '',
    String note = '',
    required DateTime now,
  }) async {
    final wish = Wish(
      id: _uuid.v4(),
      shopId: shop.shopId,
      osmId: shop.osmId,
      name: shop.name.trim(),
      latitude: shop.latitude,
      longitude: shop.longitude,
      dataSource: shop.dataSource,
      trigger: trigger.trim(),
      note: note.trim(),
      createdAt: now,
    );
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
          ),
        );
    return wish;
  }

  Future<void> updateWish(
    String id, {
    required String trigger,
    required String note,
  }) => (_db.update(_db.wishes)..where((w) => w.id.equals(id))).write(
    WishesCompanion(trigger: Value(trigger.trim()), note: Value(note.trim())),
  );

  Future<void> deleteWish(String id) =>
      (_db.delete(_db.wishes)..where((w) => w.id.equals(id))).go();
}
