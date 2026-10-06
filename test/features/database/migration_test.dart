import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

// これまでの版のテーブル定義。版を上げたら、上げる前の版をここに足す（足さないとテストが失敗する）。
const _shopsV1 = '''
CREATE TABLE shops (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  latitude REAL,
  longitude REAL,
  osm_id TEXT,
  hours_type TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (id)
)''';

const _shopsV3 =
    'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
    'latitude REAL, longitude REAL, osm_id TEXT, '
    "hours_conditions TEXT NOT NULL DEFAULT '', "
    'created_at INTEGER NOT NULL, PRIMARY KEY (id))';

const _shopsV4 =
    'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
    'latitude REAL, longitude REAL, osm_id TEXT, '
    "hours_conditions TEXT NOT NULL DEFAULT '', "
    "strategy_memo TEXT NOT NULL DEFAULT '', "
    'created_at INTEGER NOT NULL, PRIMARY KEY (id))';

const _shopsV5 =
    'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
    'latitude REAL, longitude REAL, osm_id TEXT, '
    "hours_conditions TEXT NOT NULL DEFAULT '', "
    "strategy_memo TEXT NOT NULL DEFAULT '', data_source TEXT, "
    'created_at INTEGER NOT NULL, PRIMARY KEY (id))';

const _shopsV7 =
    'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
    'latitude REAL, longitude REAL, osm_id TEXT, '
    "hours_conditions TEXT NOT NULL DEFAULT '', "
    "strategy_memo TEXT NOT NULL DEFAULT '', data_source TEXT, "
    'area TEXT, created_at INTEGER NOT NULL, PRIMARY KEY (id))';

const _shopsV10 =
    'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
    'latitude REAL, longitude REAL, osm_id TEXT, '
    "hours_conditions TEXT NOT NULL DEFAULT '', "
    "strategy_memo TEXT NOT NULL DEFAULT '', data_source TEXT, "
    'area TEXT, created_at INTEGER NOT NULL, '
    'is_famous INTEGER NOT NULL DEFAULT 0 CHECK (is_famous IN (0, 1)), '
    'PRIMARY KEY (id))';

const _shopsV11 =
    'CREATE TABLE shops (id TEXT NOT NULL, name TEXT NOT NULL, '
    'latitude REAL, longitude REAL, osm_id TEXT, '
    'is_famous INTEGER NOT NULL DEFAULT 0 CHECK (is_famous IN (0, 1)), '
    "strategy_memo TEXT NOT NULL DEFAULT '', data_source TEXT, "
    'area TEXT, created_at INTEGER NOT NULL, PRIMARY KEY (id))';

const _visits = '''
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
)''';

const _checkinsV2 =
    'CREATE TABLE active_checkins (id INTEGER NOT NULL, '
    'shop_id TEXT, osm_id TEXT, name TEXT NOT NULL, latitude REAL, '
    'longitude REAL, checked_in_at INTEGER NOT NULL, PRIMARY KEY (id))';

const _checkinsV5 =
    'CREATE TABLE active_checkins (id INTEGER NOT NULL, '
    'shop_id TEXT, osm_id TEXT, name TEXT NOT NULL, latitude REAL, '
    'longitude REAL, data_source TEXT, '
    'checked_in_at INTEGER NOT NULL, PRIMARY KEY (id))';

const _wishesV6 =
    'CREATE TABLE wishes (id TEXT NOT NULL, shop_id TEXT, '
    'osm_id TEXT, name TEXT NOT NULL, latitude REAL, longitude REAL, '
    "data_source TEXT, \"trigger\" TEXT NOT NULL DEFAULT '', "
    "note TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, "
    'fulfilled_visit_id TEXT, PRIMARY KEY (id))';

const _wishesV8 =
    'CREATE TABLE wishes (id TEXT NOT NULL, shop_id TEXT, '
    'osm_id TEXT, name TEXT NOT NULL, latitude REAL, longitude REAL, '
    "data_source TEXT, \"trigger\" TEXT NOT NULL DEFAULT '', "
    "note TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, "
    'fulfilled_visit_id TEXT, '
    "hours_conditions TEXT NOT NULL DEFAULT '', PRIMARY KEY (id))";

const _wishesV12 =
    'CREATE TABLE wishes (id TEXT NOT NULL, shop_id TEXT, '
    'osm_id TEXT, name TEXT NOT NULL, latitude REAL, longitude REAL, '
    "data_source TEXT, \"trigger\" TEXT NOT NULL DEFAULT '', "
    "note TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, "
    'fulfilled_visit_id TEXT, link TEXT, PRIMARY KEY (id))';

const _homeBasesV9 =
    'CREATE TABLE home_base_settings (id TEXT NOT NULL, '
    'name TEXT NOT NULL, latitude REAL NOT NULL, '
    'longitude REAL NOT NULL, set_at INTEGER NOT NULL, '
    'PRIMARY KEY (id))';

const _schemas = <int, List<String>>{
  1: [_shopsV1, _visits],
  2: [_shopsV1, _visits, _checkinsV2],
  3: [_shopsV3, _visits, _checkinsV2],
  4: [_shopsV4, _visits, _checkinsV2],
  5: [_shopsV5, _visits, _checkinsV5],
  6: [_shopsV5, _visits, _checkinsV5, _wishesV6],
  7: [_shopsV7, _visits, _checkinsV5, _wishesV6],
  8: [_shopsV7, _visits, _checkinsV5, _wishesV8],
  9: [_shopsV7, _visits, _checkinsV5, _wishesV8, _homeBasesV9],
  10: [_shopsV10, _visits, _checkinsV5, _wishesV8, _homeBasesV9],
  11: [_shopsV11, _visits, _checkinsV5, _wishesV6, _homeBasesV9],
  12: [_shopsV11, _visits, _checkinsV5, _wishesV12, _homeBasesV9],
};

/// 表の列の名前。店の条件（hours_conditions）や整理券（has_ticket）の列が消えたことを確かめる。
Future<List<String>> _columns(AppDatabase database, String table) async => [
  for (final row
      in await database.customSelect('PRAGMA table_info($table)').get())
    row.read<String>('name'),
];

void main() {
  test('バージョン1のデータを残したまま、チェックインのテーブルを追加する', () async {
    final eatenAt = DateTime(2026, 9, 30, 12);
    final seconds = eatenAt.millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemas[1]!) {
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
    // 以前の営業時間の種類は持ち越さない。
    expect(
      await _columns(database, 'shops'),
      isNot(contains('hours_conditions')),
    );
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

  test('バージョン2の店は、営業時間の種類を持ち越さずにそのまま残す', () async {
    final seconds = DateTime(2026, 9, 30).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemas[2]!) {
            raw.execute(statement);
          }
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
    expect(
      await _columns(database, 'shops'),
      isNot(contains('hours_conditions')),
    );
  });

  test('バージョン3の店に、店の覚え書きの列を足す', () async {
    final seconds = DateTime(2026, 10, 1).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemas[3]!) {
            raw.execute(statement);
          }
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
    expect(
      await _columns(database, 'shops'),
      isNot(contains('hours_conditions')),
    );

    await repository.setShopMemo('shop', '平日の昼だけ');
    expect((await repository.allShops()).single.strategyMemo, '平日の昼だけ');
  });

  test('バージョン4の店と並び中の店に、出所の列を足す', () async {
    final seconds = DateTime(2026, 10, 2).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemas[4]!) {
            raw.execute(statement);
          }
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
          for (final statement in _schemas[5]!) {
            raw.execute(statement);
          }
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
          for (final statement in _schemas[6]!) {
            raw.execute(statement);
          }
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

  test('バージョン7の願はそのまま残す', () async {
    final seconds = DateTime(2026, 10, 3).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemas[7]!) {
            raw.execute(statement);
          }
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
    expect(
      await _columns(database, 'wishes'),
      isNot(contains('hours_conditions')),
    );
  });

  test('バージョン8に拠点の表を足し、記録と願はそのまま残す', () async {
    final eatenAt = DateTime(2026, 10, 4, 12);
    final seconds = eatenAt.millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemas[8]!) {
            raw.execute(statement);
          }
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
          for (final statement in _schemas[9]!) {
            raw.execute(statement);
          }
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
    // 店の条件の列は消え、ほかの値はそのまま残る。
    expect(
      await _columns(database, 'shops'),
      isNot(contains('hours_conditions')),
    );
    expect(
      await _columns(database, 'wishes'),
      isNot(contains('hours_conditions')),
    );

    await repository.setShopFamous('shop', true);
    expect(
      (await repository.allShops()).singleWhere((s) => s.id == 'shop').isFamous,
      isTrue,
    );
  });

  test('バージョン10の店と願から店の条件の列を消し、名店の印・記録・願はそのまま残す', () async {
    final seconds = DateTime(2026, 10, 6, 12).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemas[10]!) {
            raw.execute(statement);
          }
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', 35.0, 139.0, 'node/1', 'lunchOnly', "
            "'券売機は現金のみ', NULL, '新宿区', $seconds, 1)",
          );
          raw.execute(
            "INSERT INTO visits VALUES ('visit', 'shop', 'eaten', "
            "'photos/a.jpg', NULL, $seconds, 'miso', 5, 0, 0, 'うまい', "
            '$seconds)',
          );
          raw.execute(
            'INSERT INTO wishes VALUES '
            "('wish', 'shop', NULL, '麺屋', 35.0, 139.0, NULL, "
            "'友人', 'また行く', $seconds, 'visit', 'nightOnly')",
          );
          raw.execute('PRAGMA user_version = 10');
        },
      ),
    );
    addTearDown(database.close);
    final repository = RecordRepository(database);

    final entry = (await repository.watchVisits().first).single;
    expect(entry.visit.photoPath, 'photos/a.jpg');
    expect(entry.visit.memo, 'うまい');
    expect(entry.visit.rating, 5);
    expect(entry.shop.strategyMemo, '券売機は現金のみ');
    expect(entry.shop.area, '新宿区');
    expect(entry.shop.isFamous, isTrue);
    final wish = (await WishRepository(database).watchWishes().first).single;
    expect(wish.fulfilledVisitId, 'visit');
    expect(wish.trigger, '友人');
    expect(
      await _columns(database, 'shops'),
      isNot(contains('hours_conditions')),
    );
    expect(
      await _columns(database, 'wishes'),
      isNot(contains('hours_conditions')),
    );
  });

  test('バージョン11の願にリンクの列を足し、記録・店・願はそのまま残す', () async {
    final seconds = DateTime(2026, 10, 6, 12).millisecondsSinceEpoch ~/ 1000;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemas[11]!) {
            raw.execute(statement);
          }
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', 43.06, 141.35, 'node/1', 1, "
            "'券売機は現金のみ', NULL, '札幌市中央区', $seconds)",
          );
          raw.execute(
            "INSERT INTO visits VALUES ('visit', 'shop', 'eaten', "
            "'photos/a.jpg', NULL, $seconds, 'miso', 5, 0, 0, 'うまい', "
            '$seconds)',
          );
          raw.execute(
            'INSERT INTO wishes VALUES '
            "('done', 'shop', NULL, '麺屋', 43.06, 141.35, NULL, "
            "'友人', 'また行く', $seconds, 'visit'), "
            "('wish', NULL, NULL, '中華そば', NULL, NULL, NULL, "
            "'テレビ', '', $seconds, NULL)",
          );
          raw.execute('PRAGMA user_version = 11');
        },
      ),
    );
    addTearDown(database.close);

    final entry = (await RecordRepository(database).watchVisits().first).single;
    expect(entry.visit.photoPath, 'photos/a.jpg');
    expect(entry.visit.memo, 'うまい');
    expect(entry.shop.strategyMemo, '券売機は現金のみ');
    expect(entry.shop.isFamous, isTrue);
    final wishes = {
      for (final wish in await WishRepository(database).watchWishes().first)
        wish.id: wish,
    };
    expect(wishes.keys, unorderedEquals(['done', 'wish']));
    expect(wishes['done']!.fulfilledVisitId, 'visit');
    expect(wishes['done']!.trigger, '友人');
    expect(wishes['wish']!.trigger, 'テレビ');
    expect(wishes.values.map((w) => w.link), everyElement(isNull));
    expect(await _columns(database, 'wishes'), contains('link'));
  });

  test('バージョン12の記録から整理券の列を消し、記録・店・願・拠点・並びはそのまま残す', () async {
    final seconds = DateTime(2026, 10, 6, 12).millisecondsSinceEpoch ~/ 1000;
    final checkedIn = seconds - 1800;
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemas[12]!) {
            raw.execute(statement);
          }
          raw.execute(
            'INSERT INTO shops VALUES '
            "('shop', '麺屋', 43.06, 141.35, 'node/1', 1, "
            "'券売機は現金のみ', NULL, '札幌市中央区', $seconds)",
          );
          raw.execute(
            'INSERT INTO visits VALUES '
            "('visit', 'shop', 'eaten', 'photos/a.jpg', $checkedIn, "
            "$seconds, 'miso', 5, 1, 1, 'うまい', $seconds), "
            "('retreat', 'shop', 'retreated', NULL, NULL, $seconds, "
            "NULL, NULL, 0, 0, '売り切れ', $seconds)",
          );
          raw.execute(
            'INSERT INTO wishes VALUES '
            "('done', 'shop', NULL, '麺屋', 43.06, 141.35, NULL, "
            "'友人', 'また行く', $seconds, 'visit', 'https://example.com/a'), "
            "('wish', NULL, NULL, '中華そば', NULL, NULL, NULL, "
            "'テレビ', '', $seconds, NULL, NULL)",
          );
          raw.execute(
            'INSERT INTO home_base_settings VALUES '
            "('base', '札幌駅', 43.068, 141.350, $seconds)",
          );
          raw.execute(
            'INSERT INTO active_checkins VALUES '
            "(1, 'shop', 'node/1', '麺屋', 43.06, 141.35, NULL, $checkedIn)",
          );
          raw.execute('PRAGMA user_version = 12');
        },
      ),
    );
    addTearDown(database.close);

    final repository = RecordRepository(database);
    final data = await repository.exportAll();
    final visits = {for (final visit in data.visits) visit.id: visit};
    expect(visits.keys, unorderedEquals(['visit', 'retreat']));
    final visit = visits['visit']!;
    expect(visit.shopId, 'shop');
    expect(visit.result, VisitResult.eaten);
    expect(visit.photoPath, 'photos/a.jpg');
    expect(
      visit.checkedInAt,
      DateTime.fromMillisecondsSinceEpoch(checkedIn * 1000),
    );
    expect(visit.eatenAt, DateTime(2026, 10, 6, 12));
    expect(visit.style, RamenStyle.miso);
    expect(visit.rating, 5);
    expect(visit.isLimited, isTrue);
    expect(visit.memo, 'うまい');
    expect(visit.createdAt, DateTime(2026, 10, 6, 12));
    expect(visits['retreat']!.result, VisitResult.retreated);
    expect(visits['retreat']!.memo, '売り切れ');
    expect(await _columns(database, 'visits'), isNot(contains('has_ticket')));

    final shop = data.shops.single;
    expect(shop.strategyMemo, '券売機は現金のみ');
    expect(shop.isFamous, isTrue);
    expect(shop.area, '札幌市中央区');
    final wishes = {for (final wish in data.wishes) wish.id: wish};
    expect(wishes.keys, unorderedEquals(['done', 'wish']));
    expect(wishes['done']!.fulfilledVisitId, 'visit');
    expect(wishes['done']!.link, 'https://example.com/a');
    expect(wishes['wish']!.trigger, 'テレビ');
    expect(data.homeBases.single.name, '札幌駅');
    final checkin = await repository.activeCheckin();
    expect(checkin!.shopId, 'shop');
    expect(checkin.name, '麺屋');
  });

  test('これまでのすべての版に、移行のテストがある', () {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(_schemas.keys.toSet(), {
      for (var version = 1; version < database.schemaVersion; version++)
        version,
    });
  });

  for (final version in _schemas.keys) {
    group('バージョン$versionから今の版へ', () {
      late AppDatabase database;
      late Map<String, Set<String>> oldColumns;

      setUp(() {
        oldColumns = {};
        database = AppDatabase(
          NativeDatabase.memory(
            setup: (raw) {
              for (final statement in _schemas[version]!) {
                raw.execute(statement);
              }
              for (final MapEntry(key: table, value: rows) in _seed.entries) {
                final columns = {
                  for (final row in raw.select('PRAGMA table_info($table)'))
                    row['name'] as String,
                };
                if (columns.isEmpty) continue;
                oldColumns[table] = columns;
                for (final row in rows) {
                  final names = row.keys.where(columns.contains).toList();
                  raw.execute(
                    'INSERT INTO $table '
                    '(${names.map((n) => '"$n"').join(', ')}) '
                    'VALUES (${List.filled(names.length, '?').join(', ')})',
                    [for (final name in names) row[name]],
                  );
                }
              }
              raw.execute('PRAGMA user_version = $version');
            },
          ),
        );
        addTearDown(database.close);
      });

      bool had(String table, String column) =>
          oldColumns[table]?.contains(column) ?? false;

      test('表の形が、新しく入れたときと同じになる', () async {
        final migrated = await _schemaOf(database);
        await database.close();
        final fresh = AppDatabase(NativeDatabase.memory());
        addTearDown(fresh.close);

        expect(migrated, await _schemaOf(fresh));
      });

      test('記録・写真のパス・店・願・拠点・並びの値が残る', () async {
        final repository = RecordRepository(database);
        final data = await repository.exportAll();

        final visits = {for (final visit in data.visits) visit.id: visit};
        expect(visits.keys, unorderedEquals(['visit', 'retreat']));
        final visit = visits['visit']!;
        expect(visit.shopId, 'shop');
        expect(visit.result, VisitResult.eaten);
        expect(visit.photoPath, 'photos/a.jpg');
        expect(visit.checkedInAt, _checkedInAt);
        expect(visit.eatenAt, _eatenAt);
        expect(visit.style, RamenStyle.shoyu);
        expect(visit.rating, 4);
        expect(visit.isLimited, isTrue);
        expect(visit.memo, '醤油が澄んでいた');
        expect(visit.createdAt, _createdAt);
        final retreat = visits['retreat']!;
        expect(retreat.shopId, 'manual');
        expect(retreat.result, VisitResult.retreated);
        expect(retreat.photoPath, isNull);
        expect(retreat.rating, isNull);
        expect(
          await _columns(database, 'visits'),
          isNot(contains('has_ticket')),
        );

        final shops = {for (final shop in data.shops) shop.id: shop};
        expect(shops.keys, unorderedEquals(['shop', 'manual']));
        final shop = shops['shop']!;
        expect(shop.name, '麺屋');
        expect(shop.latitude, 35.0);
        expect(shop.longitude, 139.0);
        expect(shop.osmId, 'node/1');
        expect(shop.createdAt, _createdAt);
        expect(
          shop.strategyMemo,
          had('shops', 'strategy_memo') ? '券売機は現金のみ' : '',
        );
        expect(shop.area, had('shops', 'area') ? '新宿区' : isNull);
        expect(shop.isFamous, had('shops', 'is_famous'));
        expect(
          shop.dataSource?.licenses,
          had('shops', 'data_source') ? ['CC BY 4.0'] : isNull,
        );
        expect(shops['manual']!.latitude, isNull);

        final checkin = await repository.activeCheckin();
        if (oldColumns.containsKey('active_checkins')) {
          expect(checkin!.shopId, 'shop');
          expect(checkin.name, '麺屋');
          expect(checkin.latitude, 35.0);
          expect(checkin.checkedInAt, _checkedInAt);
          expect(
            checkin.dataSource?.attributions,
            had('active_checkins', 'data_source') ? ['新宿区'] : isNull,
          );
        } else {
          expect(checkin, isNull);
        }

        if (oldColumns.containsKey('wishes')) {
          final wishes = {for (final wish in data.wishes) wish.id: wish};
          expect(wishes.keys, unorderedEquals(['wish', 'done']));
          final wish = wishes['wish']!;
          expect(wish.name, 'はやし田');
          expect(wish.osmId, 'node/2');
          expect(wish.latitude, 35.1);
          expect(wish.trigger, '同僚に聞いた');
          expect(wish.note, '煮干し');
          expect(wish.dataSource?.licenses, ['CC BY 4.0']);
          expect(wish.createdAt, _createdAt);
          expect(wish.link, isNull);
          expect(wishes['done']!.shopId, 'shop');
          expect(wishes['done']!.fulfilledVisitId, 'visit');
        } else {
          expect(data.wishes, isEmpty);
        }

        if (oldColumns.containsKey('home_base_settings')) {
          final base = data.homeBases.single;
          expect(base.name, '横浜駅');
          expect(base.latitude, 35.466);
          expect(base.setAt, _createdAt);
        } else {
          expect(data.homeBases, isEmpty);
        }
      });

      test('移行のあとも、記録・願・拠点を足せる', () async {
        final repository = RecordRepository(database);
        await repository.saveEatenVisit(
          shop: const ShopInput(shopId: 'shop', name: '麺屋'),
          eatenAt: DateTime(2026, 10, 6, 12),
          now: DateTime(2026, 10, 6, 12),
        );
        await WishRepository(database).addWish(
          shop: const ShopInput(name: '中華そば'),
          now: DateTime(2026, 10, 6),
        );
        await HomeBaseRepository(database).setHomeBase(
          name: '札幌',
          latitude: 43.06,
          longitude: 141.35,
          now: DateTime(2026, 10, 6),
        );

        final data = await repository.exportAll();
        expect(data.visits, hasLength(3));
        expect(data.wishes.map((w) => w.name), contains('中華そば'));
        expect(data.homeBases.map((b) => b.name), contains('札幌'));
      });
    });
  }
}

final _eatenAt = DateTime(2026, 9, 30, 12);
final _checkedInAt = DateTime(2026, 9, 30, 11, 20);
final _createdAt = DateTime(2026, 9, 30, 12, 5);

int _seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

final _source = jsonEncode({
  'licenses': ['CC BY 4.0'],
  'attributions': ['新宿区'],
});

/// どの版にも入れる記録。その版に無い列の値は入れない。
final Map<String, List<Map<String, Object?>>> _seed = {
  'shops': [
    {
      'id': 'shop',
      'name': '麺屋',
      'latitude': 35.0,
      'longitude': 139.0,
      'osm_id': 'node/1',
      'hours_type': 'fewDays',
      'hours_conditions': 'lunchOnly,irregular',
      'strategy_memo': '券売機は現金のみ',
      'data_source': _source,
      'area': '新宿区',
      'is_famous': 1,
      'created_at': _seconds(_createdAt),
    },
    {
      'id': 'manual',
      'name': '手入力の店',
      'hours_type': 'normal',
      'created_at': _seconds(_createdAt),
    },
  ],
  'visits': [
    {
      'id': 'visit',
      'shop_id': 'shop',
      'result': 'eaten',
      'photo_path': 'photos/a.jpg',
      'checked_in_at': _seconds(_checkedInAt),
      'eaten_at': _seconds(_eatenAt),
      'style': 'shoyu',
      'rating': 4,
      'is_limited': 1,
      'has_ticket': 1,
      'memo': '醤油が澄んでいた',
      'created_at': _seconds(_createdAt),
    },
    {
      'id': 'retreat',
      'shop_id': 'manual',
      'result': 'retreated',
      'eaten_at': _seconds(_eatenAt),
      'created_at': _seconds(_createdAt),
    },
  ],
  'active_checkins': [
    {
      'id': 1,
      'shop_id': 'shop',
      'osm_id': 'node/1',
      'name': '麺屋',
      'latitude': 35.0,
      'longitude': 139.0,
      'data_source': _source,
      'checked_in_at': _seconds(_checkedInAt),
    },
  ],
  'wishes': [
    {
      'id': 'wish',
      'osm_id': 'node/2',
      'name': 'はやし田',
      'latitude': 35.1,
      'longitude': 139.1,
      'data_source': _source,
      'trigger': '同僚に聞いた',
      'note': '煮干し',
      'created_at': _seconds(_createdAt),
      'hours_conditions': 'nightOnly',
    },
    {
      'id': 'done',
      'shop_id': 'shop',
      'name': '麺屋',
      'created_at': _seconds(_createdAt),
      'fulfilled_visit_id': 'visit',
    },
  ],
  'home_base_settings': [
    {
      'id': 'base',
      'name': '横浜駅',
      'latitude': 35.466,
      'longitude': 139.622,
      'set_at': _seconds(_createdAt),
    },
  ],
};

/// 表ごとの列（名前・型・必須・初期値・主キー）。列の順番は問わない。
Future<Map<String, Set<String>>> _schemaOf(AppDatabase database) async {
  final tables = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return {
    for (final table in tables.map((row) => row.read<String>('name')))
      table: {
        for (final column
            in await database.customSelect('PRAGMA table_info($table)').get())
          [
            column.data['name'],
            column.data['type'],
            column.data['notnull'],
            column.data['dflt_value'],
            column.data['pk'],
          ].join('|'),
      },
  };
}
