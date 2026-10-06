import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/record/record_draft.dart';
import 'package:ramen_in_cho/features/record/record_state.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/shop_search/found_shop.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/shop_candidate.dart';

import '../../support/fakes.dart';

void main() {
  final draft = RecordDraft(
    photoPath: 'record_draft/a.jpg',
    photoTakenAt: DateTime(2026, 10, 5, 12, 30),
    photoFromCamera: true,
    photoLocation: const GeoPoint(35.1, 139.2),
    pinnedLocation: const GeoPoint(43.0687, 141.3508),
    selectedShop: const ShopCandidate(
      osmId: 'node/1',
      name: '麺屋テスト',
      location: GeoPoint(35.001, 139.0),
      hoursConditions: {HoursCondition.nightOnly},
      dataSource: ShopSource(licenses: ['CC-BY'], attributions: ['Overture']),
      wishId: 'wish-1',
      conditionsDraftSource: ConditionsDraftSource.openingHours,
    ),
    rating: 5,
    style: RamenStyle.jiro,
    isLimited: true,
    chosenHoursConditions: const {HoursCondition.badAccess},
    memo: 'ニンニク',
    manualWaitMinutes: 40,
  );

  test('書き出して読み戻すと同じ入力になる', () {
    final decoded = RecordDraft.fromJson(
      jsonDecode(jsonEncode(draft.toJson())),
    )!;

    expect(decoded.photoPath, 'record_draft/a.jpg');
    expect(decoded.photoTakenAt, DateTime(2026, 10, 5, 12, 30));
    expect(decoded.photoFromCamera, isTrue);
    expect(decoded.photoDateFromPhoto, isFalse);
    expect(decoded.photoLocation?.latitude, 35.1);
    expect(decoded.pinnedLocation?.longitude, 141.3508);
    final shop = decoded.selectedShop!;
    expect(shop.osmId, 'node/1');
    expect(shop.name, '麺屋テスト');
    expect(shop.location?.longitude, 139.0);
    expect(shop.hoursConditions, {HoursCondition.nightOnly});
    expect(shop.dataSource?.licenses, ['CC-BY']);
    expect(shop.dataSource?.attributions, ['Overture']);
    expect(shop.wishId, 'wish-1');
    expect(shop.conditionsDraftSource, ConditionsDraftSource.openingHours);
    expect(decoded.rating, 5);
    expect(decoded.style, RamenStyle.jiro);
    expect(decoded.isLimited, isTrue);
    expect(decoded.chosenHoursConditions, {HoursCondition.badAccess});
    expect(decoded.memo, 'ニンニク');
    expect(decoded.manualWaitMinutes, 40);
    expect(jsonEncode(decoded.toJson()), jsonEncode(draft.toJson()));
  });

  test('条件の下書きの出どころを読み戻す。前の版の「地図から」の印も読める', () {
    ShopCandidate shopOf(Map<String, Object?> shop) => RecordDraft.fromJson({
      'selectedShop': {'name': '麺屋テスト', ...shop},
    })!.selectedShop!;

    expect(
      shopOf({'conditionsDraftSource': 'curatedShops'}).conditionsDraftSource,
      ConditionsDraftSource.curatedShops,
    );
    expect(
      shopOf({'conditionsFromMap': true}).conditionsDraftSource,
      ConditionsDraftSource.openingHours,
    );
    expect(shopOf({}).conditionsDraftSource, isNull);
  });

  test('読めない項目は空にし、形が違えばnull', () {
    final decoded = RecordDraft.fromJson({
      'style': 'unknown',
      'rating': 9,
      'manualWaitMinutes': -1,
      'chosenHoursConditions': ['lunchOnly', 'unknown'],
      'selectedShop': {'name': ''},
      'memo': 3,
    })!;
    expect(decoded.style, isNull);
    expect(decoded.rating, isNull);
    expect(decoded.manualWaitMinutes, isNull);
    expect(decoded.chosenHoursConditions, {HoursCondition.lunchOnly});
    expect(decoded.selectedShop, isNull);
    expect(decoded.memo, isEmpty);

    expect(RecordDraft.fromJson('broken'), isNull);
    expect(RecordDraft.fromJson(null), isNull);
  });

  test('何も入れていなければ空の下書き。並んでいる店は下書きの店に入れない', () {
    expect(const RecordDraft().isEmpty, isTrue);
    expect(const RecordDraft(memo: '  ').isEmpty, isTrue);
    expect(const RecordDraft(isLimited: true).isEmpty, isFalse);

    const queued = ShopCandidate(name: '並んだ店');
    final fromCheckin = RecordDraft.fromState(
      const RecordState(checkinShop: queued, selectedShop: queued),
    );
    expect(fromCheckin.selectedShop, isNull);
    expect(fromCheckin.isEmpty, isTrue);
  });

  test('「着」を押した時刻と並びは、書き出して読み戻しても残る', () {
    final checkin = Checkin(
      shopId: 'shop-1',
      osmId: 'node/9',
      name: '並んだ店',
      latitude: 35.0,
      longitude: 139.0,
      dataSource: const ShopSource(licenses: ['ODbL'], attributions: ['OSM']),
      checkedInAt: DateTime(2026, 10, 5, 11),
    );
    const queued = ShopCandidate(name: '並んだ店');
    final arrived = RecordDraft.fromState(
      RecordState(
        checkin: checkin,
        checkinShop: queued,
        selectedShop: queued,
        arrivedAt: DateTime(2026, 10, 5, 11, 50),
      ),
    );
    // 写真がまだでも、「着」を押していれば下書きに残す。
    expect(arrived.isEmpty, isFalse);
    expect(arrived.selectedShop, isNull);

    final decoded = RecordDraft.fromJson(
      jsonDecode(jsonEncode(arrived.toJson())),
    )!;
    expect(decoded.arrivedAt, DateTime(2026, 10, 5, 11, 50));
    final restored = decoded.arrivedCheckin!;
    expect(restored.shopId, 'shop-1');
    expect(restored.osmId, 'node/9');
    expect(restored.name, '並んだ店');
    expect(restored.latitude, 35.0);
    expect(restored.dataSource?.attributions, ['OSM']);
    expect(restored.checkedInAt, DateTime(2026, 10, 5, 11));
    expect(decoded.withPhotoPath('record_draft/b.jpg').arrivedAt, isNotNull);
    expect(decoded.withoutArrival().isEmpty, isTrue);

    // 並びの無い「着」の時刻だけは読まない。
    final broken = RecordDraft.fromJson({
      'arrivedAt': '2026-10-05T02:50:00.000Z',
    })!;
    expect(broken.arrivedAt, isNull);
    expect(broken.isEmpty, isTrue);
  });

  group('FileRecordDraftStore', () {
    late Directory documents;
    late FileRecordDraftStore store;

    setUp(() {
      documents = createTempDirectory();
      store = FileRecordDraftStore(documents);
    });

    File source() =>
        File(p.join(createTempDirectory().path, 'tmp.jpg'))
          ..writeAsBytesSync([7, 8]);

    test('写真は documents に写し、相対パスで残して読み戻す', () async {
      final kept = await store.keepPhoto(source().path);
      expect(
        p.isWithin(
          p.join(documents.path, FileRecordDraftStore.photoDirectoryName),
          kept,
        ),
        isTrue,
      );
      await store.save(RecordDraft(photoPath: kept, memo: 'メモ'));

      final raw = jsonDecode(
        File(p.join(documents.path, FileRecordDraftStore.fileName))
            .readAsStringSync(),
      );
      expect(p.isRelative(raw['photoPath'] as String), isTrue);
      final loaded = await FileRecordDraftStore(documents).load();
      expect(loaded?.photoPath, kept);
      expect(File(loaded!.photoPath!).readAsBytesSync(), [7, 8]);
    });

    test('写真が消えていれば写真なしで読み戻す', () async {
      final kept = await store.keepPhoto(source().path);
      await store.save(RecordDraft(photoPath: kept, memo: 'メモ'));
      File(kept).deleteSync();

      final loaded = await store.load();
      expect(loaded?.photoPath, isNull);
      expect(loaded?.memo, 'メモ');
    });

    test('下書き用のフォルダの外のファイルは下書きの写真にせず、消しもしない', () async {
      final outside = File(p.join(documents.path, 'photos', 'visit.jpg'))
        ..createSync(recursive: true);
      await store.save(RecordDraft(photoPath: outside.path, memo: 'メモ'));
      expect((await store.load())?.photoPath, isNull);

      await store.clear();
      expect(outside.existsSync(), isTrue);
    });

    test('消すのは下書きと下書き用のフォルダの写真だけ。記録の写真やほかのファイルは残す', () async {
      final saved = File(p.join(documents.path, 'photos', 'visit.jpg'))
        ..createSync(recursive: true);
      final other = File(p.join(documents.path, 'curated_shops.json'))
        ..writeAsStringSync('[]');
      final kept = await store.keepPhoto(source().path);
      await store.save(RecordDraft(photoPath: kept, memo: 'メモ'));

      await store.clear();
      expect(await store.load(), isNull);
      expect(File(kept).existsSync(), isFalse);
      expect(saved.existsSync(), isTrue);
      expect(other.existsSync(), isTrue);
    });

    test('消すと下書きと写真がなくなる。残す写真は指定できる', () async {
      final first = await store.keepPhoto(source().path);
      final second = await store.keepPhoto(source().path);
      await store.save(RecordDraft(photoPath: second));

      await store.clear(keepPhoto: second);
      expect(await store.load(), isNull);
      expect(File(first).existsSync(), isFalse);
      expect(File(second).existsSync(), isTrue);

      await store.clear();
      expect(File(second).existsSync(), isFalse);
    });
  });
}
