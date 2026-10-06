import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/record/photo_metadata.dart';
import 'package:ramen_in_cho/features/record/photo_picker.dart';
import 'package:ramen_in_cho/features/record/record_controller.dart';
import 'package:ramen_in_cho/features/record/record_draft.dart';
import 'package:ramen_in_cho/features/record/record_state.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/records/wait_time.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';
import 'package:ramen_in_cho/features/shop_search/overpass.dart';
import 'package:ramen_in_cho/features/shop_search/nearby_shop_finder.dart';
import 'package:ramen_in_cho/features/shop_search/ramen_in_cho_api.dart';
import 'package:ramen_in_cho/features/shop_search/shop_search_service.dart';
import 'package:ramen_in_cho/features/wishes/shared_wish.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

import '../../support/fakes.dart';

const _here = GeoPoint(35.0, 139.0);
final _photoTime = DateTime(2026, 9, 30, 12);

void main() {
  late Directory documents;
  late FakeLocationService location;
  late FakeShopFinder overpass;
  late FakePhotoPicker picker;
  late FakePhotoMetadataReader metadata;
  late ProviderContainer container;
  late AppDatabase database;
  late Future<GeoPoint?> Function(String) geocoder;

  /// 記録画面を開き直したとき（前の画面の状態は残らず、documents と記録だけが残る）。
  ProviderContainer newSession() {
    final session = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        documentsDirectoryProvider.overrideWithValue(documents),
        locationServiceProvider.overrideWithValue(location),
        nearbyShopFinderProvider.overrideWithValue(overpass),
        photoPickerProvider.overrideWithValue(picker),
        photoMetadataReaderProvider.overrideWithValue(metadata),
        clockProvider.overrideWithValue(() => _photoTime),
        addressGeocoderProvider.overrideWithValue(
          (address) => geocoder(address),
        ),
      ],
    );
    addTearDown(session.dispose);
    session.listen(recordControllerProvider, (_, _) {});
    return session;
  }

  setUp(() {
    documents = createTempDirectory();
    final photo = File(p.join(createTempDirectory().path, 'camera.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    location = FakeLocationService(position: _here);
    overpass = FakeShopFinder(
      shops: const [
        FoundShop(
          osmId: 'node/1',
          name: '麺屋テスト',
          location: GeoPoint(35.001, 139.0),
        ),
      ],
    );
    picker = FakePhotoPicker(cameraPath: photo.path, galleryPath: photo.path);
    metadata = FakePhotoMetadataReader();
    database = createTestDatabase();
    geocoder = (_) async => null;
    // autoDisposeのため、テスト中は購読して破棄されないようにする（newSession の中で購読する）。
    container = newSession();
  });

  RecordController controller() =>
      container.read(recordControllerProvider.notifier);
  RecordState state() => container.read(recordControllerProvider);
  Future<List<VisitWithShop>> visits() =>
      container.read(recordRepositoryProvider).watchVisits().first;

  test('写真を撮ると近くの店が候補に出て、選んで★をつければ保存できる', () async {
    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();

    expect(state().photoPath, isNotNull);
    expect(state().searchStatus, ShopSearchStatus.done);
    expect(state().candidates.single.name, '麺屋テスト');
    expect(state().canSave, isFalse);

    controller().selectShop(state().candidates.single);
    expect(state().canSave, isTrue);
    controller().setRating(4);

    expect(await controller().save(), isNotNull);

    final entry = (await visits()).single;
    expect(entry.shop.name, '麺屋テスト');
    expect(entry.shop.osmId, 'node/1');
    expect(entry.shop.latitude, 35.001);
    expect(entry.visit.rating, 4);
    expect(entry.visit.eatenAt, _photoTime);
    final photo = File(p.join(documents.path, entry.visit.photoPath!));
    expect(photo.readAsBytesSync(), [1, 2, 3]);
  });

  test('通信できないときは手入力で保存でき、現在地が店の位置になる', () async {
    overpass.error = const SocketException('offline');

    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();

    expect(state().searchStatus, ShopSearchStatus.done);
    expect(state().searchFailure, ShopSearchFailure.searchFailed);
    expect(state().candidates, isEmpty);

    controller().setManualName('電波のない店');
    controller().setRating(3);
    expect(await controller().save(), isNotNull);

    final entry = (await visits()).single;
    expect(entry.shop.name, '電波のない店');
    expect(entry.shop.osmId, isNull);
    expect(entry.shop.latitude, 35.0);
    expect(entry.shop.longitude, 139.0);
  });

  test('検索が時間切れでも手入力で保存できる', () async {
    overpass.error = TimeoutException('timeout');

    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();
    controller().setManualName('遅い回線の店');
    controller().setRating(3);

    expect(state().searchFailure, ShopSearchFailure.searchFailed);
    expect(await controller().save(), isNotNull);
    expect((await visits()).single.shop.name, '遅い回線の店');
  });

  test('位置情報が取れないときは検索せず、手入力で保存できる', () async {
    location
      ..ready = false
      ..position = null;

    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();

    expect(location.requests, [true]);
    expect(overpass.calls, 0);
    expect(state().searchFailure, ShopSearchFailure.noLocation);

    controller().setManualName('手入力の店');
    controller().setRating(5);
    expect(await controller().save(), isNotNull);

    final entry = (await visits()).single;
    expect(entry.shop.name, '手入力の店');
    expect(entry.shop.latitude, isNull);
  });

  test('開いただけでは店を探さず、位置情報の許可も尋ねない。カメラで撮ると現在地で探す', () async {
    location.ready = false;
    await controller().start();
    await pumpEventQueue();

    expect(location.requests, isEmpty);
    expect(overpass.calls, 0);
    expect(state().searchStatus, ShopSearchStatus.idle);

    await controller().takePhoto();
    await pumpEventQueue();

    expect(location.requests, [true]);
    expect(overpass.calls, 1);
    expect(overpass.centers.single.latitude, _here.latitude);
    expect(state().candidates.single.name, '麺屋テスト');
  });

  test('位置情報が許可済みなら、開いたときに現在地だけ取り、店名で探すときの基準にする', () async {
    await controller().start();
    await pumpEventQueue();

    expect(location.requests, [false]);
    expect(overpass.calls, 0);
    expect(controller().searchCenter, _here);
  });

  test('撮影場所の無いギャラリーの写真では、現在地で探す', () async {
    await controller().start();
    await controller().pickFromGallery();
    await pumpEventQueue();

    expect(location.requests.last, isTrue);
    expect(overpass.centers.single.latitude, _here.latitude);
    expect(state().candidates.single.name, '麺屋テスト');
  });

  test('候補が0件でも手入力で保存できる', () async {
    overpass.shops = const [];

    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();

    expect(state().candidates, isEmpty);
    expect(state().searchFailure, isNull);

    controller().setManualName('地図にない店');
    controller().setRating(2);
    expect(await controller().save(), isNotNull);
  });

  test('カメラをキャンセルしても、写真なしで保存できる', () async {
    picker.cameraPath = null;

    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();

    expect(state().photoPath, isNull);

    controller().setManualName('写真なしの店');
    controller().setRating(3);
    expect(await controller().save(), isNotNull);

    final entry = (await visits()).single;
    expect(entry.visit.photoPath, isNull);
    expect(entry.visit.eatenAt, _photoTime);
  });

  test('ギャラリーから選んだ写真では、現在地を手入力の店の位置にしない', () async {
    picker.cameraPath = null;

    await controller().start();
    await controller().takePhoto();
    await controller().pickFromGallery();
    await pumpEventQueue();
    controller().setManualName('家で記録した店');
    controller().setRating(3);
    await controller().save();

    final entry = (await visits()).single;
    expect(entry.visit.photoPath, isNotNull);
    expect(entry.shop.latitude, isNull);
  });

  group('待ち時間をあとから入れる', () {
    test('入れた分だけ前を並んだ時刻にして保存する', () async {
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().setManualName('並んだ店');
      controller().setWaitMinutes(25);
      await controller().save();

      final visit = (await visits()).single.visit;
      expect(
        visit.checkedInAt,
        _photoTime.subtract(const Duration(minutes: 25)),
      );
      expect(waitMinutes(visit), 25);
    });

    test('空にすれば待ち時間なし', () async {
      await controller().start();
      await controller().takePhoto();
      controller().setManualName('並ばなかった店');
      controller().setWaitMinutes(25);
      controller().setWaitMinutes(null);
      await controller().save();

      expect((await visits()).single.visit.checkedInAt, isNull);
    });
  });

  group('過去の写真から記録する', () {
    final takenAt = DateTime(2026, 9, 20, 12, 34);
    const shopPlace = GeoPoint(35.6, 139.7);

    test('ギャラリーの写真に撮影日時があれば、それを食べた日時にする', () async {
      picker.cameraPath = null;
      metadata.metadata = PhotoMetadata(takenAt: takenAt);

      await controller().start();
      await controller().takePhoto();
      await controller().pickFromGallery();
      await pumpEventQueue();

      expect(state().photoTakenAt, takenAt);
      expect(state().photoDateFromPhoto, isTrue);
      controller().setManualName('昔の店');
      await controller().save();

      expect((await visits()).single.visit.eatenAt, takenAt);
    });

    test('撮影日時が無い写真は、今の時刻で記録する', () async {
      picker.cameraPath = null;

      await controller().start();
      await controller().takePhoto();
      await controller().pickFromGallery();

      expect(state().photoTakenAt, _photoTime);
      expect(state().photoDateFromPhoto, isFalse);
    });

    test('撮影場所があれば、そこで店を探し、手入力の店の位置にもする', () async {
      picker.cameraPath = null;
      metadata.metadata = PhotoMetadata(takenAt: takenAt, location: shopPlace);

      await controller().start();
      await controller().pickFromGallery();
      await pumpEventQueue();

      expect(overpass.centers.single.latitude, shopPlace.latitude);
      expect(location.requests, isNot(contains(true)));
      expect(state().searchStatus, ShopSearchStatus.done);

      controller().setManualName('写真の場所の店');
      await controller().save();

      final shop = (await visits()).single.shop;
      expect(shop.latitude, shopPlace.latitude);
      expect(shop.longitude, shopPlace.longitude);
    });

    test('昔の写真のあとにカメラで撮り直すと、今の時刻と現在地に戻る', () async {
      metadata.metadata = PhotoMetadata(takenAt: takenAt, location: shopPlace);

      await controller().start();
      await controller().takePhoto();
      await controller().pickFromGallery();
      await pumpEventQueue();
      await controller().takePhoto();
      await pumpEventQueue();

      expect(state().photoTakenAt, _photoTime);
      expect(state().photoDateFromPhoto, isFalse);
      expect(state().photoLocation, isNull);
      expect(overpass.centers.last.latitude, _here.latitude);
    });

    test('カメラで撮った写真は、撮影日時を読まない', () async {
      await controller().start();
      await controller().takePhoto();

      expect(metadata.paths, isEmpty);
    });
  });

  group('地図アプリから共有された店で記録する', () {
    SharedWish shared(String text) => parseSharedWish(text)!;

    test('リンクの座標の店を選んだ状態で始まり、今の時刻で保存できる', () async {
      await controller().start(
        sharedPlace: shared(
          'https://www.google.com/maps/place/X/@35.4,139.6,17z/data=!3d35.4437!4d139.6380',
        ),
      );

      expect(state().selectedShop!.name, 'X');
      expect(state().selectedShop!.location!.latitude, 35.4437);
      controller().setRating(4);
      expect(await controller().save(), isNotNull);
      final saved = (await visits()).single;
      expect(saved.shop.latitude, 35.4437);
      expect(saved.visit.eatenAt, _photoTime);
    });

    test('住所しかなければサーバーで位置にする', () async {
      final asked = <String>[];
      geocoder = (address) async {
        asked.add(address);
        return const GeoPoint(43.0621, 141.3544);
      };

      await controller().start(
        sharedPlace: shared(
          '札幌味噌 ゆきだるま\n北海道札幌市中央区南2条西3丁目4-5\nhttps://maps.app.goo.gl/Snow1',
        ),
      );

      expect(asked, ['北海道札幌市中央区南2条西3丁目4-5']);
      expect(state().selectedShop!.name, '札幌味噌 ゆきだるま');
      expect(state().selectedShop!.location!.longitude, 141.3544);
    });

    test('位置がわからなければ店名だけを入れる', () async {
      await controller().start(
        sharedPlace: shared('中華そば つばめ https://maps.app.goo.gl/Xyz987'),
      );

      expect(state().selectedShop, isNull);
      expect(state().manualName, '中華そば つばめ');
    });

    test('記録済みの同じ店があれば、その店を選ぶ', () async {
      final visit = await container
          .read(recordRepositoryProvider)
          .saveEatenVisit(
            shop: const ShopInput(
              name: '横浜家系 はま',
              latitude: 35.4660,
              longitude: 139.6223,
            ),
            eatenAt: DateTime(2026, 9, 1),
            now: DateTime(2026, 9, 1),
          );

      await controller().start(
        sharedPlace: shared(
          '横浜家系 はま\nhttps://maps.google.com/?q=35.4661,139.6224',
        ),
      );

      expect(state().selectedShop!.shopId, visit.shopId);
    });

    test('願を掛けた店なら、その願を選んで保存すると叶う', () async {
      final wish = await container
          .read(wishRepositoryProvider)
          .addWish(
            shop: const ShopInput(name: '新宿の煮干し屋'),
            now: DateTime(2026, 9, 1),
          );

      await controller().start(
        sharedPlace: shared(
          '新宿の煮干し屋\nhttps://maps.google.com/?q=35.6900,139.7000',
        ),
      );

      expect(state().selectedShop!.wishId, wish.id);
      expect(await controller().save(), isNotNull);
      final saved =
          (await container.read(wishRepositoryProvider).watchWishes().first)
              .single;
      expect(saved.fulfilledVisitId, isNotNull);
    });

    test('店名だけの願は、名前が似ているだけでは選ばない', () async {
      await container
          .read(wishRepositoryProvider)
          .addWish(
            shop: const ShopInput(name: '一蘭'),
            now: DateTime(2026, 9, 1),
          );

      await controller().start(
        sharedPlace: shared(
          '一蘭 新宿中央東口店\nhttps://maps.google.com/?q=35.6900,139.7000',
        ),
      );

      expect(state().selectedShop!.wishId, isNull);
      expect(state().selectedShop!.name, '一蘭 新宿中央東口店');
    });

    test('下書きの店はそのまま残す', () async {
      await controller().start();
      controller().setManualName('下書きの店');
      await pumpEventQueue();
      container = newSession();

      await controller().start(
        sharedPlace: shared(
          '共有した店\nhttps://maps.google.com/?q=35.6900,139.7000',
        ),
      );

      expect(state().manualName, '下書きの店');
      expect(state().selectedShop, isNull);
    });
  });

  test('店名を入力すると候補の選択は外れ、記録済みの店が名前の候補に出る', () async {
    await container
        .read(recordRepositoryProvider)
        .saveEatenVisit(
          shop: const ShopInput(name: '行きつけの麺屋'),
          eatenAt: DateTime(2026, 9, 1),
          rating: 5,
          now: DateTime(2026, 9, 1),
        );

    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();
    controller().selectShop(state().candidates.single);
    controller().setManualName('行きつけ');

    expect(state().selectedShop, isNull);
    expect(state().nameMatches.single.name, '行きつけの麺屋');

    controller().selectShop(state().nameMatches.single);
    controller().setRating(4);

    expect(state().manualName, '');
    expect(await controller().save(), isNotNull);
    expect(
      await container.read(recordRepositoryProvider).allShops(),
      hasLength(1),
    );
    expect(await visits(), hasLength(2));
  });

  test('アプリが終了させられて取り戻した写真では、現在地を店の位置にしない', () async {
    await controller().start(recoveredPhotoPath: picker.cameraPath);
    await pumpEventQueue();
    controller().setManualName('取り戻した写真の店');
    controller().setRating(3);
    await controller().save();

    final entry = (await visits()).single;
    expect(entry.visit.photoPath, isNotNull);
    expect(entry.shop.latitude, isNull);
  });

  group('チェックイン中', () {
    final checkedInAt = _photoTime.subtract(const Duration(minutes: 35));

    Future<void> checkIn({DateTime? at}) => container
        .read(recordRepositoryProvider)
        .checkIn(
          shop: const ShopInput(
            osmId: 'node/9',
            name: '並んだ店',
            latitude: 35.0,
            longitude: 139.0,
          ),
          at: at ?? checkedInAt,
        );

    test('地図アプリから別の店を共有されたら、その店に替える（並びは続く）', () async {
      await checkIn();

      await controller().start(
        sharedPlace: parseSharedWish(
          '共有した店\nhttps://maps.google.com/?q=35.6900,139.7000',
        ),
      );

      expect(state().selectedShop!.name, '共有した店');
      expect(state().checkin, isNotNull);
    });

    test('共有された店が並んでいる店なら、並んだ店のまま', () async {
      await checkIn();

      await controller().start(
        sharedPlace: parseSharedWish(
          '並んだ店\nhttps://maps.google.com/?q=35.0001,139.0001',
        ),
      );

      expect(identical(state().selectedShop, state().checkinShop), isTrue);
    });

    test('並んだ店が選ばれた状態で始まり、★だけで保存すると待ち時間がつく', () async {
      await checkIn();

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();

      expect(state().selectedShop!.name, '並んだ店');
      expect(state().isCheckinShopSelected, isTrue);

      controller().setRating(5);
      expect(await controller().save(), isNotNull);

      final entry = (await visits()).single;
      expect(entry.shop.name, '並んだ店');
      expect(entry.shop.osmId, 'node/9');
      expect(entry.visit.checkedInAt, checkedInAt);
      expect(entry.visit.eatenAt, _photoTime);
      expect(waitMinutes(entry.visit), 35);
      expect(
        await container.read(recordRepositoryProvider).activeCheckin(),
        isNull,
      );
    });

    test('開いたときは探さず、写真を撮ると候補を探しても並んだ店は選んだまま', () async {
      await checkIn();

      await controller().start();
      await pumpEventQueue();
      expect(overpass.calls, 0);
      expect(state().isCheckinShopSelected, isTrue);

      await controller().takePhoto();
      await pumpEventQueue();

      expect(overpass.calls, 1);
      expect(state().candidates, isNotEmpty);
      expect(state().isCheckinShopSelected, isTrue);
    });

    test('並んでいる最中に、並ぶ前に撮った写真で記録しても待ち時間はつけない', () async {
      await checkIn();
      metadata.metadata = PhotoMetadata(
        takenAt: checkedInAt.subtract(const Duration(days: 1)),
      );

      await controller().start();
      await controller().takePhoto();
      await controller().pickFromGallery();
      await pumpEventQueue();
      expect(state().isCheckinShopSelected, isTrue);
      expect(await controller().save(), isNotNull);

      expect((await visits()).single.visit.checkedInAt, isNull);
    });

    test('別の店で待ち時間を手で入れても、並んでいる店のチェックインは続く', () async {
      await checkIn();

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().setManualName('別の店');
      controller().setWaitMinutes(10);
      expect(await controller().save(), isNotNull);

      expect(waitMinutes((await visits()).single.visit), 10);
      expect(
        await container.read(recordRepositoryProvider).activeCheckin(),
        isNotNull,
      );
    });

    test('並んだ店を選んでいるときは、手で入れた待ち時間より並んだ時刻を使う', () async {
      await checkIn();

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().setWaitMinutes(99);
      await controller().save();

      expect(waitMinutes((await visits()).single.visit), 35);
    });

    test('別の店を選んで保存すると待ち時間はつかず、チェックインは続く', () async {
      await checkIn();

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().selectShop(state().candidates.single);
      expect(state().isCheckinShopSelected, isFalse);
      controller().setRating(3);
      await controller().save();

      final entry = (await visits()).single;
      expect(entry.shop.name, '麺屋テスト');
      expect(entry.visit.checkedInAt, isNull);
      expect(
        (await container.read(recordRepositoryProvider).activeCheckin())!.name,
        '並んだ店',
      );
    });

    test('並んだ店を検索結果や名前の候補から選び直しても、待ち時間がつく', () async {
      overpass.shops = const [
        FoundShop(
          osmId: 'node/9',
          name: '並んだ店',
          location: GeoPoint(35.0, 139.0),
        ),
      ];
      await checkIn();

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().selectShop(state().candidates.single);

      expect(state().isCheckinShopSelected, isTrue);
      controller().setRating(4);
      await controller().save();

      final entry = (await visits()).single;
      expect(entry.visit.checkedInAt, checkedInAt);
      expect(
        await container.read(recordRepositoryProvider).activeCheckin(),
        isNull,
      );
    });

    test('手入力でチェックインした店が検索結果に出たら、同じ店として扱う', () async {
      await container
          .read(recordRepositoryProvider)
          .checkIn(
            shop: const ShopInput(
              name: '麺屋テスト',
              latitude: 35.0,
              longitude: 139.0,
            ),
            at: checkedInAt,
          );

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().selectShop(state().candidates.single);

      expect(state().candidates.single.osmId, 'node/1');
      expect(state().isCheckinShopSelected, isTrue);
    });

    test('撮り直しても、最初に撮った時刻で待ち時間を計算する', () async {
      var now = _photoTime;
      container.updateOverrides([
        appDatabaseProvider.overrideWithValue(
          container.read(appDatabaseProvider),
        ),
        documentsDirectoryProvider.overrideWithValue(documents),
        locationServiceProvider.overrideWithValue(location),
        nearbyShopFinderProvider.overrideWithValue(overpass),
        photoPickerProvider.overrideWithValue(picker),
        photoMetadataReaderProvider.overrideWithValue(metadata),
        clockProvider.overrideWithValue(() => now),
        addressGeocoderProvider.overrideWithValue(
          (address) => geocoder(address),
        ),
      ]);
      await checkIn();

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      now = _photoTime.add(const Duration(minutes: 20));
      await controller().takePhoto();
      controller().setRating(4);
      await controller().save();

      final entry = (await visits()).single;
      expect(entry.visit.eatenAt, _photoTime);
      expect(waitMinutes(entry.visit), 35);
    });

    test('記録済みの店に並んでいるときは、その店の覚え書きも引き継ぐ', () async {
      final repository = container.read(recordRepositoryProvider);
      final first = await repository.saveEatenVisit(
        shop: const ShopInput(name: '行きつけの店'),
        eatenAt: DateTime(2026, 9, 1),
        now: DateTime(2026, 9, 1),
      );
      await repository.setShopMemo(first.shopId, '開店30分前で1巡目');
      await repository.checkIn(
        shop: ShopInput(shopId: first.shopId, name: '行きつけの店'),
        at: checkedInAt,
      );

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();

      expect(state().isCheckinShopSelected, isTrue);
      expect(state().selectedShop!.strategyMemo, '開店30分前で1巡目');
    });

    test('3時間を超えたチェックインは使わない', () async {
      await checkIn(at: _photoTime.subtract(const Duration(hours: 4)));

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();

      expect(state().checkin, isNull);
      expect(state().selectedShop, isNull);
    });

    group('真ん中の「着」から', () {
      final arrivedAt = _photoTime.subtract(const Duration(minutes: 10));

      test('すぐにカメラを開き、写真をあとで撮っても「着」の時刻で待ち時間が決まる', () async {
        await checkIn();

        await controller().start(arrivedAt: arrivedAt);
        // カメラは開いたあとに写真が入るので、入るまで待つ。
        for (var i = 0; i < 100 && state().photoPath == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        expect(picker.cameraOpens, 1);
        expect(state().photoPath, isNotNull);
        expect(state().isCheckinShopSelected, isTrue);
        expect(await controller().save(), isNotNull);

        final entry = (await visits()).single;
        expect(entry.visit.eatenAt, arrivedAt);
        expect(entry.visit.checkedInAt, checkedInAt);
        expect(waitMinutes(entry.visit), 25);
        expect(
          await container.read(recordRepositoryProvider).activeCheckin(),
          isNull,
        );
      });

      test('カメラをやめても、写真なしで同じ待ち時間で保存できる', () async {
        picker.cameraPath = null;
        await checkIn();

        await controller().start(arrivedAt: arrivedAt);
        await pumpEventQueue();

        expect(picker.cameraOpens, 1);
        expect(state().photoPath, isNull);
        expect(state().canSave, isTrue);
        await controller().save();

        final entry = (await visits()).single;
        expect(entry.visit.photoPath, isNull);
        expect(entry.visit.eatenAt, arrivedAt);
        expect(waitMinutes(entry.visit), 25);
      });

      test('保存する前にアプリが終わっても、次に開くと「着」の時刻から続けられる', () async {
        picker.cameraPath = null;
        await checkIn();
        await controller().start(arrivedAt: arrivedAt);
        await pumpEventQueue();
        expect(await controller().draftAwaitsArrivalPhoto(), isTrue);

        container = newSession();
        // もう一度「着」を押しても、先に押した時刻を使う。
        await controller().start(arrivedAt: _photoTime);
        await pumpEventQueue();

        expect(state().arrivedAt, arrivedAt);
        expect(state().isCheckinShopSelected, isTrue);
        await controller().save();
        expect(waitMinutes((await visits()).single.visit), 25);
      });

      test('アプリが終わっている間にチェックインが消えても、下書きの並びで待ち時間をつける', () async {
        picker.cameraPath = null;
        await checkIn();
        await controller().start(arrivedAt: arrivedAt);
        await pumpEventQueue();
        await container.read(recordRepositoryProvider).cancelCheckin();

        container = newSession();
        await controller().start();
        await pumpEventQueue();

        expect(state().selectedShop!.name, '並んだ店');
        await controller().save();
        final entry = (await visits()).single;
        expect(entry.shop.name, '並んだ店');
        expect(entry.shop.osmId, 'node/9');
        expect(waitMinutes(entry.visit), 25);
      });

      test('別の並びが始まっていれば、下書きの「着」は使わない', () async {
        picker.cameraPath = null;
        await checkIn();
        await controller().start(arrivedAt: arrivedAt);
        await pumpEventQueue();
        await checkIn(at: _photoTime.subtract(const Duration(minutes: 5)));

        container = newSession();
        await controller().start();
        await pumpEventQueue();

        expect(state().arrivedAt, isNull);
        expect(state().resumedFromDraft, isFalse);
      });

      test('別の店を選んで保存すると待ち時間はつかず、チェックインは続く', () async {
        await checkIn();

        await controller().start(arrivedAt: arrivedAt);
        for (var i = 0; i < 100 && state().photoPath == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        controller().selectShop(state().candidates.single);
        await controller().save();

        final entry = (await visits()).single;
        expect(entry.shop.name, '麺屋テスト');
        expect(entry.visit.checkedInAt, isNull);
        expect(entry.visit.eatenAt, _photoTime);
        expect(
          await container.read(recordRepositoryProvider).activeCheckin(),
          isNotNull,
        );
      });
    });

    test('並んだ店が選ばれているだけなら、確認なしで戻れる', () async {
      picker.cameraPath = null;
      await checkIn();

      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();

      expect(state().hasInput, isFalse);
    });
  });

  test('店が決まるまでは保存しない（★だけでは保存しない）', () async {
    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();

    expect(await controller().save(), isNull);
    controller().setRating(3);
    expect(await controller().save(), isNull);
    controller().setManualName('   ');
    expect(await controller().save(), isNull);
    expect(await visits(), isEmpty);
  });

  test('★を付けずに保存でき、あとから★を付けられる', () async {
    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();
    controller().selectShop(state().candidates.single);

    final visitId = await controller().save();

    expect(visitId, isNotNull);
    expect((await visits()).single.visit.rating, isNull);

    await container.read(recordRepositoryProvider).setRating(visitId!, 5);
    expect((await visits()).single.visit.rating, 5);
  });

  test('保存に失敗したら、コピーした写真を消して入力を続けられる', () async {
    await controller().start();
    await controller().takePhoto();
    await pumpEventQueue();
    controller().setManualName('麺屋');
    controller().setRating(3);
    await container.read(appDatabaseProvider).close();

    expect(await controller().save(), isNull);

    expect(state().isSaving, isFalse);
    expect(state().canSave, isTrue);
    final photos = Directory(p.join(documents.path, 'photos'));
    expect(photos.listSync(), isEmpty);
    // 保存できなかったので、下書きは残る。
    final draft = await container.read(recordDraftStoreProvider).load();
    expect(draft?.manualName, '麺屋');
    expect(File(draft!.photoPath!).existsSync(), isTrue);
  });

  group('下書き', () {
    Directory draftPhotos() => Directory(
      p.join(documents.path, FileRecordDraftStore.photoDirectoryName),
    );
    File draftFile() =>
        File(p.join(documents.path, FileRecordDraftStore.fileName));

    /// 書きかけの書き込みが終わるのを待つ（読み書きは順番に行われるため）。
    Future<RecordDraft?> flushed(ProviderContainer c) =>
        c.read(recordDraftStoreProvider).load();

    test('保存せずに閉じても入力が残り、次に開くとそこから再開する', () async {
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller()
        ..selectShop(state().candidates.single)
        ..setRating(4)
        ..setStyle(RamenStyle.iekei)
        ..setLimited(true)
        ..setMemo('かため')
        ..setShopMemo('券売機は現金のみ')
        ..setWaitMinutes(25);
      // 写真は一時ファイルではなく documents に写してある。
      expect(p.isWithin(draftPhotos().path, state().photoPath!), isTrue);
      await flushed(container);
      container.dispose();

      final next = newSession();
      await next.read(recordControllerProvider.notifier).start();
      final resumed = next.read(recordControllerProvider);

      expect(resumed.resumedFromDraft, isTrue);
      expect(File(resumed.photoPath!).readAsBytesSync(), [1, 2, 3]);
      expect(resumed.photoTakenAt, _photoTime);
      expect(resumed.photoFromCamera, isTrue);
      // 店が決まっている下書きでは、探し直さない。
      expect(resumed.searchStatus, ShopSearchStatus.idle);
      expect(resumed.selectedShop?.name, '麺屋テスト');
      expect(resumed.rating, 4);
      expect(resumed.style, RamenStyle.iekei);
      expect(resumed.isLimited, isTrue);
      expect(resumed.memo, 'かため');
      expect(resumed.shopMemo, '券売機は現金のみ');
      expect(resumed.manualWaitMinutes, 25);

      expect(
        await next.read(recordControllerProvider.notifier).save(),
        isNotNull,
      );
      final entry =
          (await next.read(recordRepositoryProvider).watchVisits().first)
              .single;
      expect(entry.shop.name, '麺屋テスト');
      expect(entry.shop.strategyMemo, '券売機は現金のみ');
      expect(entry.visit.memo, 'かため');
      expect(entry.visit.style, RamenStyle.iekei);
    });

    test('店の決まっていない写真つきの下書きは、再開すると写真で探し直す', () async {
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().setRating(4);
      await flushed(container);
      container.dispose();
      final calls = overpass.calls;

      final next = newSession();
      await next.read(recordControllerProvider.notifier).start();
      await pumpEventQueue();
      final resumed = next.read(recordControllerProvider);

      expect(resumed.resumedFromDraft, isTrue);
      expect(overpass.calls, calls + 1);
      expect(resumed.candidates.single.name, '麺屋テスト');
    });

    test('何も入れていなければ下書きは作らず、再開の案内も出さない', () async {
      await controller().start();
      await flushed(container);
      expect(draftFile().existsSync(), isFalse);

      controller().setManualName('麺');
      await flushed(container);
      expect(draftFile().existsSync(), isTrue);
      controller().setManualName('');
      await flushed(container);
      expect(draftFile().existsSync(), isFalse);
      container.dispose();

      final next = newSession();
      await next.read(recordControllerProvider.notifier).start();
      expect(next.read(recordControllerProvider).resumedFromDraft, isFalse);
    });

    test('「着丼！」で保存すると下書きと下書きの写真は消え、記録の写真は残る', () async {
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().setManualName('麺屋');

      expect(await controller().save(), isNotNull);

      expect(draftFile().existsSync(), isFalse);
      expect(draftPhotos().listSync(), isEmpty);
      final saved = (await visits()).single.visit.photoPath!;
      expect(File(p.join(documents.path, saved)).readAsBytesSync(), [1, 2, 3]);

      container.dispose();
      final next = newSession();
      await next.read(recordControllerProvider.notifier).start();
      final fresh = next.read(recordControllerProvider);
      expect(fresh.resumedFromDraft, isFalse);
      expect(fresh.photoPath, isNull);
      expect(fresh.manualName, isEmpty);
    });

    test('下書きを捨てると入力と下書きの写真が消え、記録済みの写真は消えない', () async {
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().setManualName('前の店');
      expect(await controller().save(), isNotNull);
      final saved = (await visits()).single.visit.photoPath!;
      container.dispose();

      final next = newSession();
      final nextController = next.read(recordControllerProvider.notifier);
      await nextController.start();
      await nextController.takePhoto();
      nextController
        ..setManualName('書きかけの店')
        ..setMemo('メモ');
      await flushed(next);
      expect(draftPhotos().listSync(), hasLength(1));

      await nextController.discardDraft();
      await flushed(next);

      final state = next.read(recordControllerProvider);
      expect(state.photoPath, isNull);
      expect(state.manualName, isEmpty);
      expect(state.memo, isEmpty);
      expect(state.resumedFromDraft, isFalse);
      // 写真ごと捨てたので、その写真で探した候補も消える。
      expect(state.candidates, isEmpty);
      expect(state.searchStatus, ShopSearchStatus.idle);
      expect(draftFile().existsSync(), isFalse);
      expect(draftPhotos().listSync(), isEmpty);
      expect(File(p.join(documents.path, saved)).existsSync(), isTrue);
    });

    test('撮り直すと前の下書きの写真は片付く', () async {
      await controller().start();
      await controller().takePhoto();
      final first = state().photoPath!;
      await controller().takePhoto();
      await flushed(container);

      expect(File(first).existsSync(), isFalse);
      expect(draftPhotos().listSync().single.path, state().photoPath);
    });

    String incomingPhoto() => (File(
      p.join(createTempDirectory().path, 'incoming.jpg'),
    )..writeAsBytesSync([4, 5, 6])).path;

    Future<ProviderContainer> leaveDraft({bool withPhoto = false}) async {
      await controller().start();
      if (withPhoto) await controller().takePhoto();
      controller().setManualName('書きかけの店');
      await flushed(container);
      container.dispose();
      return newSession();
    }

    test('写真を渡されて開くとき、下書きがあるかを確かめられる', () async {
      expect(await controller().hasDraft(), isFalse);
      final next = await leaveDraft();
      expect(
        await next.read(recordControllerProvider.notifier).hasDraft(),
        isTrue,
      );
    });

    test('下書きを破棄して新しく始めると、渡された写真だけの記録になる', () async {
      final next = await leaveDraft(withPhoto: true);
      final source = incomingPhoto();
      await next
          .read(recordControllerProvider.notifier)
          .start(recoveredPhotoPath: source, startOver: true);
      final state = next.read(recordControllerProvider);
      expect(state.resumedFromDraft, isFalse);
      expect(state.manualName, isEmpty);
      expect(File(state.photoPath!).readAsBytesSync(), [4, 5, 6]);
      final draft = await flushed(next);
      expect(draft?.photoPath, state.photoPath);
      expect(draft?.manualName, isEmpty);
      expect(draftPhotos().listSync().single.path, state.photoPath);
      expect(File(source).existsSync(), isTrue);
    });

    test('取り戻した写真で下書きの続きにすると、その写真を下書きに入れる（下書きを書く途中で撮った写真のため）', () async {
      final next = await leaveDraft(withPhoto: true);
      await next
          .read(recordControllerProvider.notifier)
          .start(recoveredPhotoPath: incomingPhoto());
      final state = next.read(recordControllerProvider);
      expect(state.resumedFromDraft, isTrue);
      expect(state.manualName, '書きかけの店');
      expect(File(state.photoPath!).readAsBytesSync(), [4, 5, 6]);
      expect((await flushed(next))?.photoPath, state.photoPath);
    });

    test('共有された写真で下書きの続きにすると、下書きに写真があればそちらを残す', () async {
      final next = await leaveDraft(withPhoto: true);
      final source = incomingPhoto();
      await next
          .read(recordControllerProvider.notifier)
          .start(recoveredPhotoPath: source, sharedPhoto: true);
      final state = next.read(recordControllerProvider);
      expect(state.manualName, '書きかけの店');
      expect(File(state.photoPath!).readAsBytesSync(), [1, 2, 3]);
      await flushed(next);
      expect(draftPhotos().listSync().single.path, state.photoPath);
      expect(File(source).existsSync(), isTrue);
    });

    test('共有された写真で下書きの続きにすると、下書きに写真が無ければ入れ、捨てても写真は残す', () async {
      final next = await leaveDraft();
      final nextController = next.read(recordControllerProvider.notifier);
      await nextController.start(
        recoveredPhotoPath: incomingPhoto(),
        sharedPhoto: true,
      );
      var state = next.read(recordControllerProvider);
      expect(state.manualName, '書きかけの店');
      expect(File(state.photoPath!).readAsBytesSync(), [4, 5, 6]);

      await nextController.discardDraft();
      await flushed(next);
      state = next.read(recordControllerProvider);
      expect(state.manualName, isEmpty);
      expect(File(state.photoPath!).readAsBytesSync(), [4, 5, 6]);
    });

    test('記録をやめて破棄すると下書きと下書きの写真だけが消え、そのあとの入力も書かない', () async {
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller().setManualName('前の店');
      expect(await controller().save(), isNotNull);
      final saved = (await visits()).single.visit.photoPath!;
      container.dispose();

      final next = newSession();
      final nextController = next.read(recordControllerProvider.notifier);
      await nextController.start();
      await nextController.takePhoto();
      nextController.setManualName('書きかけの店');
      await flushed(next);
      expect(draftPhotos().listSync(), hasLength(1));

      await nextController.abandonDraft();
      nextController.setMemo('閉じる間際の入力');
      expect(await flushed(next), isNull);
      expect(draftFile().existsSync(), isFalse);
      expect(draftPhotos().listSync(), isEmpty);
      expect(File(p.join(documents.path, saved)).readAsBytesSync(), [1, 2, 3]);
    });
  });

  group('店の覚え書き', () {
    Future<String> knownShop(String name, String memo) async {
      final repository = container.read(recordRepositoryProvider);
      final visit = await repository.saveEatenVisit(
        shop: ShopInput(name: name),
        eatenAt: DateTime(2026, 9, 1),
        now: DateTime(2026, 9, 1),
      );
      await repository.setShopMemo(visit.shopId, memo);
      return visit.shopId;
    }

    Future<Shop> savedShop(String name) async => (await visits())
        .firstWhere((e) => e.shop.name == name && e.visit.memo == 'かため')
        .shop;

    test('初めての店を選んで書くと、新しい店と一緒に保存する', () async {
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller()
        ..selectShop(state().candidates.single)
        ..setMemo('かため');
      expect(state().shopMemo, '');

      controller().setShopMemo(' 券売機は現金のみ ');
      expect(await controller().save(), isNotNull);

      final shop = await savedShop('麺屋テスト');
      expect(shop.strategyMemo, '券売機は現金のみ');
    });

    test('記録済みの店を選ぶと、その店の覚え書きが入り、書き換えると店に保存する', () async {
      await knownShop('行きつけの店', '11時前に着けば一巡目');
      await controller().start();
      await pumpEventQueue();

      controller().setManualName('行きつけ');
      controller().selectShop(state().nameMatches.single);
      expect(state().shopMemo, '11時前に着けば一巡目');

      controller()
        ..setMemo('かため')
        ..setShopMemo('11時前に着けば一巡目。券売機は現金のみ');
      expect(await controller().save(), isNotNull);

      final shop = await savedShop('行きつけの店');
      expect(shop.strategyMemo, '11時前に着けば一巡目。券売機は現金のみ');
    });

    test('記録済みの店の名前を打つと、その店の覚え書きが入り、触らなければそのまま', () async {
      await knownShop('行きつけの店', '11時前に着けば一巡目');
      await controller().start();
      await pumpEventQueue();

      controller().setManualName('行きつけ');
      expect(state().shopMemo, '');
      controller()
        ..setManualName('行きつけの店')
        ..setMemo('かため');
      expect(state().shopMemo, '11時前に着けば一巡目');
      expect(state().shopMemoEdited, isFalse);
      expect(await controller().save(), isNotNull);

      final shop = await savedShop('行きつけの店');
      expect(shop.strategyMemo, '11時前に着けば一巡目');
    });

    test('店を選び替えると、書きかけを捨ててその店の覚え書きに入れ替える', () async {
      await knownShop('行きつけの店', '11時前に着けば一巡目');
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();

      controller().setManualName('行きつけ');
      final known = state().nameMatches.single;
      controller()
        ..selectShop(known)
        ..setShopMemo('書きかけ');
      expect(state().shopMemoEdited, isTrue);

      controller().selectShop(state().candidates.single);
      expect(state().shopMemo, '');
      expect(state().shopMemoEdited, isFalse);

      controller().selectShop(known);
      expect(state().shopMemo, '11時前に着けば一巡目');

      // 店名を打ち始めて選んだ店が外れたら、空から書く。
      controller().setManualName('別の店');
      expect(state().selectedShop, isNull);
      expect(state().shopMemo, '');
    });
  });

  group('名店の印', () {
    Future<String> knownShop(String name, {bool famous = false}) async {
      final repository = container.read(recordRepositoryProvider);
      final visit = await repository.saveEatenVisit(
        shop: ShopInput(name: name),
        eatenAt: DateTime(2026, 9, 1),
        now: DateTime(2026, 9, 1),
      );
      await repository.setShopFamous(visit.shopId, famous);
      return visit.shopId;
    }

    Future<VisitWithShop> saved(String name) async => (await visits())
        .firstWhere((e) => e.shop.name == name && e.visit.memo == 'かため');

    test('初めての店で付けると、新しい店と一緒に保存し、名店の点がつく', () async {
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller()
        ..selectShop(state().candidates.single)
        ..setMemo('かため');
      expect(state().shopFamous, isFalse);

      controller().setShopFamous(true);
      expect(await controller().save(), isNotNull);

      final entry = await saved('麺屋テスト');
      expect(entry.shop.isFamous, isTrue);
      final scored = scoreVisits([entry]).single;
      expect(scored.points.famousBonus, famousBonus);
    });

    test('手入力の新しい店でも付けられる', () async {
      await controller().start();
      await pumpEventQueue();
      controller()
        ..setManualName('はじめての店')
        ..setShopFamous(true)
        ..setMemo('かため');
      expect(await controller().save(), isNotNull);

      expect((await saved('はじめての店')).shop.isFamous, isTrue);
    });

    test('記録済みの店を選ぶとその店の印が入り、外すと店に保存する', () async {
      await knownShop('行きつけの店', famous: true);
      await controller().start();
      await pumpEventQueue();

      controller().setManualName('行きつけ');
      controller().selectShop(state().nameMatches.single);
      expect(state().shopFamous, isTrue);
      expect(state().shopFamousEdited, isFalse);

      controller()
        ..setMemo('かため')
        ..setShopFamous(false);
      expect(await controller().save(), isNotNull);

      expect((await saved('行きつけの店')).shop.isFamous, isFalse);
    });

    test('触らなければ店の印を書き換えない', () async {
      final shopId = await knownShop('行きつけの店', famous: true);
      await controller().start();
      await pumpEventQueue();
      controller()
        ..setManualName('行きつけの店')
        ..setMemo('かため');
      expect(state().shopFamous, isTrue);
      expect(state().shopFamousEdited, isFalse);
      // 記録画面を開いたあとに店のページで外していても、上書きしない。
      await container
          .read(recordRepositoryProvider)
          .setShopFamous(shopId, false);
      expect(await controller().save(), isNotNull);

      expect((await saved('行きつけの店')).shop.isFamous, isFalse);
    });

    test('同じ名前の名店でも、離れた場所で新しい店になれば、見えていた印を付ける', () async {
      final repository = container.read(recordRepositoryProvider);
      final far = await repository.saveEatenVisit(
        shop: const ShopInput(name: '行きつけの店', latitude: 35.1, longitude: 139.0),
        eatenAt: DateTime(2026, 9, 1),
        now: DateTime(2026, 9, 1),
      );
      await repository.setShopFamous(far.shopId, true);
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();
      controller()
        ..setManualName('行きつけの店')
        ..setMemo('かため');
      expect(state().shopFamous, isTrue);
      expect(await controller().save(), isNotNull);

      final entry = await saved('行きつけの店');
      expect(entry.shop.id, isNot(far.shopId));
      expect(entry.shop.isFamous, isTrue);
    });

    test('店を選び替えると、その店の印に入れ替わる', () async {
      await knownShop('行きつけの店', famous: true);
      await controller().start();
      await controller().takePhoto();
      await pumpEventQueue();

      controller().setManualName('行きつけ');
      final known = state().nameMatches.single;
      controller().selectShop(state().candidates.single);
      controller().setShopFamous(true);
      expect(state().shopFamousEdited, isTrue);

      controller().selectShop(known);
      expect(state().shopFamous, isTrue);
      expect(state().shopFamousEdited, isFalse);

      controller().selectShop(state().candidates.single);
      expect(state().shopFamous, isFalse);
      expect(state().shopFamousEdited, isFalse);

      controller().setManualName('別の店');
      expect(state().selectedShop, isNull);
      expect(state().shopFamous, isFalse);
    });

    test('下書きに残り、次に開くと付けたまま再開する', () async {
      await controller().start();
      await pumpEventQueue();
      controller()
        ..setManualName('はじめての店')
        ..setShopFamous(true);
      await container.read(recordDraftStoreProvider).load();
      container.dispose();

      final next = newSession();
      await next.read(recordControllerProvider.notifier).start();
      final resumed = next.read(recordControllerProvider);
      expect(resumed.shopFamous, isTrue);
      expect(resumed.shopFamousEdited, isTrue);
    });
  });
}
