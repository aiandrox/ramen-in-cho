import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/quests/quest_seal.dart';
import 'package:ramen_in_cho/features/quests/quests.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';

import '../../support/builders.dart';

DateTime _day(int d) => DateTime(2026, 1, 1, 12).add(Duration(days: d));

QuestProgress _progress(String id, List<VisitWithShop> entries) =>
    evaluateQuests(scoreVisits(entries)).firstWhere((p) => p.quest.id == id);

List<VisitWithShop> _bowls(int count, {Shop? shop}) => [
  for (var i = 0; i < count; i++)
    buildEntry(
      shop: shop ?? buildShop(id: 'shop'),
      eatenAt: _day(i),
    ),
];

void main() {
  test('常設とスポットに分かれ、IDが重複しない。レベルの段階は小さい順', () {
    expect(quests.map((q) => q.id).toSet(), hasLength(quests.length));
    expect(
      quests.where((q) => q.kind == QuestKind.standing).map((q) => q.title),
      ['着丼の道', '開拓者', '行列の覇者', '限定ハンター', '不屈の挑戦者', '大物討伐', '願掛け'],
    );
    expect(quests.where((q) => q.kind == QuestKind.spot).map((q) => q.title), [
      'はじめての着丼',
      '六十分の試練',
      '九十分の死闘',
      '一日二杯',
      '三度目の正直',
      '系統の探究',
      '幻の店',
      '拠点を構える',
      '百日越しの願',
      '朝ラーの心得',
      '丑三つの背徳',
      '疾風の着丼',
      '系統はしご',
      '一途',
      '月の巡礼',
      '限定狩りの月',
      '満点の舌',
      '二郎の洗礼',
      '遥かなる遠征',
      '年越しの一杯',
      '夏の涼麺',
    ]);
    for (final quest in quests) {
      final sorted = [...quest.thresholds]..sort();
      expect(quest.thresholds, sorted, reason: quest.id);
      if (quest.kind == QuestKind.spot) {
        expect(quest.thresholds, hasLength(1), reason: quest.id);
      }
    }
  });

  group('期間限定', () {
    final limited = Quest(
      id: 'limited',
      kind: QuestKind.spot,
      title: '期間限定',
      description: '期間中に2杯食べる',
      unit: '杯',
      thresholds: const [2],
      count: (scored) => scored.length,
      availableFrom: _day(1),
      availableUntil: _day(3),
    );
    QuestProgress evaluate(List<VisitWithShop> entries) =>
        evaluateQuests(scoreVisits(entries), definitions: [limited]).single;

    test('期間のはじめは含み、おわりの日時は含まない', () {
      expect(limited.isAvailableAt(_day(1)), isTrue);
      expect(
        limited.isAvailableAt(_day(1).subtract(const Duration(minutes: 1))),
        isFalse,
      );
      expect(
        limited.isAvailableAt(_day(3).subtract(const Duration(minutes: 1))),
        isTrue,
      );
      expect(limited.isAvailableAt(_day(3)), isFalse);
    });

    test('期間の外で食べた記録は数えない', () {
      // _day(0)〜_day(3) の4杯のうち、期間内は _day(1) と _day(2) の2杯。
      final progress = evaluate(_bowls(4));
      expect(progress.current, 2);
      expect(progress.levelAchievedAt, [_day(2)]);

      expect(evaluate([_bowls(4)[0], _bowls(4)[3]]).isAchieved, isFalse);
    });

    test('期間が過ぎても、期間中に会得した秘伝は残る', () {
      final progress = evaluate(_bowls(30));
      expect(progress.isAchieved, isTrue);
      expect(progress.levelAchievedAt, [_day(2)]);
    });
  });

  test('記録が無ければ、すべてレベル0（未達成）', () {
    final all = evaluateQuests(const []);

    expect(all.map((p) => p.level).toSet(), {0});
    expect(all.map((p) => p.isAchieved).toSet(), {false});
  });

  group('着丼の道（常設）', () {
    test('杯数の段階ごとにレベルが上がり、段階ごとの到達日を持つ', () {
      final four = _progress('bowls', _bowls(4));
      final nine = _progress('bowls', _bowls(9));
      final ten = _progress('bowls', _bowls(10));

      // 1杯目は「はじめての着丼」で祝うので、Lv.1 は5杯から。
      expect(four.level, 0);
      expect(nine.level, 1);
      expect(nine.nextThreshold, 10);
      expect(ten.level, 2);
      expect(ten.levelAchievedAt, [_day(4), _day(9)]);
      expect(ten.nextThreshold, 30);
    });

    test('最高レベル（200杯）に届くと次の段階は無い', () {
      final progress = _progress('bowls', _bowls(200));

      expect(progress.level, 6);
      expect(progress.isMaxLevel, isTrue);
      expect(progress.nextThreshold, isNull);
    });

    test('撤退は数えない', () {
      final progress = _progress('bowls', [
        buildEntry(shop: buildShop(), result: VisitResult.retreated),
      ]);

      expect(progress.level, 0);
    });
  });

  test('開拓者は、食べたことのある店の数で上がる（同じ店は1軒）', () {
    final entries = [
      for (var i = 0; i < 3; i++)
        buildEntry(
          shop: buildShop(id: 'shop$i'),
          eatenAt: _day(i),
        ),
      buildEntry(
        shop: buildShop(id: 'shop0'),
        eatenAt: _day(5),
      ),
    ];

    final progress = _progress('shops', entries);

    expect(progress.current, 3);
    expect(progress.level, 1);
    expect(progress.levelAchievedAt, [_day(2)]);
  });

  test('不屈の挑戦者は、撤退のあとに食べた回数。撤退1回につき1回まで', () {
    final shop = buildShop();
    VisitWithShop retreat(int d) =>
        buildEntry(shop: shop, eatenAt: _day(d), result: VisitResult.retreated);
    VisitWithShop eat(int d) => buildEntry(shop: shop, eatenAt: _day(d));

    expect(_progress('retry', [retreat(1), eat(2), eat(3), eat(4)]).current, 1);
    expect(
      _progress('retry', [retreat(1), eat(2), retreat(3), eat(4)]).current,
      2,
    );
  });

  test('行列の覇者は30分以上並んだ回数。29分は数えない', () {
    final progress = _progress('queue', [
      buildEntry(shop: buildShop(), eatenAt: _day(1), waitMinutes: 29),
      buildEntry(shop: buildShop(), eatenAt: _day(2), waitMinutes: 30),
    ]);

    expect(progress.current, 1);
    expect(progress.level, 1);
  });

  test('限定ハンターは4杯で Lv.1、5杯で Lv.2', () {
    List<VisitWithShop> limited(int count) => [
      for (var i = 0; i < count; i++)
        buildEntry(shop: buildShop(), eatenAt: _day(i), isLimited: true),
    ];

    expect(_progress('limited', limited(4)).level, 1);
    expect(_progress('limited', limited(5)).level, 2);
  });

  test('系統の探究は秘伝。「その他」を除く8系統をすべて食べた記録で会得', () {
    const styles = [
      RamenStyle.shoyu,
      RamenStyle.miso,
      RamenStyle.shio,
      RamenStyle.tonkotsu,
      RamenStyle.iekei,
      RamenStyle.jiro,
      RamenStyle.tsukemen,
      RamenStyle.shirunashi,
    ];
    final progress = _progress('styles', [
      for (var i = 0; i < 8; i++)
        buildEntry(shop: buildShop(), eatenAt: _day(i), style: styles[i]),
      buildEntry(shop: buildShop(), eatenAt: _day(9), style: RamenStyle.other),
    ]);

    expect(progress.quest.kind, QuestKind.spot);
    expect(progress.isAchieved, isTrue);
    expect(progress.levelAchievedAt, [_day(7)]);
  });

  test('大物討伐は、1杯で60点以上のSランクの店の数', () {
    final rare = buildShop(
      id: 'rare',
      hoursConditions: {HoursCondition.weekdaysOnly, HoursCondition.fewDays},
    );
    // (10 + 10 + 20) × 2 = 80
    final progress = _progress('boss', [
      buildEntry(shop: rare, eatenAt: _day(1), isLimited: true),
    ]);

    expect(progress.level, 1);
  });

  group('スポット', () {
    test('はじめての着丼は最初の1杯で達成', () {
      final progress = _progress('first_bowl', _bowls(3));

      expect(progress.isAchieved, isTrue);
      expect(progress.isMaxLevel, isTrue);
      expect(progress.levelAchievedAt, [_day(0)]);
    });

    test('60分の試練と90分の死闘は、待ち時間の境界で分かれる', () {
      final entries = [buildEntry(shop: buildShop(), waitMinutes: 89)];

      expect(_progress('queue_60', entries).isAchieved, isTrue);
      expect(_progress('queue_90', entries).isAchieved, isFalse);
      expect(
        _progress('queue_90', [
          buildEntry(shop: buildShop(), waitMinutes: 90),
        ]).isAchieved,
        isTrue,
      );
    });

    test('一日二杯は、同じ日に2杯食べると達成（撤退は数えない）', () {
      final shop = buildShop();
      final sameDay = [
        buildEntry(shop: shop, eatenAt: DateTime(2026, 9, 1, 11)),
        buildEntry(shop: shop, eatenAt: DateTime(2026, 9, 1, 20)),
      ];
      final withRetreat = [
        buildEntry(shop: shop, eatenAt: DateTime(2026, 9, 1, 11)),
        buildEntry(
          shop: shop,
          eatenAt: DateTime(2026, 9, 1, 20),
          result: VisitResult.retreated,
        ),
        buildEntry(shop: shop, eatenAt: DateTime(2026, 9, 2, 11)),
      ];

      expect(_progress('double_bowl', sameDay).isAchieved, isTrue);
      expect(_progress('double_bowl', withRetreat).isAchieved, isFalse);
    });

    test('三度目の正直は、同じ店で2回撤退したあとに食べると達成', () {
      final shop = buildShop();
      VisitWithShop retreat(int d) => buildEntry(
        shop: shop,
        eatenAt: _day(d),
        result: VisitResult.retreated,
      );

      expect(
        _progress('third_time', [
          retreat(1),
          buildEntry(shop: shop, eatenAt: _day(2)),
        ]).isAchieved,
        isFalse,
      );
      expect(
        _progress('third_time', [
          retreat(1),
          retreat(2),
          buildEntry(shop: shop, eatenAt: _day(3)),
        ]).levelAchievedAt,
        [_day(3)],
      );
    });

    test('幻の店は、営業の条件が2つ以上ある店で食べると達成', () {
      final one = buildShop(
        id: 'one',
        hoursConditions: {HoursCondition.lunchOnly},
      );
      final two = buildShop(
        id: 'two',
        hoursConditions: {
          HoursCondition.lunchOnly,
          HoursCondition.weekdaysOnly,
        },
      );

      expect(
        _progress('rare_shop', [buildEntry(shop: one)]).isAchieved,
        isFalse,
      );
      expect(
        _progress('rare_shop', [buildEntry(shop: two)]).isAchieved,
        isTrue,
      );
    });

    test('幻の店は、アクセスの悪さを営業の条件として数えない', () {
      final access = buildShop(
        hoursConditions: {HoursCondition.nightOnly, HoursCondition.badAccess},
      );

      expect(
        _progress('rare_shop', [buildEntry(shop: access)]).isAchieved,
        isFalse,
      );
    });
  });

  group('newlyAchievedLevels', () {
    test('新しく届いたレベルだけを返す', () {
      final before = _bowls(9);
      final after = _bowls(10);

      final levelUps = newlyAchievedLevels(
        before: evaluateQuests(scoreVisits(before)),
        after: evaluateQuests(scoreVisits(after)),
      );

      // 同じ店の10杯目なので、秘伝「一途」も同時に会得する。
      expect(levelUps.map((l) => (l.quest.id, l.level)), [
        ('bowls', 2),
        ('devoted', 1),
      ]);
    });

    test('最初の1杯では「はじめての着丼」だけを知らせる（同じことを二重に知らせない）', () {
      final levelUps = newlyAchievedLevels(
        before: evaluateQuests(const []),
        after: evaluateQuests(scoreVisits(_bowls(1))),
      );

      expect(levelUps.map((l) => (l.quest.id, l.level)), [('first_bowl', 1)]);
    });

    test('レベルが変わらなければ知らせない', () {
      final levelUps = newlyAchievedLevels(
        before: evaluateQuests(scoreVisits(_bowls(2))),
        after: evaluateQuests(scoreVisits(_bowls(3))),
      );

      expect(levelUps, isEmpty);
    });
  });

  test('段は大字で書く', () {
    expect(daijiNumber(1), '壱');
    expect(daijiNumber(4), '肆');
    expect(daijiNumber(6), '陸');
    expect(daijiNumber(10), '拾');
    expect(daijiNumber(11), '11');
  });

  test('拠点を構えるは、同じ地域で5杯食べた記録で達成', () {
    final shop = buildShop(id: 'home', latitude: 35.0, longitude: 139.0);
    final entries = [
      for (var d = 1; d <= 5; d++)
        buildEntry(shop: shop, eatenAt: DateTime(2026, 9, d, 12)),
    ];

    expect(
      _progress('home_base', entries.take(4).toList()).isAchieved,
      isFalse,
    );
    final progress = _progress('home_base', entries);
    expect(progress.isAchieved, isTrue);
    expect(progress.levelAchievedAt.single, DateTime(2026, 9, 5, 12));
  });
}
