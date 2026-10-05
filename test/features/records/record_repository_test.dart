import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

import '../../support/fakes.dart';

void main() {
  late RecordRepository repository;
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
    repository = RecordRepository(database);
  });

  Future<Visit> save(
    ShopInput shop, {
    DateTime? eatenAt,
    Set<HoursCondition>? hoursConditions,
  }) => repository.saveEatenVisit(
    shop: shop,
    hoursConditions: hoursConditions,
    eatenAt: eatenAt ?? DateTime(2026, 9, 30, 12),
    rating: 4,
    now: DateTime(2026, 9, 30, 12, 5),
  );

  test('記録を保存すると店と一緒に読み出せる', () async {
    await repository.saveEatenVisit(
      shop: const ShopInput(
        osmId: 'node/1',
        name: '麺屋テスト',
        latitude: 35.0,
        longitude: 139.0,
      ),
      hoursConditions: {HoursCondition.lunchOnly},
      eatenAt: DateTime(2026, 9, 30, 12),
      rating: 5,
      photoPath: 'photos/a.jpg',
      style: RamenStyle.shoyu,
      isLimited: true,
      hasTicket: true,
      memo: 'うまい',
      now: DateTime(2026, 9, 30, 12, 5),
    );

    final entry = (await repository.watchVisits().first).single;

    expect(entry.shop.name, '麺屋テスト');
    expect(entry.shop.osmId, 'node/1');
    expect(entry.shop.latitude, 35.0);
    expect(entry.shop.hoursConditions, {HoursCondition.lunchOnly});
    expect(entry.visit.result, VisitResult.eaten);
    expect(entry.visit.photoPath, 'photos/a.jpg');
    expect(entry.visit.eatenAt, DateTime(2026, 9, 30, 12));
    expect(entry.visit.checkedInAt, isNull);
    expect(entry.visit.style, RamenStyle.shoyu);
    expect(entry.visit.rating, 5);
    expect(entry.visit.isLimited, isTrue);
    expect(entry.visit.hasTicket, isTrue);
    expect(entry.visit.memo, 'うまい');
  });

  test('任意の項目を省いた手入力の店の記録を保存できる', () async {
    await save(const ShopInput(name: ' 手入力の店 '));

    final entry = (await repository.watchVisits().first).single;

    expect(entry.shop.name, '手入力の店');
    expect(entry.shop.osmId, isNull);
    expect(entry.shop.latitude, isNull);
    expect(entry.visit.photoPath, isNull);
    expect(entry.visit.style, isNull);
    expect(entry.visit.isLimited, isFalse);
    expect(entry.visit.memo, '');
  });

  test('記録は食べた時刻の新しい順に並ぶ', () async {
    await save(const ShopInput(name: '古い'), eatenAt: DateTime(2026, 9, 1));
    await save(const ShopInput(name: '新しい'), eatenAt: DateTime(2026, 9, 30));
    await save(const ShopInput(name: '中間'), eatenAt: DateTime(2026, 9, 15));

    final visits = await repository.watchVisits().first;

    expect(visits.map((v) => v.shop.name), ['新しい', '中間', '古い']);
  });

  test('同じOSMの店の2回目は店を増やさない', () async {
    final first = await save(const ShopInput(osmId: 'node/1', name: '麺屋'));
    final second = await save(const ShopInput(osmId: 'node/1', name: '麺屋'));

    expect(second.shopId, first.shopId);
    expect(await repository.allShops(), hasLength(1));
  });

  test('同じ名前の手入力の店の2回目は店を増やさない', () async {
    final first = await save(const ShopInput(name: '手入力の店'));
    final second = await save(const ShopInput(name: '手入力の店 '));
    final other = await save(const ShopInput(name: '別の店'));

    expect(second.shopId, first.shopId);
    expect(other.shopId, isNot(first.shopId));
    expect(await repository.allShops(), hasLength(2));
  });

  test('営業の条件を選ばずに保存しても、記録済みの店の値は変えない', () async {
    await save(
      const ShopInput(name: '麺屋'),
      hoursConditions: {HoursCondition.weekdaysOnly, HoursCondition.fewDays},
    );
    await save(const ShopInput(name: '麺屋'));

    expect((await repository.allShops()).single.hoursConditions, {
      HoursCondition.weekdaysOnly,
      HoursCondition.fewDays,
    });
  });

  test('同じ名前でも300mより離れた手入力の店は別の店にする', () async {
    const here = ShopInput(name: '一蘭', latitude: 35.0, longitude: 139.0);
    const near = ShopInput(name: '一蘭', latitude: 35.002, longitude: 139.0);
    const far = ShopInput(name: '一蘭', latitude: 35.01, longitude: 139.0);
    final first = await save(here);

    expect((await save(near)).shopId, first.shopId);
    expect((await save(far)).shopId, isNot(first.shopId));
    expect(await repository.allShops(), hasLength(2));
  });

  test('位置のわからない手入力の店は、同じ名前の店と同じ店として扱う', () async {
    final first = await save(
      const ShopInput(name: '麺屋', latitude: 35.0, longitude: 139.0),
    );

    expect((await save(const ShopInput(name: '麺屋'))).shopId, first.shopId);
  });

  test('手入力で記録した店をあとから検索結果で選ぶと、同じ店に位置とIDを補う', () async {
    final first = await save(const ShopInput(name: '麺屋'));
    final second = await save(
      const ShopInput(
        osmId: 'node/1',
        name: '麺屋',
        latitude: 35.0,
        longitude: 139.0,
      ),
    );

    final shop = (await repository.allShops()).single;
    expect(second.shopId, first.shopId);
    expect(shop.osmId, 'node/1');
    expect(shop.latitude, 35.0);
  });

  test('OpenPOIで選んだ店を、近くにある表記の少し違うOSMの店として選び直すと同じ店にする', () async {
    final first = await save(
      const ShopInput(name: '鴨 to 葱', latitude: 35.0, longitude: 139.0),
    );
    final second = await save(
      const ShopInput(
        osmId: 'node/1',
        name: 'らーめん鴨to葱',
        latitude: 35.0003,
        longitude: 139.0,
      ),
    );

    expect(second.shopId, first.shopId);
    final shop = (await repository.allShops()).single;
    expect(shop.osmId, 'node/1');
  });

  test('表記の似た店でも100mより離れていれば別の店にする', () async {
    final first = await save(
      const ShopInput(name: '壱角家', latitude: 35.0, longitude: 139.0),
    );
    final second = await save(
      const ShopInput(
        osmId: 'node/1',
        name: '壱角家 西新宿店',
        latitude: 35.002,
        longitude: 139.0,
      ),
    );

    expect(second.shopId, isNot(first.shopId));
  });

  group('OpenPOIの店の出所', () {
    const source = ShopSource(
      licenses: ['CC BY 4.0'],
      attributions: ['東京都新宿区食品等営業許可・届出一覧'],
    );

    test('店と一緒に保存する', () async {
      await save(
        const ShopInput(
          name: 'はやし田',
          latitude: 35.0,
          longitude: 139.0,
          dataSource: source,
        ),
      );

      final shop = (await repository.allShops()).single;
      expect(shop.dataSource!.licenses, ['CC BY 4.0']);
      expect(shop.dataSource!.attributions, source.attributions);
    });

    test('手入力で記録した店をOpenPOIの候補から選び直すと、出所を補う', () async {
      final first = await save(
        const ShopInput(name: 'はやし田', latitude: 35.0, longitude: 139.0),
      );
      final second = await save(
        const ShopInput(
          name: 'はやし田',
          latitude: 35.0,
          longitude: 139.0,
          dataSource: source,
        ),
      );

      expect(second.shopId, first.shopId);
      expect((await repository.allShops()).single.dataSource, isNotNull);
    });

    test('並んだ店の出所は、撤退の記録の店に引き継ぐ', () async {
      await repository.checkIn(
        shop: const ShopInput(
          name: 'はやし田',
          latitude: 35.0,
          longitude: 139.0,
          dataSource: source,
        ),
        at: DateTime(2026, 10, 2, 11),
      );
      final checkin = (await repository.activeCheckin())!;
      expect(checkin.dataSource!.licenses, ['CC BY 4.0']);

      await repository.saveRetreat(
        checkin: checkin,
        now: DateTime(2026, 10, 2, 12),
      );

      expect((await repository.allShops()).single.dataSource, isNotNull);
    });
  });

  test('位置のわからない店に、店名で探した位置を付けられる', () async {
    final visit = await save(const ShopInput(name: '麺屋ふじみち'));

    await repository.setShopLocation(
      visit.shopId,
      latitude: 35.69,
      longitude: 139.71,
      dataSource: const ShopSource(licenses: ['CDLA-Permissive-2.0']),
    );

    final shop = (await repository.allShops()).single;
    expect(shop.latitude, 35.69);
    expect(shop.longitude, 139.71);
    expect(shop.osmId, isNull);
    expect(shop.dataSource!.licenses, ['CDLA-Permissive-2.0']);
  });

  test('位置のわからない店で、位置つきの同じ名前の店を選んで記録すると、位置を補う', () async {
    final first = await save(const ShopInput(name: '麺屋ふじみち'));
    final second = await save(
      const ShopInput(name: '麺屋ふじみち', latitude: 35.69, longitude: 139.71),
    );

    expect(second.shopId, first.shopId);
    final shop = (await repository.allShops()).single;
    expect(shop.latitude, 35.69);
    expect(shop.longitude, 139.71);
  });

  test('同じ名前でも別のOSMの店は別の店にする', () async {
    final first = await save(const ShopInput(osmId: 'node/1', name: '一風堂'));
    final second = await save(const ShopInput(osmId: 'node/2', name: '一風堂'));

    expect(second.shopId, isNot(first.shopId));
  });

  test('記録済みの店をIDで指定でき、営業の条件の変更は店に反映する', () async {
    final first = await save(const ShopInput(name: '麺屋'));
    final second = await save(
      ShopInput(shopId: first.shopId, name: '麺屋'),
      hoursConditions: {HoursCondition.weekdaysOnly, HoursCondition.fewDays},
    );

    final shops = await repository.allShops();
    expect(second.shopId, first.shopId);
    expect(shops.single.hoursConditions, {
      HoursCondition.weekdaysOnly,
      HoursCondition.fewDays,
    });
  });

  group('updateVisit', () {
    Future<String?> update(
      Visit visit, {
      required String shopName,
      Set<HoursCondition>? hoursConditions,
      int? rating = 4,
      String memo = '',
    }) => repository.updateVisit(
      visitId: visit.id,
      shopName: shopName,
      hoursConditions: hoursConditions,
      eatenAt: visit.eatenAt,
      checkedInAt: visit.checkedInAt,
      rating: rating,
      style: visit.style,
      isLimited: visit.isLimited,
      hasTicket: visit.hasTicket,
      memo: memo,
      now: DateTime(2026, 10, 1),
    );

    Future<Visit> saveWithPhoto(String name, String? photoPath) =>
        repository.saveEatenVisit(
          shop: ShopInput(name: name),
          eatenAt: DateTime(2026, 9, 30, 12),
          photoPath: photoPath,
          now: DateTime(2026, 9, 30, 12, 5),
        );

    Future<String?> changePhoto(Visit visit, String? photoPath) =>
        repository.updateVisit(
          visitId: visit.id,
          shopName: '麺屋',
          hoursConditions: null,
          eatenAt: visit.eatenAt,
          checkedInAt: visit.checkedInAt,
          rating: visit.rating,
          style: visit.style,
          isLimited: visit.isLimited,
          hasTicket: visit.hasTicket,
          memo: visit.memo,
          changesPhoto: true,
          photoPath: photoPath,
          now: DateTime(2026, 10, 1),
        );

    test('写真を替えると新しいパスを保存し、使われなくなった前の写真のパスを返す', () async {
      final visit = await saveWithPhoto('麺屋', 'photos/old.jpg');

      final unused = await changePhoto(visit, 'photos/new.jpg');

      expect(unused, 'photos/old.jpg');
      final entry = (await repository.watchVisits().first).single;
      expect(entry.visit.photoPath, 'photos/new.jpg');
    });

    test('写真を外すと写真なしになり、前の写真のパスを返す', () async {
      final visit = await saveWithPhoto('麺屋', 'photos/old.jpg');

      final unused = await changePhoto(visit, null);

      expect(unused, 'photos/old.jpg');
      final entry = (await repository.watchVisits().first).single;
      expect(entry.visit.photoPath, isNull);
    });

    test('前の写真をほかの記録も使っていれば、消してよいパスとして返さない', () async {
      final visit = await saveWithPhoto('麺屋', 'photos/shared.jpg');
      await saveWithPhoto('麺屋', 'photos/shared.jpg');

      final unused = await changePhoto(visit, 'photos/new.jpg');

      expect(unused, isNull);
    });

    test('写真を変えないときは前の写真を残し、何も返さない', () async {
      final visit = await saveWithPhoto('麺屋', 'photos/old.jpg');

      final unused = await update(visit, shopName: '麺屋');

      expect(unused, isNull);
      final entry = (await repository.watchVisits().first).single;
      expect(entry.visit.photoPath, 'photos/old.jpg');
    });

    test('記録の内容と店の営業の条件を書き換える', () async {
      final visit = await save(const ShopInput(name: '麺屋'));

      await repository.updateVisit(
        visitId: visit.id,
        shopName: '麺屋',
        hoursConditions: {HoursCondition.lunchOnly},
        eatenAt: DateTime(2026, 9, 29, 11),
        checkedInAt: DateTime(2026, 9, 29, 10, 20),
        rating: 2,
        style: RamenStyle.miso,
        isLimited: true,
        hasTicket: true,
        memo: '書き直した',
        now: DateTime(2026, 10, 1),
      );

      final entry = (await repository.watchVisits().first).single;
      expect(entry.visit.id, visit.id);
      expect(entry.visit.eatenAt, DateTime(2026, 9, 29, 11));
      expect(entry.visit.checkedInAt, DateTime(2026, 9, 29, 10, 20));
      expect(entry.visit.rating, 2);
      expect(entry.visit.style, RamenStyle.miso);
      expect(entry.visit.isLimited, isTrue);
      expect(entry.visit.hasTicket, isTrue);
      expect(entry.visit.memo, '書き直した');
      expect(entry.shop.hoursConditions, {HoursCondition.lunchOnly});
    });

    test('ほかに記録の無い手入力の店は、位置を残したまま名前を直す', () async {
      final visit = await save(
        const ShopInput(name: '麺やテスト', latitude: 35.0, longitude: 139.0),
      );

      await update(visit, shopName: ' 麺屋テスト ');

      final shop = (await repository.allShops()).single;
      expect(shop.id, visit.shopId);
      expect(shop.name, '麺屋テスト');
      expect(shop.latitude, 35.0);
    });

    test('ほかにも記録のある店の名前を変えると、その記録だけを新しい店に付け替える', () async {
      final first = await save(const ShopInput(name: '麺屋'));
      final second = await save(const ShopInput(name: '麺屋'));

      await update(second, shopName: '別の店');

      final visits = await repository.watchVisits().first;
      final names = {for (final v in visits) v.visit.id: v.shop.name};
      expect(names, {first.id: '麺屋', second.id: '別の店'});
      expect(await repository.allShops(), hasLength(2));
    });

    test('OSMの店を選び間違えたときは、元の店を書き換えずに付け替える', () async {
      final visit = await save(const ShopInput(osmId: 'node/1', name: '一風堂'));

      await update(visit, shopName: '本当に行った店');

      final shop = (await repository.allShops()).single;
      expect(shop.name, '本当に行った店');
      expect(shop.osmId, isNull);
    });

    test('記録済みの店の名前に変えると、その店の記録になる', () async {
      final known = await save(const ShopInput(osmId: 'node/1', name: '一風堂'));
      final visit = await save(const ShopInput(name: 'いっぷうどう'));

      await update(visit, shopName: '一風堂');

      final visits = await repository.watchVisits().first;
      expect(visits.map((v) => v.shop.id).toSet(), {known.shopId});
      expect(await repository.allShops(), hasLength(1));
    });

    test('営業の条件を変えずに別の店へ付け替えても、その店の値を変えない', () async {
      await save(
        const ShopInput(name: '週2日の店'),
        hoursConditions: {HoursCondition.weekdaysOnly, HoursCondition.fewDays},
      );
      await save(const ShopInput(name: '週2日の店'));
      final typo = await save(const ShopInput(name: '週2日のみせ'));

      await update(typo, shopName: '週2日の店');

      final shop = (await repository.allShops()).single;
      expect(shop.hoursConditions, {
        HoursCondition.weekdaysOnly,
        HoursCondition.fewDays,
      });
    });

    test('新しい店に付け替えるときは、元の店の営業の条件を引き継ぐ', () async {
      await save(
        const ShopInput(name: '麺屋'),
        hoursConditions: {HoursCondition.lunchOnly},
      );
      final second = await save(const ShopInput(name: '麺屋'));

      await update(second, shopName: '別の店');

      final shops = await repository.allShops();
      expect(
        {for (final shop in shops) shop.name: shop.hoursConditions},
        {
          '麺屋': {HoursCondition.lunchOnly},
          '別の店': {HoursCondition.lunchOnly},
        },
      );
    });

    test('同じ名前の支店が複数あるときは、元の店に近い方へ付け替える', () async {
      final far = await save(
        const ShopInput(name: '一蘭', latitude: 35.05, longitude: 139.0),
      );
      final near = await save(
        const ShopInput(name: '一蘭', latitude: 35.001, longitude: 139.0),
      );
      final typo = await save(
        const ShopInput(name: 'いちらん', latitude: 35.0, longitude: 139.0),
      );

      await update(typo, shopName: '一蘭');

      final visits = await repository.watchVisits().first;
      final moved = visits.firstWhere((v) => v.visit.id == typo.id);
      expect(moved.shop.id, near.shopId);
      expect(moved.shop.id, isNot(far.shopId));
    });

    test('店名を空にしても元の店のままにする', () async {
      final visit = await save(const ShopInput(name: '麺屋'));

      await update(visit, shopName: '  ');

      expect((await repository.allShops()).single.name, '麺屋');
    });
  });

  group('deleteVisit', () {
    test('記録を削除して写真のパスを返し、記録の無くなった店も消す', () async {
      final visit = await repository.saveEatenVisit(
        shop: const ShopInput(name: '麺屋'),
        eatenAt: DateTime(2026, 9, 30),
        rating: 3,
        photoPath: 'photos/a.jpg',
        now: DateTime(2026, 9, 30),
      );

      expect(await repository.deleteVisit(visit.id), 'photos/a.jpg');
      expect(await repository.watchVisits().first, isEmpty);
      expect(await repository.allShops(), isEmpty);
    });

    test('ほかに記録のある店は残す', () async {
      final first = await save(const ShopInput(name: '麺屋'));
      final second = await save(const ShopInput(name: '麺屋'));

      await repository.deleteVisit(second.id);

      final visits = await repository.watchVisits().first;
      expect(visits.single.visit.id, first.id);
      expect(await repository.allShops(), hasLength(1));
    });

    test('無い記録の削除は何もしない', () async {
      expect(await repository.deleteVisit('missing'), isNull);
    });
  });

  group('チェックイン', () {
    final checkedInAt = DateTime(2026, 9, 30, 11, 20);
    const shop = ShopInput(
      osmId: 'node/1',
      name: '麺屋',
      latitude: 35.0,
      longitude: 139.0,
    );

    test('チェックインすると並んでいる店と時刻を読み出せ、取り消すと無くなる', () async {
      expect(await repository.activeCheckin(), isNull);

      await repository.checkIn(shop: shop, at: checkedInAt);

      final checkin = (await repository.activeCheckin())!;
      expect(checkin.name, '麺屋');
      expect(checkin.osmId, 'node/1');
      expect(checkin.latitude, 35.0);
      expect(checkin.checkedInAt, checkedInAt);
      expect((await repository.watchActiveCheckin().first)!.name, '麺屋');
      // チェックインだけでは店も記録も増やさない。
      expect(await repository.allShops(), isEmpty);

      await repository.cancelCheckin();
      expect(await repository.activeCheckin(), isNull);
      expect(await repository.watchActiveCheckin().first, isNull);
    });

    test('チェックイン中に別の店へチェックインすると置き換える', () async {
      await repository.checkIn(shop: shop, at: checkedInAt);
      await repository.checkIn(
        shop: const ShopInput(name: '別の店'),
        at: checkedInAt.add(const Duration(minutes: 5)),
      );

      expect((await repository.activeCheckin())!.name, '別の店');
    });

    test('チェックイン時刻つきで食べた記録を保存すると、チェックインを終える', () async {
      await repository.checkIn(shop: shop, at: checkedInAt);

      final visit = await repository.saveEatenVisit(
        shop: shop,
        eatenAt: checkedInAt.add(const Duration(minutes: 35)),
        checkedInAt: checkedInAt,
        rating: 4,
        now: checkedInAt.add(const Duration(minutes: 40)),
      );

      expect(visit.checkedInAt, checkedInAt);
      expect(await repository.activeCheckin(), isNull);
      final saved = (await repository.watchVisits().first).single.visit;
      expect(saved.checkedInAt, checkedInAt);
    });

    test('チェックイン時刻なしで別の店の記録を保存しても、チェックインは続く', () async {
      await repository.checkIn(shop: shop, at: checkedInAt);

      await save(const ShopInput(name: '別の店'));

      expect((await repository.activeCheckin())!.name, '麺屋');
    });

    test('撤退すると、食べられなかった記録を残してチェックインを終える', () async {
      await repository.checkIn(shop: shop, at: checkedInAt);
      final checkin = (await repository.activeCheckin())!;
      final now = checkedInAt.add(const Duration(minutes: 50));

      await repository.saveRetreat(checkin: checkin, memo: '売り切れ', now: now);

      final entry = (await repository.watchVisits().first).single;
      expect(entry.visit.result, VisitResult.retreated);
      expect(entry.visit.checkedInAt, checkedInAt);
      expect(entry.visit.eatenAt, now);
      expect(entry.visit.rating, isNull);
      expect(entry.visit.photoPath, isNull);
      expect(entry.visit.memo, '売り切れ');
      expect(entry.shop.name, '麺屋');
      expect(entry.shop.osmId, 'node/1');
      expect(await repository.activeCheckin(), isNull);
    });

    test('撤退すると、その店を願掛け帳に入れ、次に食べると願が叶う', () async {
      await repository.checkIn(shop: shop, at: checkedInAt);
      await repository.saveRetreat(
        checkin: (await repository.activeCheckin())!,
        wishTrigger: '撤退した店',
        now: checkedInAt,
      );
      final wishes = WishRepository(database);
      final wish = (await wishes.watchWishes().first).single;
      expect(wish.name, '麺屋');
      expect(wish.trigger, '撤退した店');
      expect(wish.fulfilledVisitId, isNull);

      // もう一度撤退しても、願は増えない。
      await repository.checkIn(shop: shop, at: checkedInAt);
      await repository.saveRetreat(
        checkin: (await repository.activeCheckin())!,
        wishTrigger: '撤退した店',
        now: checkedInAt.add(const Duration(days: 1)),
      );
      expect(await wishes.watchWishes().first, hasLength(1));

      final eaten = await save(shop);
      expect(
        (await wishes.watchWishes().first).single.fulfilledVisitId,
        eaten.id,
      );
    });

    test('撤退した店で次に食べると、同じ店の記録になる', () async {
      await repository.checkIn(shop: shop, at: checkedInAt);
      final retreat = await repository.saveRetreat(
        checkin: (await repository.activeCheckin())!,
        now: checkedInAt,
      );

      final eaten = await save(shop);

      expect(eaten.shopId, retreat.shopId);
      expect(await repository.allShops(), hasLength(1));
    });
  });

  group('updateVisit で店を選び直す', () {
    Future<void> repick(
      Visit visit,
      ShopInput picked, {
      Set<HoursCondition>? hoursConditions,
    }) => repository.updateVisit(
      visitId: visit.id,
      shopName: picked.name,
      hoursConditions: hoursConditions,
      eatenAt: visit.eatenAt,
      checkedInAt: visit.checkedInAt,
      rating: visit.rating,
      style: visit.style,
      isLimited: visit.isLimited,
      hasTicket: visit.hasTicket,
      memo: visit.memo,
      pickedShop: picked,
      now: DateTime(2026, 10, 5),
    );

    Future<Visit> visitById(String id) async =>
        (await repository.watchVisits().first)
            .singleWhere((entry) => entry.visit.id == id)
            .visit;

    test('記録済みの店を選ぶと、この記録だけをその店に付け替え、空になった前の店を消す', () async {
      final wrong = await save(
        const ShopInput(name: '麺屋まちがい', latitude: 35.0, longitude: 139.0),
      );
      final right = await save(
        const ShopInput(osmId: 'node/9', name: '麺屋ただしい'),
      );

      await repick(wrong, ShopInput(shopId: right.shopId, name: '麺屋ただしい'));

      expect((await visitById(wrong.id)).shopId, right.shopId);
      final shops = await repository.allShops();
      expect(shops.map((shop) => shop.id), [right.shopId]);
    });

    test('前の店にほかの記録があれば、前の店は残す', () async {
      final first = await save(const ShopInput(name: '麺屋まちがい'));
      final second = await save(const ShopInput(name: '麺屋まちがい'));
      final right = await save(const ShopInput(name: '麺屋ただしい'));

      await repick(second, ShopInput(shopId: right.shopId, name: '麺屋ただしい'));

      expect((await visitById(first.id)).shopId, first.shopId);
      expect((await visitById(second.id)).shopId, right.shopId);
      expect(await repository.allShops(), hasLength(2));
    });

    test('初めての店を選ぶと、位置・ID・出所つきの店を作って付け替える', () async {
      final visit = await save(const ShopInput(name: '手入力の店'));

      await repick(
        visit,
        const ShopInput(
          osmId: 'node/1',
          name: '麺屋みつけた',
          latitude: 35.5,
          longitude: 139.5,
          dataSource: ShopSource(licenses: ['ODbL-1.0']),
        ),
        hoursConditions: {HoursCondition.nightOnly},
      );

      final entry = (await repository.watchVisits().first).single;
      expect(entry.visit.id, visit.id);
      expect(entry.shop.id, isNot(visit.shopId));
      expect(entry.shop.name, '麺屋みつけた');
      expect(entry.shop.osmId, 'node/1');
      expect(entry.shop.latitude, 35.5);
      expect(entry.shop.longitude, 139.5);
      expect(entry.shop.dataSource?.licenses, ['ODbL-1.0']);
      expect(entry.shop.hoursConditions, {HoursCondition.nightOnly});
      expect(await repository.allShops(), hasLength(1));
    });

    test('OpenStreetMap の ID が同じ記録済みの店があれば、その店に付け替える', () async {
      final visit = await save(const ShopInput(name: '手入力の店'));
      final known = await save(
        const ShopInput(
          osmId: 'node/1',
          name: '麺屋みつけた',
          latitude: 35.5,
          longitude: 139.5,
        ),
      );

      await repick(
        visit,
        const ShopInput(
          osmId: 'node/1',
          name: '麺屋みつけた',
          latitude: 35.5,
          longitude: 139.5,
        ),
      );

      expect((await visitById(visit.id)).shopId, known.shopId);
      expect(await repository.allShops(), hasLength(1));
    });

    test('同じ名前で300m以内の記録済みの店があれば、その店に付け替える', () async {
      final visit = await save(const ShopInput(name: '手入力の店'));
      final known = await save(
        const ShopInput(name: '麺屋', latitude: 35.0, longitude: 139.0),
      );

      await repick(
        visit,
        const ShopInput(name: '麺屋', latitude: 35.001, longitude: 139.0),
      );

      expect((await visitById(visit.id)).shopId, known.shopId);
    });

    test('前の店で叶えた願はまだの願に戻し、選んだ願の店なら叶える', () async {
      final wishes = WishRepository(database);
      final wrongWish = await wishes.addWish(
        shop: const ShopInput(name: '麺屋まちがい'),
        now: DateTime(2026, 9, 1),
      );
      final rightWish = await wishes.addWish(
        shop: const ShopInput(
          osmId: 'node/2',
          name: '麺屋ただしい',
          latitude: 35.0,
          longitude: 139.0,
        ),
        now: DateTime(2026, 9, 1),
      );
      final visit = await repository.saveEatenVisit(
        shop: ShopInput(name: '麺屋まちがい', wishId: wrongWish.id),
        eatenAt: DateTime(2026, 9, 30, 12),
        now: DateTime(2026, 9, 30, 12),
      );

      await repick(
        visit,
        ShopInput(
          osmId: 'node/2',
          name: '麺屋ただしい',
          latitude: 35.0,
          longitude: 139.0,
          wishId: rightWish.id,
        ),
      );

      final byId = {
        for (final wish in await wishes.watchWishes().first) wish.id: wish,
      };
      expect(byId[wrongWish.id]!.fulfilledVisitId, isNull);
      expect(byId[wrongWish.id]!.shopId, isNull);
      expect(byId[rightWish.id]!.fulfilledVisitId, visit.id);
      expect(byId[rightWish.id]!.shopId, (await visitById(visit.id)).shopId);
    });

    test('前の店を消すとき、その店に並んでいる最中なら店のIDだけを外して並びは続ける', () async {
      final visit = await save(const ShopInput(name: '麺屋まちがい'));
      await repository.checkIn(
        shop: ShopInput(shopId: visit.shopId, name: '麺屋まちがい'),
        at: DateTime(2026, 10, 5, 11),
      );

      await repick(visit, const ShopInput(name: '麺屋ただしい'));

      final checkin = (await repository.activeCheckin())!;
      expect(checkin.shopId, isNull);
      expect(checkin.name, '麺屋まちがい');
      expect(checkin.checkedInAt, DateTime(2026, 10, 5, 11));
    });

    test('今の店を選んだときは何も付け替えない', () async {
      final visit = await save(
        const ShopInput(name: '麺屋', latitude: 35.0, longitude: 139.0),
      );

      await repick(visit, ShopInput(shopId: visit.shopId, name: '麺屋'));

      expect((await visitById(visit.id)).shopId, visit.shopId);
      expect(await repository.allShops(), hasLength(1));
    });
  });

  test('店の攻略メモを保存でき、記録を読むと店と一緒に出る', () async {
    final visit = await save(const ShopInput(name: '麺屋'));

    await repository.setShopMemo(visit.shopId, ' 券売機は現金のみ ');

    final entry = (await repository.watchVisits().first).single;
    expect(entry.shop.strategyMemo, '券売機は現金のみ');
  });
}
