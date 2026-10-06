import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/backup/backup_codec.dart';
import 'package:ramen_in_cho/features/backup/backup_service.dart';
import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';

import '../../support/fakes.dart';

final _now = DateTime(2026, 10, 1, 21, 30);

void main() {
  group('backup_codec', () {
    test('店と記録を書き出して読み戻すと、同じ内容になる', () {
      final shop = Shop(
        id: 'shop',
        name: '麺屋',
        latitude: 35.0,
        longitude: 139.0,
        osmId: 'node/1',
        isFamous: true,
        strategyMemo: '券売機は現金のみ',
        area: '新宿区',
        dataSource: const ShopSource(
          licenses: ['CC BY 4.0'],
          attributions: ['東京都新宿区食品等営業許可・届出一覧'],
        ),
        createdAt: DateTime(2026, 9, 1),
      );
      final visit = Visit(
        id: 'visit',
        shopId: 'shop',
        result: VisitResult.eaten,
        photoPath: 'photos/a.jpg',
        checkedInAt: DateTime(2026, 9, 1, 11, 20),
        eatenAt: DateTime(2026, 9, 1, 12),
        style: RamenStyle.iekei,
        rating: 4,
        isLimited: true,
        hasTicket: false,
        memo: 'うまい',
        createdAt: DateTime(2026, 9, 1, 12, 5),
      );

      final json = jsonDecode(
        jsonEncode(
          encodeBackup(
            BackupData(shops: [shop], visits: [visit]),
            exportedAt: _now,
          ),
        ),
      );
      final restored = decodeBackup(json);

      final restoredShop = restored.shops.single;
      expect(restoredShop.id, 'shop');
      expect(restoredShop.name, '麺屋');
      expect(restoredShop.latitude, 35.0);
      expect(restoredShop.osmId, 'node/1');
      expect(restoredShop.isFamous, isTrue);
      expect(restoredShop.strategyMemo, '券売機は現金のみ');
      expect(restoredShop.area, '新宿区');
      expect(restoredShop.dataSource!.licenses, ['CC BY 4.0']);
      expect(restoredShop.dataSource!.attributions, ['東京都新宿区食品等営業許可・届出一覧']);
      expect(restoredShop.createdAt, DateTime(2026, 9, 1));
      final restoredVisit = restored.visits.single;
      expect(restoredVisit.id, 'visit');
      expect(restoredVisit.result, VisitResult.eaten);
      expect(restoredVisit.photoPath, 'photos/a.jpg');
      expect(restoredVisit.checkedInAt, DateTime(2026, 9, 1, 11, 20));
      expect(restoredVisit.eatenAt, DateTime(2026, 9, 1, 12));
      expect(restoredVisit.style, RamenStyle.iekei);
      expect(restoredVisit.rating, 4);
      expect(restoredVisit.isLimited, isTrue);
      expect(restoredVisit.memo, 'うまい');
    });

    test('前の版のバックアップにある店の条件は読み飛ばし、名店の印は無しにする', () {
      final restored = decodeBackup({
        'format': backupFormat,
        'version': backupVersion,
        'shops': [
          {
            'id': 's',
            'name': '麺屋',
            'hoursConditions': ['lunchOnly', 'fewDays'],
            'createdAt': '2026-09-01T12:00:00.000Z',
          },
        ],
        'wishes': [
          {
            'id': 'w',
            'name': '願の店',
            'hoursConditions': ['irregular'],
            'createdAt': '2026-09-01T12:00:00.000Z',
          },
        ],
        'visits': <Object?>[],
      });

      expect(restored.shops.single.name, '麺屋');
      expect(restored.shops.single.isFamous, isFalse);
      expect(restored.wishes.single.name, '願の店');
    });

    test('日時はUTCで書き出し、読むときはその端末の時刻に直す', () {
      final json = encodeBackup(
        BackupData(
          shops: [
            Shop(id: 's', name: '麺屋', createdAt: DateTime(2026, 9, 1, 12)),
          ],
          visits: const [],
        ),
        exportedAt: _now,
      );

      final written = (json['shops']! as List).single as Map;
      expect(written['createdAt'], endsWith('Z'));
      final restored = decodeBackup(jsonDecode(jsonEncode(json)));
      expect(restored.shops.single.createdAt, DateTime(2026, 9, 1, 12));
      expect(restored.shops.single.createdAt.isUtc, isFalse);
    });

    test('項目の型が違うときも、壊れたバックアップとして扱う', () {
      expect(
        () => decodeBackup({
          'format': backupFormat,
          'version': backupVersion,
          'shops': [
            {
              'id': 's',
              'name': '麺屋',
              'osmId': 123,
              'createdAt': '2026-09-01T12:00:00.000Z',
            },
          ],
          'visits': <Object?>[],
        }),
        throwsFormatException,
      );
    });

    test('旧名（着丼クエスト）のバックアップは読まない', () {
      expect(
        () => decodeBackup({
          'format': 'chakudon-quest-backup',
          'version': backupVersion,
          'shops': <Object?>[],
          'visits': <Object?>[],
        }),
        throwsFormatException,
      );
    });

    test('知らない項目は読み飛ばし、無い項目は初期値にする', () {
      final restored = decodeBackup({
        'format': backupFormat,
        'version': backupVersion,
        'somethingNew': {'a': 1},
        'shops': [
          {
            'id': 's',
            'name': '麺屋',
            'futureField': 'x',
            'createdAt': '2026-09-01T12:00:00.000Z',
          },
        ],
        'visits': [
          {
            'id': 'v',
            'shopId': 's',
            'result': 'eaten',
            'eatenAt': '2026-09-01T12:00:00.000Z',
            'createdAt': '2026-09-01T12:00:00.000Z',
            'futureField': 3,
          },
        ],
      });

      final shop = restored.shops.single;
      expect(shop.latitude, isNull);
      expect(shop.isFamous, isFalse);
      expect(shop.strategyMemo, '');
      expect(shop.area, isNull);
      expect(shop.dataSource, isNull);
      final visit = restored.visits.single;
      expect(visit.photoPath, isNull);
      expect(visit.checkedInAt, isNull);
      expect(visit.memo, '');
      expect(visit.isLimited, isFalse);
      expect(restored.wishes, isEmpty);
      expect(restored.homeBases, isEmpty);
    });

    test('拠点の履歴を書き出して読み戻せる', () {
      final json = jsonDecode(
        jsonEncode(
          encodeBackup(
            BackupData(
              shops: const [],
              visits: const [],
              homeBases: [
                HomeBaseSetting(
                  id: 'base',
                  name: '札幌市',
                  latitude: 43.06,
                  longitude: 141.35,
                  setAt: DateTime(2026, 10, 5, 9),
                ),
              ],
            ),
            exportedAt: _now,
          ),
        ),
      );

      final base = decodeBackup(json).homeBases.single;
      expect(base.id, 'base');
      expect(base.name, '札幌市');
      expect(base.latitude, 43.06);
      expect(base.longitude, 141.35);
      expect(base.setAt, DateTime(2026, 10, 5, 9));
    });

    test('ほかのアプリのファイルや、新しい版のバックアップは読まない', () {
      expect(() => decodeBackup({'format': 'other'}), throwsFormatException);
      expect(
        () => decodeBackup({
          'format': backupFormat,
          'version': backupVersion + 1,
          'shops': <Object?>[],
          'visits': <Object?>[],
        }),
        throwsFormatException,
      );
      expect(() => decodeBackup('not a map'), throwsFormatException);
    });

    test('記録の必須項目が壊れていれば読まない。知らない系統は「系統なし」にする', () {
      Map<String, Object?> backupWith(Map<String, Object?> visit) => {
        'format': backupFormat,
        'version': backupVersion,
        'shops': <Object?>[],
        'visits': [visit],
      };
      final visit = {
        'id': 'v',
        'shopId': 's',
        'result': 'eaten',
        'eatenAt': '2026-09-01T12:00:00.000',
        'createdAt': '2026-09-01T12:00:00.000',
        'style': 'unknownStyle',
        'rating': 9,
      };

      final restored = decodeBackup(backupWith(visit)).visits.single;
      expect(restored.style, isNull);
      expect(restored.rating, isNull);

      expect(
        () => decodeBackup(backupWith({...visit, 'result': 'burned'})),
        throwsFormatException,
      );
      expect(
        () => decodeBackup(backupWith({...visit, 'eatenAt': 'yesterday'})),
        throwsFormatException,
      );
    });
  });

  group('BackupService', () {
    late AppDatabase sourceDatabase;
    late RecordRepository source;
    late PhotoStorage sourcePhotos;
    late Directory temporary;

    setUp(() async {
      sourceDatabase = createTestDatabase();
      source = RecordRepository(sourceDatabase);
      await HomeBaseRepository(sourceDatabase).setHomeBase(
        name: '横浜駅',
        latitude: 35.466,
        longitude: 139.622,
        now: DateTime(2026, 8, 1, 9),
      );
      sourcePhotos = PhotoStorage(createTempDirectory());
      temporary = createTempDirectory();
      final picked = File(p.join(temporary.path, 'picked.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final photoPath = await sourcePhotos.save(picked.path);
      final visit = await source.saveEatenVisit(
        shop: const ShopInput(name: '麺屋', latitude: 35.0, longitude: 139.0),
        eatenAt: DateTime(2026, 9, 1, 12),
        rating: 5,
        photoPath: photoPath,
        now: DateTime(2026, 9, 1, 12),
      );
      await source.setShopMemo(visit.shopId, '開店30分前');
      await source.saveEatenVisit(
        shop: const ShopInput(name: '写真なしの店'),
        eatenAt: DateTime(2026, 9, 2, 12),
        now: DateTime(2026, 9, 2, 12),
      );
    });

    BackupService serviceFor(
      RecordRepository repository,
      PhotoStorage photos,
    ) => BackupService(
      repository: repository,
      photos: photos,
      temporaryDirectory: () async => temporary,
    );

    test('書き出したファイルを別のスマホで読み込むと、記録と写真が戻る', () async {
      final backup = await serviceFor(source, sourcePhotos).writeBackup(_now);
      expect(p.basename(backup.path), 'ramen-in-cho-20261001-2130.zip');

      final targetDatabase = createTestDatabase();
      final target = RecordRepository(targetDatabase);
      final targetPhotos = PhotoStorage(createTempDirectory());
      final summary = await serviceFor(
        target,
        targetPhotos,
      ).restoreBackup(backup.path);

      expect(summary.addedVisits, 2);
      final homeBase = (await HomeBaseRepository(
        targetDatabase,
      ).allSettings()).single;
      expect(homeBase.name, '横浜駅');
      expect(homeBase.setAt, DateTime(2026, 8, 1, 9));
      expect(summary.totalVisits, 2);
      final visits = await target.watchVisits().first;
      expect(visits.map((v) => v.shop.name).toSet(), {'麺屋', '写真なしの店'});
      final withPhoto = visits.firstWhere((v) => v.shop.name == '麺屋');
      expect(withPhoto.shop.strategyMemo, '開店30分前');
      expect(withPhoto.visit.rating, 5);
      expect(
        targetPhotos.fileFor(withPhoto.visit.photoPath!).readAsBytesSync(),
        [1, 2, 3],
      );
    });

    test('同じファイルをもう一度読み込んでも、記録は増えない', () async {
      final service = serviceFor(source, sourcePhotos);
      final backup = await service.writeBackup(_now);

      final summary = await service.restoreBackup(backup.path);

      expect(summary.addedVisits, 0);
      expect(await source.watchVisits().first, hasLength(2));
      expect((await source.exportAll()).homeBases, hasLength(1));
    });

    test('直した拠点は直した中身で書き出し、消した拠点は書き出さない', () async {
      final homeBases = HomeBaseRepository(sourceDatabase);
      final yokohama = (await homeBases.allSettings()).single;
      final sapporo = await homeBases.setHomeBase(
        name: '札幌',
        latitude: 43.0687,
        longitude: 141.3508,
        now: DateTime(2026, 9, 10, 9),
      );
      await homeBases.updateHomeBase(
        yokohama.copyWith(name: '横浜', setAt: DateTime(2026, 7, 1)),
      );
      await homeBases.deleteHomeBase(sapporo.id);
      final backup = await serviceFor(source, sourcePhotos).writeBackup(_now);

      final targetDatabase = createTestDatabase();
      await serviceFor(
        RecordRepository(targetDatabase),
        PhotoStorage(createTempDirectory()),
      ).restoreBackup(backup.path);

      final restored = (await HomeBaseRepository(
        targetDatabase,
      ).allSettings()).single;
      expect(restored.id, yokohama.id);
      expect(restored.name, '横浜');
      expect(restored.setAt, DateTime(2026, 7, 1));
    });

    test('同じIDの拠点がもうあれば、読み込んでも端末の中身を残す', () async {
      final backup = await serviceFor(source, sourcePhotos).writeBackup(_now);
      final homeBases = HomeBaseRepository(sourceDatabase);
      final yokohama = (await homeBases.allSettings()).single;
      await homeBases.updateHomeBase(yokohama.copyWith(name: '横浜'));

      await serviceFor(source, sourcePhotos).restoreBackup(backup.path);

      expect((await homeBases.allSettings()).single.name, '横浜');
    });

    test('書き出すたびに、前回書き出したファイルを消す', () async {
      final service = serviceFor(source, sourcePhotos);
      final first = await service.writeBackup(_now);
      final second = await service.writeBackup(
        _now.add(const Duration(minutes: 5)),
      );

      expect(first.existsSync(), isFalse);
      expect(second.existsSync(), isTrue);
    });

    test('記録を足せなかったら、書いた写真も消す', () async {
      final backup = await serviceFor(source, sourcePhotos).writeBackup(_now);
      final targetDocuments = createTempDirectory();
      final failing = FakeRecordRepository()..importError = StateError('db');

      await expectLater(
        serviceFor(
          failing,
          PhotoStorage(targetDocuments),
        ).restoreBackup(backup.path),
        throwsStateError,
      );

      final photos = Directory(p.join(targetDocuments.path, 'photos'));
      expect(photos.existsSync() ? photos.listSync() : const [], isEmpty);
    });

    test('バックアップでないzipは読み込まない', () async {
      final path = p.join(temporary.path, 'other.zip');
      final encoder = ZipFileEncoder()..create(path);
      encoder.addArchiveFile(ArchiveFile.string('readme.txt', 'hello'));
      await encoder.close();

      expect(
        () => serviceFor(source, sourcePhotos).restoreBackup(path),
        throwsFormatException,
      );
    });

    test('写真のフォルダの外を指す名前のファイルは書き出さない', () async {
      final data = await source.exportAll();
      final path = p.join(temporary.path, 'evil.zip');
      final encoder = ZipFileEncoder()..create(path);
      encoder.addArchiveFile(
        ArchiveFile.string(
          'backup.json',
          jsonEncode(encodeBackup(data, exportedAt: _now)),
        ),
      );
      encoder.addArchiveFile(ArchiveFile.bytes('photos/../escaped.jpg', [9]));
      encoder.addArchiveFile(ArchiveFile.bytes('other/x.jpg', [9]));
      await encoder.close();
      final targetDocuments = createTempDirectory();

      await serviceFor(
        RecordRepository(createTestDatabase()),
        PhotoStorage(targetDocuments),
      ).restoreBackup(path);

      expect(
        File(p.join(targetDocuments.path, 'escaped.jpg')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(targetDocuments.path, 'other', 'x.jpg')).existsSync(),
        isFalse,
      );
    });
  });

  group('これまでの版で書き出したバックアップ', () {
    Future<BackupData> importFixture(String name, AppDatabase database) async {
      final json = jsonDecode(
        File('test/fixtures/backup/$name.json').readAsStringSync(),
      );
      await RecordRepository(database).importAll(decodeBackup(json));
      return RecordRepository(database).exportAll();
    }

    test('2026-10-03 の版（店と願に店の条件、拠点なし）を読み込める', () async {
      final data = await importFixture('2026-10-03', createTestDatabase());

      final shops = {for (final shop in data.shops) shop.id: shop};
      expect(shops.keys, unorderedEquals(['shop', 'manual']));
      final shop = shops['shop']!;
      expect(shop.name, '麺屋');
      expect(shop.latitude, 35.0);
      expect(shop.osmId, 'node/1');
      expect(shop.strategyMemo, '券売機は現金のみ');
      expect(shop.area, '新宿区');
      expect(shop.dataSource!.licenses, ['CC BY 4.0']);
      expect(shop.isFamous, isFalse);
      expect(shop.createdAt, DateTime.utc(2026, 9, 30, 3).toLocal());
      expect(shops['manual']!.latitude, isNull);

      final visits = {for (final visit in data.visits) visit.id: visit};
      final visit = visits['visit']!;
      expect(visit.photoPath, 'photos/a.jpg');
      expect(visit.checkedInAt, DateTime.utc(2026, 9, 30, 2, 20).toLocal());
      expect(visit.eatenAt, DateTime.utc(2026, 9, 30, 3).toLocal());
      expect(visit.style, RamenStyle.shoyu);
      expect(visit.rating, 4);
      expect(visit.isLimited, isTrue);
      expect(visit.hasTicket, isTrue);
      expect(visit.memo, '醤油が澄んでいた');
      expect(visits['retreat']!.result, VisitResult.retreated);
      expect(visits['retreat']!.memo, '売り切れ');

      final wish = data.wishes.single;
      expect(wish.name, 'はやし田');
      expect(wish.osmId, 'node/2');
      expect(wish.trigger, '同僚に聞いた');
      expect(wish.note, '煮干し');
      expect(wish.link, isNull);
      expect(data.homeBases, isEmpty);
    });

    test('2026-10-05 の版（拠点あり）を読み込める', () async {
      final data = await importFixture('2026-10-05', createTestDatabase());

      expect(data.shops.single.isFamous, isFalse);
      expect(data.visits.single.style, RamenStyle.iekei);
      expect(data.visits.single.rating, isNull);
      final wish = data.wishes.single;
      expect(wish.shopId, 'shop');
      expect(wish.fulfilledVisitId, 'visit');
      final base = data.homeBases.single;
      expect(base.name, '横浜駅');
      expect(base.latitude, 35.466);
      expect(base.longitude, 139.622);
      expect(base.setAt, DateTime.utc(2026, 8, 1).toLocal());
    });

    test('2026-10-06 の版（名店の印あり、願のリンクなし）を読み込める', () async {
      final data = await importFixture('2026-10-06', createTestDatabase());

      expect(data.shops.single.isFamous, isTrue);
      expect(data.visits.single.style, RamenStyle.shirunashi);
      expect(data.visits.single.rating, 5);
      expect(data.wishes.single.trigger, 'テレビ');
      expect(data.wishes.single.link, isNull);
      expect(data.homeBases, isEmpty);
    });
  });

  test('すべての表に記録がある端末を書き出して空の端末に読み込むと、同じ内容になる', () async {
    final sourceDatabase = createTestDatabase();
    final source = RecordRepository(sourceDatabase);
    const dataSource = ShopSource(
      licenses: ['CC BY 4.0'],
      attributions: ['東京都新宿区食品等営業許可・届出一覧'],
    );
    await source.importAll(
      BackupData(
        shops: [
          Shop(
            id: 'shop',
            name: '麺屋',
            latitude: 35.0,
            longitude: 139.0,
            osmId: 'node/1',
            isFamous: true,
            strategyMemo: '券売機は現金のみ',
            dataSource: dataSource,
            area: '新宿区',
            createdAt: DateTime(2026, 9, 1, 12),
          ),
          Shop(id: 'manual', name: '手入力の店', createdAt: DateTime(2026, 9, 2)),
        ],
        visits: [
          Visit(
            id: 'visit',
            shopId: 'shop',
            result: VisitResult.eaten,
            photoPath: 'photos/a.jpg',
            checkedInAt: DateTime(2026, 9, 1, 11, 20),
            eatenAt: DateTime(2026, 9, 1, 12),
            style: RamenStyle.iekei,
            rating: 4,
            isLimited: true,
            hasTicket: true,
            memo: 'うまい',
            createdAt: DateTime(2026, 9, 1, 12, 5),
          ),
          Visit(
            id: 'retreat',
            shopId: 'manual',
            result: VisitResult.retreated,
            eatenAt: DateTime(2026, 9, 2, 12),
            isLimited: false,
            hasTicket: false,
            memo: '売り切れ',
            createdAt: DateTime(2026, 9, 2, 12),
          ),
        ],
        wishes: [
          Wish(
            id: 'wish',
            osmId: 'node/2',
            name: 'はやし田',
            latitude: 35.1,
            longitude: 139.1,
            dataSource: dataSource,
            trigger: '同僚に聞いた',
            note: '煮干し',
            link: 'https://maps.app.goo.gl/example',
            createdAt: DateTime(2026, 8, 1),
          ),
          Wish(
            id: 'done',
            shopId: 'shop',
            name: '麺屋',
            createdAt: DateTime(2026, 8, 2),
            fulfilledVisitId: 'visit',
          ),
        ],
        homeBases: [
          HomeBaseSetting(
            id: 'base',
            name: '横浜駅',
            latitude: 35.466,
            longitude: 139.622,
            setAt: DateTime(2026, 8, 1, 9),
          ),
        ],
      ),
    );
    final sourcePhotos = PhotoStorage(createTempDirectory());
    sourcePhotos.fileFor('photos/a.jpg')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final temporary = createTempDirectory();
    final backup = await BackupService(
      repository: source,
      photos: sourcePhotos,
      temporaryDirectory: () async => temporary,
    ).writeBackup(_now);

    final target = RecordRepository(createTestDatabase());
    final targetPhotos = PhotoStorage(createTempDirectory());
    final summary = await BackupService(
      repository: target,
      photos: targetPhotos,
      temporaryDirectory: () async => temporary,
    ).restoreBackup(backup.path);

    expect(summary.addedVisits, 2);
    Map<String, Object?> dump(BackupData data) =>
        encodeBackup(data, exportedAt: _now);
    final restored = dump(await target.exportAll());
    expect(restored, dump(await source.exportAll()));
    for (final key in ['shops', 'visits', 'wishes', 'homeBases']) {
      expect(restored[key], hasLength(key == 'homeBases' ? 1 : 2));
    }
    expect(targetPhotos.fileFor('photos/a.jpg').readAsBytesSync(), [1, 2, 3]);
  });
}
