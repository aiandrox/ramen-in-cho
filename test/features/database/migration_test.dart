import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

/// 最初の版（バージョン1）のテーブル定義。
const _v1Schema = [
  '''
CREATE TABLE shops (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  latitude REAL,
  longitude REAL,
  osm_id TEXT,
  hours_type TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (id)
)''',
  '''
CREATE TABLE visits (
  id TEXT NOT NULL,
  shop_id TEXT NOT NULL REFERENCES shops (id),
  result TEXT NOT NULL,
  photo_path TEXT,
  checked_in_at INTEGER,
  eaten_at INTEGER NOT NULL,
  style TEXT,
  rating INTEGER,
  is_limited INTEGER NOT NULL DEFAULT 0 CHECK (is_limited IN (0, 1)),
  has_ticket INTEGER NOT NULL DEFAULT 0 CHECK (has_ticket IN (0, 1)),
  memo TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  PRIMARY KEY (id)
)''',
];

void main() {
  test('バージョン1のデータを残したまま、チェックインのテーブルを追加する', () async {
    final eatenAt = DateTime(2026, 9, 30, 12);
    final seconds = eatenAt.millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _v1Schema) {
            raw.execute(statement);
          }
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', 35.0, 139.0, 'node/1', 'fewDays', $seconds)",
          );
          raw.execute(
            "INSERT INTO visits VALUES ('visit', 'shop', 'eaten', "
            "'photos/a.jpg', NULL, $seconds, 'shoyu', 4, 1, 0, 'メモ', $seconds)",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(database.close);
    final repository = RecordRepository(database);

    final entry = (await repository.watchVisits().first).single;
    expect(entry.shop.name, '麺屋');
    // 以前の「週3日以下」は、条件「週3日以下」に引き継ぐ。
    expect(entry.shop.hoursConditions, {HoursCondition.fewDays});
    expect(entry.visit.photoPath, 'photos/a.jpg');
    expect(entry.visit.eatenAt, eatenAt);
    expect(entry.visit.style, RamenStyle.shoyu);
    expect(entry.visit.rating, 4);
    expect(entry.visit.isLimited, isTrue);
    expect(entry.visit.memo, 'メモ');

    await repository.checkIn(
      shop: const ShopInput(shopId: 'shop', name: '麺屋'),
      at: eatenAt,
    );
    expect((await repository.activeCheckin())!.name, '麺屋');
  });

  test('バージョン2の「昼のみ」「通常」の店を、営業の条件に引き継ぐ', () async {
    final seconds = DateTime(2026, 9, 30).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _v1Schema) {
            raw.execute(statement);
          }
          raw.execute(
            'CREATE TABLE active_checkins (id INTEGER NOT NULL, '
            'shop_id TEXT, osm_id TEXT, name TEXT NOT NULL, latitude REAL, '
            'longitude REAL, checked_in_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(
            'INSERT INTO shops VALUES '
            "('lunch', '昼の店', NULL, NULL, NULL, 'lunchOnly', $seconds), "
            "('normal', '普通の店', NULL, NULL, NULL, 'normal', $seconds)",
          );
          raw.execute('PRAGMA user_version = 2');
        },
      ),
    );
    addTearDown(database.close);

    final shops = await RecordRepository(database).allShops();

    expect(
      {for (final shop in shops) shop.name: shop.hoursConditions},
      {
        '昼の店': {HoursCondition.lunchOnly},
        '普通の店': <HoursCondition>{},
      },
    );
  });

  test('バージョン3の店に、攻略メモの列を足す', () async {
    final seconds = DateTime(2026, 10, 1).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
            'latitude REAL, longitude REAL, osm_id TEXT, '
            "hours_conditions TEXT NOT NULL DEFAULT '', "
            'created_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(_v1Schema[1]);
          raw.execute(
            'CREATE TABLE active_checkins (id INTEGER NOT NULL, '
            'shop_id TEXT, osm_id TEXT, name TEXT NOT NULL, latitude REAL, '
            'longitude REAL, checked_in_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', NULL, NULL, NULL, 'weekdaysOnly', $seconds)",
          );
          raw.execute('PRAGMA user_version = 3');
        },
      ),
    );
    addTearDown(database.close);
    final repository = RecordRepository(database);

    final shop = (await repository.allShops()).single;
    expect(shop.hoursConditions, {HoursCondition.weekdaysOnly});
    expect(shop.strategyMemo, '');

    await repository.setShopMemo('shop', '平日の昼だけ');
    expect((await repository.allShops()).single.strategyMemo, '平日の昼だけ');
  });

  test('バージョン4の店と並び中の店に、出所の列を足す', () async {
    final seconds = DateTime(2026, 10, 2).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
            'latitude REAL, longitude REAL, osm_id TEXT, '
            "hours_conditions TEXT NOT NULL DEFAULT '', "
            "strategy_memo TEXT NOT NULL DEFAULT '', "
            'created_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(_v1Schema[1]);
          raw.execute(
            'CREATE TABLE active_checkins (id INTEGER NOT NULL, '
            'shop_id TEXT, osm_id TEXT, name TEXT NOT NULL, latitude REAL, '
            'longitude REAL, checked_in_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', NULL, NULL, NULL, '', 'メモ', $seconds)",
          );
          raw.execute(
            'INSERT INTO active_checkins VALUES '
            "(1, NULL, NULL, '並んでいる店', 35.0, 139.0, $seconds)",
          );
          raw.execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(database.close);
    final repository = RecordRepository(database);

    final shop = (await repository.allShops()).single;
    expect(shop.strategyMemo, 'メモ');
    expect(shop.dataSource, isNull);
    final checkin = (await repository.activeCheckin())!;
    expect(checkin.name, '並んでいる店');
    expect(checkin.dataSource, isNull);
  });

  test('バージョン5に願掛け帳の表を足し、記録はそのまま残す', () async {
    final seconds = DateTime(2026, 10, 3).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
            'latitude REAL, longitude REAL, osm_id TEXT, '
            "hours_conditions TEXT NOT NULL DEFAULT '', "
            "strategy_memo TEXT NOT NULL DEFAULT '', data_source TEXT, "
            'created_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(_v1Schema[1]);
          raw.execute(
            'CREATE TABLE active_checkins (id INTEGER NOT NULL, '
            'shop_id TEXT, osm_id TEXT, name TEXT NOT NULL, latitude REAL, '
            'longitude REAL, data_source TEXT, '
            'checked_in_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', NULL, NULL, NULL, '', '', NULL, $seconds)",
          );
          raw.execute(
            "INSERT INTO visits VALUES ('visit', 'shop', 'eaten', "
            "NULL, NULL, $seconds, NULL, 4, 0, 0, '', $seconds)",
          );
          raw.execute('PRAGMA user_version = 5');
        },
      ),
    );
    addTearDown(database.close);

    final entry = (await RecordRepository(database).watchVisits().first).single;
    expect(entry.shop.name, '麺屋');
    final wishes = WishRepository(database);
    await wishes.addWish(
      shop: const ShopInput(name: 'はやし田'),
      now: DateTime(2026, 10, 3),
    );
    expect((await wishes.watchWishes().first).single.name, 'はやし田');
  });

  test('バージョン6の店に地名の列を足し、店はそのまま残す', () async {
    final seconds = DateTime(2026, 10, 3).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
            'latitude REAL, longitude REAL, osm_id TEXT, '
            "hours_conditions TEXT NOT NULL DEFAULT '', "
            "strategy_memo TEXT NOT NULL DEFAULT '', data_source TEXT, "
            'created_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(_v1Schema[1]);
          raw.execute(
            'CREATE TABLE active_checkins (id INTEGER NOT NULL, '
            'shop_id TEXT, osm_id TEXT, name TEXT NOT NULL, latitude REAL, '
            'longitude REAL, data_source TEXT, '
            'checked_in_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(
            'CREATE TABLE wishes (id TEXT NOT NULL, shop_id TEXT, '
            'osm_id TEXT, name TEXT NOT NULL, latitude REAL, longitude REAL, '
            "data_source TEXT, \"trigger\" TEXT NOT NULL DEFAULT '', "
            "note TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, "
            'fulfilled_visit_id TEXT, PRIMARY KEY (id))',
          );
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', 35.0, 139.0, NULL, '', '', NULL, $seconds)",
          );
          raw.execute('PRAGMA user_version = 6');
        },
      ),
    );
    addTearDown(database.close);
    final repository = RecordRepository(database);

    expect((await repository.allShops()).single.area, isNull);
    await repository.setShopArea('shop', '厚木市');
    expect((await repository.allShops()).single.area, '厚木市');
  });

  test('バージョン7の願に店の条件の列を足し、願はそのまま残す', () async {
    final seconds = DateTime(2026, 10, 3).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
            'latitude REAL, longitude REAL, osm_id TEXT, '
            "hours_conditions TEXT NOT NULL DEFAULT '', "
            "strategy_memo TEXT NOT NULL DEFAULT '', data_source TEXT, "
            'area TEXT, created_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(_v1Schema[1]);
          raw.execute(
            'CREATE TABLE active_checkins (id INTEGER NOT NULL, '
            'shop_id TEXT, osm_id TEXT, name TEXT NOT NULL, latitude REAL, '
            'longitude REAL, data_source TEXT, '
            'checked_in_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(
            'CREATE TABLE wishes (id TEXT NOT NULL, shop_id TEXT, '
            'osm_id TEXT, name TEXT NOT NULL, latitude REAL, longitude REAL, '
            "data_source TEXT, \"trigger\" TEXT NOT NULL DEFAULT '', "
            "note TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, "
            'fulfilled_visit_id TEXT, PRIMARY KEY (id))',
          );
          raw.execute(
            'INSERT INTO wishes VALUES '
            "('wish', NULL, NULL, 'はやし田', NULL, NULL, NULL, "
            "'同僚に聞いた', '', $seconds, NULL)",
          );
          raw.execute('PRAGMA user_version = 7');
        },
      ),
    );
    addTearDown(database.close);
    final wishes = WishRepository(database);

    final wish = (await wishes.watchWishes().first).single;
    expect(wish.trigger, '同僚に聞いた');
    expect(wish.hoursConditions, isEmpty);
    await wishes.updateWish(
      'wish',
      trigger: '同僚に聞いた',
      note: '',
      hoursConditions: {HoursCondition.lunchOnly},
    );
    expect((await wishes.watchWishes().first).single.hoursConditions, {
      HoursCondition.lunchOnly,
    });
  });

  test('バージョン8に拠点の表を足し、記録と願はそのまま残す', () async {
    final eatenAt = DateTime(2026, 10, 4, 12);
    final seconds = eatenAt.millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
            'latitude REAL, longitude REAL, osm_id TEXT, '
            "hours_conditions TEXT NOT NULL DEFAULT '', "
            "strategy_memo TEXT NOT NULL DEFAULT '', data_source TEXT, "
            'area TEXT, created_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(_v1Schema[1]);
          raw.execute(
            'CREATE TABLE active_checkins (id INTEGER NOT NULL, '
            'shop_id TEXT, osm_id TEXT, name TEXT NOT NULL, latitude REAL, '
            'longitude REAL, data_source TEXT, '
            'checked_in_at INTEGER NOT NULL, PRIMARY KEY (id))',
          );
          raw.execute(
            'CREATE TABLE wishes (id TEXT NOT NULL, shop_id TEXT, '
            'osm_id TEXT, name TEXT NOT NULL, latitude REAL, longitude REAL, '
            "data_source TEXT, \"trigger\" TEXT NOT NULL DEFAULT '', "
            "note TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, "
            'fulfilled_visit_id TEXT, '
            "hours_conditions TEXT NOT NULL DEFAULT '', PRIMARY KEY (id))",
          );
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', 35.0, 139.0, NULL, '', '', NULL, NULL, $seconds)",
          );
          raw.execute(
            "INSERT INTO visits VALUES ('visit', 'shop', 'eaten', "
            "NULL, NULL, $seconds, 'shoyu', 4, 0, 0, '', $seconds)",
          );
          raw.execute(
            'INSERT INTO wishes VALUES '
            "('wish', NULL, NULL, 'はやし田', NULL, NULL, NULL, "
            "'', '', $seconds, NULL, 'lunchOnly')",
          );
          raw.execute('PRAGMA user_version = 8');
        },
      ),
    );
    addTearDown(database.close);

    expect(
      (await RecordRepository(database).watchVisits().first).single.visit.id,
      'visit',
    );
    expect(
      (await WishRepository(database).watchWishes().first).single.name,
      'はやし田',
    );
    final homeBases = HomeBaseRepository(database);
    expect(await homeBases.allSettings(), isEmpty);
    await homeBases.setHomeBase(
      name: '横浜駅',
      latitude: 35.466,
      longitude: 139.622,
      now: DateTime(2026, 10, 5, 9),
    );
    final saved = (await homeBases.watchSettings().first).single;
    expect(saved.name, '横浜駅');
    expect(saved.setAt, DateTime(2026, 10, 5, 9));
  });
}
