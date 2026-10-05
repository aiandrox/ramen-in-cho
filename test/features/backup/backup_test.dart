import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/backup/backup_codec.dart';
import 'package:ramen_in_cho/features/backup/backup_service.dart';
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
        hoursConditions: {HoursCondition.fewDays, HoursCondition.lunchOnly},
        strategyMemo: '券売機は現金のみ',
        area: '厚木市',
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
      expect(restoredShop.hoursConditions, {
        HoursCondition.lunchOnly,
        HoursCondition.fewDays,
      });
      expect(restoredShop.strategyMemo, '券売機は現金のみ');
      expect(restoredShop.area, '厚木市');
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

    test('旧名（着丼クエスト）のバックアップも読める', () {
      final restored = decodeBackup({
        'format': legacyBackupFormat,
        'version': backupVersion,
        'shops': <Object?>[],
        'visits': <Object?>[],
      });
      expect(restored.visits, isEmpty);
      // 拠点を自分で決めるようになる前のバックアップには拠点が無い。
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
                  name: '厚木市',
                  latitude: 35.44,
                  longitude: 139.36,
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
      expect(base.name, '厚木市');
      expect(base.latitude, 35.44);
      expect(base.longitude, 139.36);
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
    late RecordRepository source;
    late PhotoStorage sourcePhotos;
    late Directory temporary;

    setUp(() async {
      final sourceDatabase = createTestDatabase();
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
}
