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

/// 今は使っていない店の条件の列に、保存したままの値。
Future<Map<String, String>> _storedConditions(
  AppDatabase database,
  String table,
) async => {
  for (final row
      in await database
          .customSelect('SELECT id, hours_conditions FROM $table')
          .get())
    row.read<String>('id'): row.read<String>('hours_conditions'),
};

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
    // 以前の「週3日以下」は、条件「週3日以下」として表に残す（今は使っていない）。
    expect(await _storedConditions(database, 'shops'), {'shop': 'fewDays'});
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

  test('バージョン2の「昼のみ」「通常」の店を、営業の条件として表に残す', () async {
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

    expect(shops.map((s) => s.name), unorderedEquals(['昼の店', '普通の店']));
    expect(await _storedConditions(database, 'shops'), {
      'lunch': 'lunchOnly',
      'normal': '',
    });
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
    expect(shop.strategyMemo, '');
    expect(await _storedConditions(database, 'shops'), {
      'shop': 'weekdaysOnly',
    });

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
    await repository.setShopArea('shop', '新宿区');
    expect((await repository.allShops()).single.area, '新宿区');
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
    expect(await _storedConditions(database, 'wishes'), {'wish': ''});
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

  test('バージョン9の店に名店の印の列を足し、記録・店・願・拠点・並び・写真のパスはそのまま残す', () async {
    final eatenAt = DateTime(2026, 10, 5, 12);
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
            'CREATE TABLE home_base_settings (id TEXT NOT NULL, '
            'name TEXT NOT NULL, latitude REAL NOT NULL, '
            'longitude REAL NOT NULL, set_at INTEGER NOT NULL, '
            'PRIMARY KEY (id))',
          );
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', 35.0, 139.0, 'node/1', 'lunchOnly,irregular', "
            "'券売機は現金のみ', NULL, '新宿区', $seconds), "
            "('other', '手入力の店', NULL, NULL, NULL, '', '', NULL, NULL, "
            '$seconds)',
          );
          raw.execute(
            "INSERT INTO visits VALUES ('visit', 'shop', 'eaten', "
            "'photos/a.jpg', $seconds, $seconds, 'shoyu', 4, 1, 0, 'メモ', "
            '$seconds), '
            "('retreat', 'other', 'retreated', NULL, NULL, $seconds, NULL, "
            "NULL, 0, 0, '', $seconds)",
          );
          raw.execute(
            'INSERT INTO wishes VALUES '
            "('wish', NULL, 'node/2', 'はやし田', 35.1, 139.1, NULL, "
            "'同僚に聞いた', '煮干し', $seconds, NULL, 'nightOnly')",
          );
          raw.execute(
            'INSERT INTO home_base_settings VALUES '
            "('base', '横浜駅', 35.466, 139.622, $seconds)",
          );
          raw.execute(
            'INSERT INTO active_checkins VALUES '
            "(1, 'shop', 'node/1', '麺屋', 35.0, 139.0, NULL, $seconds)",
          );
          raw.execute('PRAGMA user_version = 9');
        },
      ),
    );
    addTearDown(database.close);
    final repository = RecordRepository(database);

    final entries = await repository.watchVisits().first;
    expect(
      entries.map((e) => e.visit.id),
      unorderedEquals(['visit', 'retreat']),
    );
    final visit = entries.singleWhere((e) => e.visit.id == 'visit');
    expect(visit.visit.photoPath, 'photos/a.jpg');
    expect(visit.visit.checkedInAt, eatenAt);
    expect(visit.visit.style, RamenStyle.shoyu);
    expect(visit.visit.memo, 'メモ');
    expect(visit.shop.osmId, 'node/1');
    expect(visit.shop.strategyMemo, '券売機は現金のみ');
    expect(visit.shop.area, '新宿区');
    expect(visit.shop.isFamous, isFalse);
    final wish = (await WishRepository(database).watchWishes().first).single;
    expect(wish.osmId, 'node/2');
    expect(wish.note, '煮干し');
    expect(
      (await HomeBaseRepository(database).allSettings()).single.name,
      '横浜駅',
    );
    expect((await repository.activeCheckin())!.name, '麺屋');
    // 使わなくなった店の条件も、表には残っている。
    expect(await _storedConditions(database, 'shops'), {
      'shop': 'lunchOnly,irregular',
      'other': '',
    });
    expect(await _storedConditions(database, 'wishes'), {'wish': 'nightOnly'});

    await repository.setShopFamous('shop', true);
    expect(
      (await repository.allShops()).singleWhere((s) => s.id == 'shop').isFamous,
      isTrue,
    );
  });
}
