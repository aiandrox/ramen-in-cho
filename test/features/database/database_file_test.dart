import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/backup/backup_codec.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';

/// drift 2.35.0・sqlite3 3.5.2 で作った、スキーマのバージョン13のデータベースのファイル。
/// drift や sqlite3 を上げるときは、上げる前のコミットで
/// `UPDATE_DB_FIXTURE=true flutter test test/features/database/database_file_test.dart`
/// を実行して作り直し、この版の書き込みも直す（上げたあとに作り直すと、古い版との比べにならない）。
/// スキーマのバージョンが上がっても、このファイルは消さずに残し、マイグレーションのあとの値を比べる。
const _fixturePath = 'test/fixtures/database/ramen_in_cho_v13.sqlite';
const _fixtureSchemaVersion = 13;

const _source = ShopSource(
  licenses: ['CC-BY-4.0'],
  attributions: ['OpenPOI API'],
);

final _sample = BackupData(
  shops: [
    Shop(
      id: 'shop-osm',
      name: 'らぁ麺 新宿',
      latitude: 35.6905,
      longitude: 139.7003,
      osmId: 'node/123',
      isFamous: true,
      strategyMemo: '開店30分前に着く',
      area: '新宿区',
      createdAt: DateTime.utc(2026, 9, 30, 3),
    ),
    Shop(
      id: 'shop-openpoi',
      name: '中華そば 渋谷',
      latitude: 35.6580,
      longitude: 139.7016,
      dataSource: _source,
      area: '',
      createdAt: DateTime.utc(2026, 10, 1, 4),
    ),
    Shop(
      id: 'shop-manual',
      name: '手入力の店',
      createdAt: DateTime.utc(2026, 10, 2, 5),
    ),
  ],
  visits: [
    Visit(
      id: 'visit-1',
      shopId: 'shop-osm',
      result: VisitResult.eaten,
      photoPath: 'photos/visit-1.jpg',
      checkedInAt: DateTime.utc(2026, 9, 30, 2, 15),
      eatenAt: DateTime.utc(2026, 9, 30, 3, 2),
      style: RamenStyle.shoyu,
      rating: 5,
      isLimited: true,
      memo: '限定の煮干し',
      createdAt: DateTime.utc(2026, 9, 30, 3, 3),
    ),
    Visit(
      id: 'visit-2',
      shopId: 'shop-openpoi',
      result: VisitResult.retreated,
      eatenAt: DateTime.utc(2026, 10, 1, 4),
      isLimited: false,
      memo: '売り切れ',
      createdAt: DateTime.utc(2026, 10, 1, 4),
    ),
    Visit(
      id: 'visit-3',
      shopId: 'shop-openpoi',
      result: VisitResult.eaten,
      eatenAt: DateTime.utc(2026, 10, 4, 12, 30),
      style: RamenStyle.shirunashi,
      isLimited: false,
      memo: '',
      createdAt: DateTime.utc(2026, 10, 4, 12, 31),
    ),
    Visit(
      id: 'visit-4',
      shopId: 'shop-manual',
      result: VisitResult.eaten,
      photoPath: 'photos/visit-4.jpg',
      eatenAt: DateTime.utc(2026, 10, 5, 15, 45),
      style: RamenStyle.other,
      rating: 1,
      isLimited: false,
      memo: '改行\nあり',
      createdAt: DateTime.utc(2026, 10, 5, 15, 46),
    ),
  ],
  wishes: [
    Wish(
      id: 'wish-fulfilled',
      shopId: 'shop-openpoi',
      name: '中華そば 渋谷',
      latitude: 35.6580,
      longitude: 139.7016,
      dataSource: _source,
      trigger: '友だちに聞いた',
      note: 'つけ麺も',
      createdAt: DateTime.utc(2026, 9, 1),
      fulfilledVisitId: 'visit-3',
    ),
    Wish(
      id: 'wish-open',
      osmId: 'node/456',
      name: 'まだの店',
      latitude: 35.7295,
      longitude: 139.7109,
      link: 'https://example.com/shop',
      createdAt: DateTime.utc(2026, 10, 6),
    ),
  ],
  homeBases: [
    HomeBaseSetting(
      id: 'home',
      name: '池袋のあたり',
      latitude: 35.7295,
      longitude: 139.7109,
      setAt: DateTime.utc(2026, 10, 7),
    ),
  ],
);

Future<void> _fill(AppDatabase database) async {
  final repository = RecordRepository(database);
  await repository.importAll(_sample);
  await repository.checkIn(
    shop: const ShopInput(
      name: '並んでいる店',
      osmId: 'node/789',
      latitude: 35.6895,
      longitude: 139.6917,
      dataSource: _source,
    ),
    at: DateTime.utc(2026, 10, 8, 2),
  );
}

/// すべての表の、保存されている値そのもの。
Future<Map<String, List<Map<String, Object?>>>> _rows(
  AppDatabase database,
) async {
  final tables = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .get();
  return {
    for (final table in tables)
      table.read<String>('name'): [
        for (final row
            in await database
                .customSelect(
                  'SELECT * FROM "${table.read<String>('name')}" '
                  'ORDER BY 1',
                )
                .get())
          row.data,
      ],
  };
}

Future<List<Map<String, Object?>>> _schema(AppDatabase database) async => [
  for (final row
      in await database
          .customSelect(
            'SELECT type, name, tbl_name, sql FROM sqlite_master '
            'ORDER BY type, name',
          )
          .get())
    row.data,
];

Future<int> _userVersion(AppDatabase database) async =>
    (await database.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

void main() {
  // 別々のファイルとメモリのデータベースを同時に開くので、同じものを2回開いたという警告は当たらない。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('保存したデータベースのファイルを作り直す', () async {
    final check = AppDatabase(NativeDatabase.memory());
    final schemaVersion = check.schemaVersion;
    await check.close();
    expect(
      schemaVersion,
      _fixtureSchemaVersion,
      reason: 'スキーマのバージョンが変わったときは、新しい名前のファイルを足し、古いファイルは残す',
    );
    final file = File(_fixturePath);
    if (file.existsSync()) file.deleteSync();
    file.parent.createSync(recursive: true);
    final database = AppDatabase(NativeDatabase(file));
    await _fill(database);
    expect(await _userVersion(database), _fixtureSchemaVersion);
    await database.close();
  }, skip: Platform.environment['UPDATE_DB_FIXTURE'] != 'true');

  test('以前のパッケージの版で作ったデータベースのファイルを開いても、記録はすべてそのまま読める', () async {
    final directory = Directory.systemTemp.createTempSync('ramen_in_cho_db');
    addTearDown(() => directory.deleteSync(recursive: true));
    final copy = File(_fixturePath).copySync('${directory.path}/old.sqlite');

    final saved = AppDatabase(NativeDatabase(copy));
    addTearDown(saved.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await _fill(fresh);

    expect(await _userVersion(saved), saved.schemaVersion);
    expect(await _rows(saved), await _rows(fresh));
    if (saved.schemaVersion == _fixtureSchemaVersion) {
      expect(await _schema(saved), await _schema(fresh));
    }

    final exportedAt = DateTime.utc(2026, 10, 9);
    String backupOf(BackupData data) =>
        jsonEncode(encodeBackup(data, exportedAt: exportedAt));
    final repository = RecordRepository(saved);
    expect(
      backupOf(await repository.exportAll()),
      backupOf(await RecordRepository(fresh).exportAll()),
    );
    expect(
      (await repository.watchVisits().first).map((e) => e.visit.id).toSet(),
      {'visit-1', 'visit-2', 'visit-3', 'visit-4'},
    );
    expect((await repository.activeCheckin())?.name, '並んでいる店');
  });
}
