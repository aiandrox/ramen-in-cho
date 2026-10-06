import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../records/models.dart';

part 'app_database.g.dart';

class ShopSourceConverter extends TypeConverter<ShopSource, String> {
  const ShopSourceConverter();

  @override
  ShopSource fromSql(String fromDb) {
    final map = jsonDecode(fromDb) as Map<String, dynamic>;
    return ShopSource(
      licenses: [...?(map['licenses'] as List?)?.whereType<String>()],
      attributions: [...?(map['attributions'] as List?)?.whereType<String>()],
    );
  }

  @override
  String toSql(ShopSource value) => jsonEncode({
    'licenses': value.licenses,
    'attributions': value.attributions,
  });
}

@UseRowClass(Shop)
class Shops extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get osmId => text().nullable()();
  BoolColumn get isFamous => boolean().withDefault(const Constant(false))();
  TextColumn get strategyMemo => text().withDefault(const Constant(''))();
  TextColumn get dataSource =>
      text().map(const ShopSourceConverter()).nullable()();
  TextColumn get area => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@UseRowClass(Visit)
class Visits extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().references(Shops, #id)();
  TextColumn get result => textEnum<VisitResult>()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get checkedInAt => dateTime().nullable()();
  DateTimeColumn get eatenAt => dateTime()();
  TextColumn get style => textEnum<RamenStyle>().nullable()();
  IntColumn get rating => integer().nullable()();
  BoolColumn get isLimited => boolean().withDefault(const Constant(false))();
  TextColumn get memo => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@UseRowClass(Wish)
class Wishes extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().nullable()();
  TextColumn get osmId => text().nullable()();
  TextColumn get name => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get dataSource =>
      text().map(const ShopSourceConverter()).nullable()();
  TextColumn get trigger => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get fulfilledVisitId => text().nullable()();
  TextColumn get link => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 並んでいる最中のチェックイン。同時に1件だけなので、`id`は常に[activeCheckinId]。
class ActiveCheckins extends Table {
  IntColumn get id => integer()();
  TextColumn get shopId => text().nullable()();
  TextColumn get osmId => text().nullable()();
  TextColumn get name => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get dataSource =>
      text().map(const ShopSourceConverter()).nullable()();
  DateTimeColumn get checkedInAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

const activeCheckinId = 1;

@UseRowClass(HomeBaseSetting)
class HomeBaseSettings extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get setAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Shops, Visits, ActiveCheckins, Wishes, HomeBaseSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'ramen_in_cho'));

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(activeCheckins);
      if (from >= 2 && from < 5) {
        await migrator.addColumn(activeCheckins, activeCheckins.dataSource);
      }
      if (from < 3) {
        // 営業時間の種類の列（hours_type）は、店の条件とともにやめたので持ち越さない。
        await migrator.alterTable(
          TableMigration(
            shops,
            // 作り直した表には、バージョン4・5・7・10で足した列もすでに入る。
            newColumns: [
              shops.strategyMemo,
              shops.dataSource,
              shops.area,
              shops.isFamous,
            ],
          ),
        );
      }
      if (from == 3) await migrator.addColumn(shops, shops.strategyMemo);
      if (from >= 3 && from < 5) {
        await migrator.addColumn(shops, shops.dataSource);
      }
      if (from < 6) await migrator.createTable(wishes);
      if (from >= 3 && from < 7) await migrator.addColumn(shops, shops.area);
      if (from < 9) await migrator.createTable(homeBaseSettings);
      if (from >= 3 && from < 10) {
        await migrator.addColumn(shops, shops.isFamous);
      }
      // 店の条件（hours_conditions）の列を消す。表を作り直し、ほかの列の値はそのまま移す。
      if (from >= 3 && from < 11) {
        await migrator.alterTable(TableMigration(shops));
      }
      if (from >= 8 && from < 11) {
        await migrator.alterTable(
          TableMigration(wishes, newColumns: [wishes.link]),
        );
      }
      if ((from >= 6 && from < 8) || from == 11) {
        await migrator.addColumn(wishes, wishes.link);
      }
      // 整理券の列（has_ticket）を消す。表を作り直し、ほかの列の値はそのまま移す。
      if (from < 13) await migrator.alterTable(TableMigration(visits));
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
