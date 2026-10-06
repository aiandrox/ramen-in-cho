import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/prefecture/prefectures.dart';

import '../../support/builders.dart';

void main() {
  final index = PrefectureIndex.fromJson(
    File(prefecturesAsset).readAsStringSync(),
  );

  test('同梱した境界には47都道府県が北から順に入っている', () {
    expect(index.names, hasLength(47));
    expect(index.names.first, '北海道');
    expect(index.names[12], '東京都');
    expect(index.names.last, '沖縄県');
  });

  test('主な街の位置から都道府県を引く', () {
    expect(index.prefectureAt(35.6896, 139.7006), '東京都'); // 新宿
    expect(index.prefectureAt(43.0621, 141.3544), '北海道'); // 札幌
    expect(index.prefectureAt(34.7025, 135.4959), '大阪府'); // 梅田
    expect(index.prefectureAt(26.2124, 127.6809), '沖縄県'); // 那覇
    expect(index.prefectureAt(34.9858, 135.7588), '京都府'); // 京都駅
    expect(index.prefectureAt(35.1709, 136.8815), '愛知県'); // 名古屋駅
    expect(index.prefectureAt(33.5904, 130.4017), '福岡県'); // 天神
    expect(index.prefectureAt(38.2601, 140.8822), '宮城県'); // 仙台駅
    expect(index.prefectureAt(34.3401, 134.0434), '香川県'); // 高松
    expect(index.prefectureAt(34.3853, 132.4553), '広島県'); // 広島駅
  });

  test('境の近くでも、川を挟んだ隣の都府県と取り違えない', () {
    expect(index.prefectureAt(35.5313, 139.6968), '神奈川県'); // 川崎駅
    expect(index.prefectureAt(35.5625, 139.7160), '東京都'); // 蒲田駅
    expect(index.prefectureAt(34.7186, 135.4170), '兵庫県'); // 尼崎駅
    expect(index.prefectureAt(34.7330, 135.5000), '大阪府'); // 新大阪駅
    expect(index.prefectureAt(35.9064, 139.6237), '埼玉県'); // 大宮駅
    expect(index.prefectureAt(35.7770, 139.7210), '東京都'); // 赤羽駅
  });

  test('海岸の埋立地は、境界から少し外れても最寄りの都道府県にする', () {
    expect(index.prefectureAt(35.6270, 139.7759), '東京都'); // お台場
  });

  test('沖の海や日本の外はnull', () {
    expect(index.prefectureAt(34.0, 141.5), isNull); // 房総の沖
    expect(index.prefectureAt(37.5665, 126.9780), isNull); // ソウル
  });

  test('位置のわからない店には都道府県が無い', () {
    expect(index.prefectureOf(buildShop()), isNull);
    expect(
      index.prefectureOf(buildShop(latitude: 35.6896, longitude: 139.7006)),
      '東京都',
    );
  });

  test('読み込んでいなければ、どこも都道府県なし', () {
    expect(PrefectureIndex.empty.prefectureAt(35.6896, 139.7006), isNull);
  });
}
