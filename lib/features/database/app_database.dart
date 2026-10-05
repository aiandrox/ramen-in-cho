import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../records/models.dart';

part 'app_database.g.dart';

/// 営業時間の条件を、定義順の名前をカンマでつないだ文字列で保存する。
class HoursConditionsConverter
    extends TypeConverter<Set<HoursCondition>, String> {
  const HoursConditionsConverter();

  @override
  Set<HoursCondition> fromSql(String fromDb) {
    final byName = HoursCondition.values.asNameMap();
    return {for (final name in fromDb.split(',')) ?byName[name]};
  }

  @override
  String toSql(Set<HoursCondition> value) => [
    for (final condition in HoursCondition.values)
      if (value.contains(condition)) condition.name,
  ].join(',');
}

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
  TextColumn get hoursConditions => text()
      .map(const HoursConditionsConverter())
      .withDefault(const Constant(''))();
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
  BoolColumn get hasTicket => boolean().withDefault(const Constant(false))();
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
  TextColumn get hoursConditions => text()
      .map(const HoursConditionsConverter())
      .withDefault(const Constant(''))();

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
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(activeCheckins);
      if (from >= 2 && from < 5) {
        await migrator.addColumn(activeCheckins, activeCheckins.dataSource);
      }
      if (from < 3) {
        // 営業時間の種類（1つだけ選ぶ）を、条件（いくつでも選べる）に置き換える。
        await migrator.alterTable(
          TableMigration(
            shops,
            columnTransformer: {
              shops.hoursConditions: const CustomExpression<String>(
                "CASE hours_type WHEN 'lunchOnly' THEN 'lunchOnly' "
                "WHEN 'fewDays' THEN 'fewDays' ELSE '' END",
              ),
            },
            // 作り直した表には、バージョン4・5・7で足した列もすでに入る。
            newColumns: [
              shops.hoursConditions,
              shops.strategyMemo,
              shops.dataSource,
              shops.area,
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
      if (from >= 6 && from < 8) {
        await migrator.addColumn(wishes, wishes.hoursConditions);
      }
      if (from < 9) await migrator.createTable(homeBaseSettings);
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
