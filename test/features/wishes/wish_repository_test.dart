import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/backup/backup_codec.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

import '../../support/fakes.dart';

void main() {
  late WishRepository wishes;
  late RecordRepository records;

  setUp(() {
    final database = createTestDatabase();
    wishes = WishRepository(database);
    records = RecordRepository(database);
  });

  test('願を書き留め、書き直し、消せる', () async {
    final wish = await wishes.addWish(
      shop: const ShopInput(
        osmId: 'node/1',
        name: ' はやし田 ',
        latitude: 35.0,
        longitude: 139.0,
        dataSource: ShopSource(licenses: ['CC BY 4.0']),
      ),
      trigger: '同僚に聞いた',
      note: '',
      now: DateTime(2026, 10, 3),
    );

    var saved = (await wishes.watchWishes().first).single;
    expect(saved.name, 'はやし田');
    expect(saved.osmId, 'node/1');
    expect(saved.trigger, '同僚に聞いた');
    expect(saved.dataSource!.licenses, ['CC BY 4.0']);

    await wishes.updateWish(wish.id, trigger: 'テレビ', note: '煮干し');
    saved = (await wishes.watchWishes().first).single;
    expect(saved.trigger, 'テレビ');
    expect(saved.note, '煮干し');

    await wishes.deleteWish(wish.id);
    expect(await wishes.watchWishes().first, isEmpty);
  });

  test('願にリンクを残し、書き直しで変えたり外したりできる', () async {
    final wish = await wishes.addWish(
      shop: const ShopInput(name: '麺屋さくら'),
      link: ' https://maps.app.goo.gl/AbC ',
      now: DateTime(2026, 10, 6),
    );
    expect(wish.link, 'https://maps.app.goo.gl/AbC');
    expect(
      (await wishes.watchWishes().first).single.link,
      'https://maps.app.goo.gl/AbC',
    );

    await wishes.updateWish(
      wish.id,
      trigger: '',
      note: '',
      link: 'https://youtu.be/xyz',
    );
    expect(
      (await wishes.watchWishes().first).single.link,
      'https://youtu.be/xyz',
    );

    await wishes.updateWish(wish.id, trigger: '', note: '', link: ' ');
    expect((await wishes.watchWishes().first).single.link, isNull);
  });

  test('バックアップに願を含め、読み込むと端末に無い願だけを足す', () async {
    await wishes.addWish(
      shop: const ShopInput(name: 'はやし田'),
      trigger: '同僚に聞いた',
      link: 'https://youtu.be/xyz',
      now: DateTime(2026, 10, 3),
    );
    final exported = await records.exportAll();
    final decoded = decodeBackup(
      encodeBackup(exported, exportedAt: DateTime(2026, 10, 4)),
    );
    expect(decoded.wishes.single.trigger, '同僚に聞いた');
    expect(decoded.wishes.single.link, 'https://youtu.be/xyz');

    final other = createTestDatabase();
    await RecordRepository(other).importAll(decoded);
    await RecordRepository(other).importAll(decoded);
    final restored = await WishRepository(other).watchWishes().first;
    expect(restored.single.name, 'はやし田');
    expect(restored.single.link, 'https://youtu.be/xyz');
  });

  test('願掛け帳より前のバックアップも読める', () {
    final data = decodeBackup({
      'format': backupFormat,
      'version': backupVersion,
      'shops': <Object?>[],
      'visits': <Object?>[],
    });

    expect(data.wishes, isEmpty);
  });

  test('リンクの無い願のバックアップも読める', () {
    final data = decodeBackup({
      'format': backupFormat,
      'version': backupVersion,
      'shops': <Object?>[],
      'visits': <Object?>[],
      'wishes': [
        {
          'id': 'wish',
          'name': '麺屋さくら',
          'createdAt': '2026-10-01T00:00:00.000Z',
        },
      ],
    });

    expect(data.wishes.single.name, '麺屋さくら');
    expect(data.wishes.single.link, isNull);
  });

  group('記録で願を叶える', () {
    Future<Visit> eat(ShopInput shop) => records.saveEatenVisit(
      shop: shop,
      eatenAt: DateTime(2026, 10, 3, 12),
      now: DateTime(2026, 10, 3, 12, 5),
    );

    test('願の店を選んで保存すると、その1杯で叶う。消すとまだの願に戻る', () async {
      final wish = await wishes.addWish(
        shop: const ShopInput(name: 'はやし田', latitude: 35.0, longitude: 139.0),
        now: DateTime(2026, 9, 1),
      );
      final visit = await eat(
        ShopInput(
          name: 'はやし田',
          latitude: 35.0,
          longitude: 139.0,
          wishId: wish.id,
        ),
      );

      var saved = (await wishes.watchWishes().first).single;
      expect(saved.fulfilledVisitId, visit.id);
      expect(saved.shopId, visit.shopId);
      expect(await wishes.pendingWishes(), isEmpty);

      await records.deleteVisit(visit.id);
      saved = (await wishes.watchWishes().first).single;
      expect(saved.fulfilledVisitId, isNull);
      // 店も消えたので、願から店のIDを外す。
      expect(saved.shopId, isNull);
    });

    test('願を選ばなくても、同じOSMの店なら叶う', () async {
      await wishes.addWish(
        shop: const ShopInput(osmId: 'node/1', name: 'はやし田'),
        now: DateTime(2026, 9, 1),
      );
      final visit = await eat(
        const ShopInput(osmId: 'node/1', name: 'らぁ麺 はやし田'),
      );

      expect(
        (await wishes.watchWishes().first).single.fulfilledVisitId,
        visit.id,
      );
    });

    test('名前が似ているだけでは叶わない', () async {
      await wishes.addWish(
        shop: const ShopInput(name: '一蘭'),
        now: DateTime(2026, 9, 1),
      );
      await eat(const ShopInput(name: '一蘭 新宿店'));

      expect(await wishes.pendingWishes(), hasLength(1));
    });
  });
}
