import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/visit_detail/photo_edit.dart';

import '../../support/fakes.dart';

void main() {
  late PhotoStorage storage;
  late RecordRepository repository;

  setUp(() {
    storage = PhotoStorage(createTempDirectory());
    repository = RecordRepository(createTestDatabase());
  });

  String picked(String name) {
    final file = File(p.join(createTempDirectory().path, name))
      ..writeAsBytesSync([1, 2, 3]);
    return file.path;
  }

  Future<Visit> saveVisit(String? photoPath) => repository.saveEatenVisit(
    shop: const ShopInput(name: '麺屋'),
    eatenAt: DateTime(2026, 10, 1, 12),
    photoPath: photoPath,
    now: DateTime(2026, 10, 1, 12),
  );

  Future<String?> saveEdit(Visit visit, PhotoEdit edit) =>
      repository.updateVisit(
        visitId: visit.id,
        shopName: '麺屋',
        eatenAt: visit.eatenAt,
        checkedInAt: null,
        rating: null,
        style: null,
        isLimited: false,
        hasTicket: false,
        memo: '',
        changesPhoto: edit.isChanged,
        photoPath: edit.current,
        now: DateTime(2026, 10, 2),
      );

  Future<String?> photoPathOf(Visit visit) async =>
      (await repository.watchVisits().first)
          .singleWhere((entry) => entry.visit.id == visit.id)
          .visit
          .photoPath;

  test('保存すると新しい写真を記録に書き、前の写真のファイルを消す', () async {
    final old = await storage.save(picked('old.jpg'));
    final visit = await saveVisit(old);
    final edit = PhotoEdit(storage, original: old);

    await edit.replace(picked('new.jpg'));
    final replaced = edit.current!;
    await edit.commit(await saveEdit(visit, edit));
    await edit.discard();

    expect(await photoPathOf(visit), replaced);
    expect(storage.fileFor(replaced).existsSync(), isTrue);
    expect(storage.fileFor(old).existsSync(), isFalse);
  });

  test('保存せずに閉じると、コピーした写真だけを消して前の写真を残す', () async {
    final old = await storage.save(picked('old.jpg'));
    final visit = await saveVisit(old);
    final edit = PhotoEdit(storage, original: old);

    await edit.replace(picked('new.jpg'));
    final replaced = edit.current!;
    await edit.discard();

    expect(await photoPathOf(visit), old);
    expect(storage.fileFor(old).existsSync(), isTrue);
    expect(storage.fileFor(replaced).existsSync(), isFalse);
  });

  test('選び直すと、前に選んだ写真のコピーを消す', () async {
    final edit = PhotoEdit(storage, original: null);

    await edit.replace(picked('first.jpg'));
    final first = edit.current!;
    await edit.replace(picked('second.jpg'));

    expect(storage.fileFor(first).existsSync(), isFalse);
    expect(storage.fileFor(edit.current!).existsSync(), isTrue);
  });

  test('ほかの記録も使っている前の写真は、保存しても消さない', () async {
    final shared = await storage.save(picked('shared.jpg'));
    final visit = await saveVisit(shared);
    await saveVisit(shared);
    final edit = PhotoEdit(storage, original: shared);

    await edit.replace(picked('new.jpg'));
    await edit.commit(await saveEdit(visit, edit));

    expect(storage.fileFor(shared).existsSync(), isTrue);
  });

  test('写真を外して保存すると写真なしになり、前の写真のファイルを消す', () async {
    final old = await storage.save(picked('old.jpg'));
    final visit = await saveVisit(old);
    final edit = PhotoEdit(storage, original: old);

    await edit.remove();
    expect(edit.current, isNull);
    await edit.commit(await saveEdit(visit, edit));

    expect(await photoPathOf(visit), isNull);
    expect(storage.fileFor(old).existsSync(), isFalse);
  });

  test('写真に触れずに保存すると、前の写真をそのまま残す', () async {
    final old = await storage.save(picked('old.jpg'));
    final visit = await saveVisit(old);
    final edit = PhotoEdit(storage, original: old);

    await edit.commit(await saveEdit(visit, edit));

    expect(await photoPathOf(visit), old);
    expect(storage.fileFor(old).existsSync(), isTrue);
  });
}
