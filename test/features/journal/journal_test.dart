import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/inkan/inkan.dart';
import 'package:ramen_in_cho/features/journal/journal.dart';
import 'package:ramen_in_cho/features/journal/journal_phrases.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';

import '../../support/builders.dart';

void main() {
  final shop = buildShop(id: 'shop', name: 'はやし田');
  DateTime day(int month, int d) => DateTime(2026, month, d, 12);

  List<String> journalOf(
    List<VisitWithShop> entries, {
    List<Wish> wishes = const [],
  }) {
    final scored = scoreVisits(entries, wishes: wishes);
    return buildJournal(scored.last, scored);
  }

  test('願を掛けた店で、撤退のあと並んで食べた1杯を物語にする', () {
    final retreat = buildEntry(
      shop: shop,
      result: VisitResult.retreated,
      eatenAt: day(9, 10),
      memo: '売り切れ',
    );
    final eaten = buildEntry(
      shop: shop,
      eatenAt: day(10, 3),
      waitMinutes: 45,
      style: RamenStyle.shoyu,
    );
    final lines = journalOf(
      [retreat, eaten],
      wishes: [
        Wish(
          id: 'wish',
          name: 'はやし田',
          trigger: '同僚に聞いた',
          createdAt: day(9, 1),
          fulfilledVisitId: eaten.visit.id,
        ),
      ],
    );

    expect(lines.first, '九月一日、願を掛けた店。きっかけは「同僚に聞いた」。');
    expect(lines, contains('前回は「売り切れ」に阻まれ、撤退した。'));
    expect(lines.any((l) => l.contains('45分')), isTrue);
    final bowlLine = lines.firstWhere((l) => l.contains('修行点'));
    final points = RegExp(r'修行点 (\d+)').firstMatch(bowlLine)![1]!;
    expect(dramaticBowl.fill({'一杯': '醤油の一杯', '点': points}), contains(bowlLine));
    expect(lines.last, '三十二日越しの願成就。');
  });

  test('初めての店は何軒目の道場かを添える', () {
    final other = buildEntry(
      shop: buildShop(id: 'other'),
      eatenAt: day(1, 5),
    );
    final first = buildEntry(shop: shop, eatenAt: day(2, 1));
    final lines = journalOf([other, first]);

    expect(lines.first, contains('二軒目'));
    expect(lines.first, isNot(contains('願')));
  });

  test('今年何杯目かは、10杯ごとの節目には必ず、ほかはときどきだけ添える', () {
    final entries = [
      for (var i = 0; i < 30; i++)
        buildEntry(
          shop: shop,
          eatenAt: DateTime(2026, 1, 1, 12).add(Duration(days: i)),
        ),
    ];
    final scored = scoreVisits(entries);
    bool hasYearLine(int n) => buildJournal(
      scored[n - 1],
      scored,
    ).any(yearClosing.fill({'杯': proseNumber(n)}).contains);

    expect(hasYearLine(1), isFalse);
    expect(hasYearLine(10), isTrue);
    expect(hasYearLine(20), isTrue);
    expect(hasYearLine(30), isTrue);
    final others = [
      for (var n = 2; n <= 30; n++)
        if (n % 10 != 0) hasYearLine(n),
    ];
    expect(others, contains(true));
    expect(others, contains(false));
  });

  test('2回目は来訪の回数を、撤退が続いたあとの1杯は再挑戦成功を添える', () {
    final lines = journalOf([
      buildEntry(shop: shop, eatenAt: day(1, 1)),
      buildEntry(shop: shop, result: VisitResult.retreated, eatenAt: day(1, 2)),
      buildEntry(shop: shop, result: VisitResult.retreated, eatenAt: day(1, 3)),
      buildEntry(shop: shop, eatenAt: day(1, 4)),
    ]);

    expect(lines.first, contains('二度目'));
    expect(lines, contains('二度の撤退を越えて、ここまで来た。'));
    expect(retryClosing.fill(), contains(lines.last));
  });

  test('撤退の記録は、阻まれた理由と次への一言で終える', () {
    final lines = journalOf([
      buildEntry(
        shop: shop,
        result: VisitResult.retreated,
        eatenAt: day(3, 1),
        waitMinutes: 20,
        memo: '臨時休業',
      ),
    ]);

    expect(lines, contains('20分並んだが、'));
    expect(lines, contains('「臨時休業」に阻まれ、撤退。'));
    expect(retreatClosing.fill(), contains(lines.last));
  });

  test('同じ記録なら、何度組み立てても同じ文になる', () {
    final entry = buildEntry(shop: shop, eatenAt: day(4, 1));
    expect(journalOf([entry]), journalOf([entry]));
  });

  test('願を掛ける前の1杯を叶えたことにしても、願の話は入れない', () {
    final eaten = buildEntry(shop: shop, eatenAt: day(5, 10));
    final lines = journalOf(
      [eaten],
      wishes: [
        Wish(
          id: 'wish',
          name: 'はやし田',
          createdAt: day(10, 3),
          fulfilledVisitId: eaten.visit.id,
        ),
      ],
    );

    expect(lines.any((l) => l.contains('願')), isFalse);
  });

  test('★の数に合ったひとことで締める。★が無ければ言わない', () {
    VisitWithShop rated(int? rating) => VisitWithShop(
      shop: shop,
      visit: Visit(
        id: 'v$rating',
        shopId: 'shop',
        result: VisitResult.eaten,
        eatenAt: day(6, 1),
        rating: rating,
        isLimited: false,
        hasTicket: false,
        memo: '',
        createdAt: day(6, 1),
      ),
    );
    final five = verdicts[5]!.lines;

    expect(journalOf([rated(5)]).any(five.contains), isTrue);
    expect(journalOf([rated(null)]).any(five.contains), isFalse);
  });

  test('何も起きなかった1杯でも、記録ごとに言い回しが変わる', () {
    final journals = {
      for (var i = 0; i < 20; i++)
        journalOf([
          VisitWithShop(
            shop: shop,
            visit: Visit(
              id: 'visit-$i',
              shopId: 'shop',
              result: VisitResult.eaten,
              eatenAt: day(7, 1 + i),
              isLimited: false,
              hasTicket: false,
              memo: '',
              createdAt: day(7, 1 + i),
            ),
          ),
        ]).join(),
    };

    expect(journals.length, greaterThan(10));
  });

  Shop placed(String id, String area, double latitude) => Shop(
    id: id,
    name: id,
    area: area,
    latitude: latitude,
    longitude: 139.0,
    createdAt: DateTime(2026),
  );

  group('地名の一文は、いつもの店からの距離で変わる', () {
    String areaLine(double latitude) {
      final home = placed('home', '新宿区', 35.69);
      final here = placed('here', '某市', latitude);
      return journalOf([
        buildEntry(shop: home, eatenAt: day(8, 1)),
        buildEntry(shop: home, eatenAt: day(8, 2)),
        buildEntry(shop: here, eatenAt: day(8, 3)),
      ]).firstWhere((l) => l.contains('某市'), orElse: () => '');
    }

    // 緯度0.01度は約1.1km。
    test('20km未満は街の一文（添えないこともある）', () {
      expect(nearArea.fill({'地名': '某市'}), contains(areaLine(35.69 - 0.17)));
    });

    test('20km以上80km未満は遠出の一文', () {
      expect(farArea.fill({'地名': '某市'}), contains(areaLine(35.69 - 0.19)));
      expect(farArea.fill({'地名': '某市'}), contains(areaLine(35.69 - 0.71)));
    });

    test('80km以上は遠征の一文', () {
      expect(
        expeditionArea.fill({'地名': '某市'}),
        contains(areaLine(35.69 - 0.73)),
      );
    });

    test('距離ごとの一文は重ならない', () {
      final near = nearArea.fill({'地名': '某市'}).toSet();
      final far = farArea.fill({'地名': '某市'}).toSet();
      final expedition = expeditionArea.fill({'地名': '某市'}).toSet();
      expect(near.intersection(far), isEmpty);
      expect(far.intersection(expedition), isEmpty);
      expect(near.intersection(expedition), isEmpty);
    });
  });

  test('地名がわかっても、ほかの言い回しは変わらない', () {
    final entry = buildEntry(
      shop: placed('home', '', 35.69),
      eatenAt: day(8, 1),
    );
    final withArea = VisitWithShop(
      shop: placed('home', '新宿区', 35.69),
      visit: entry.visit,
    );
    final without = journalOf([entry]);
    final with_ = journalOf([withArea]);

    // 初めての市区町村の点が足されるので、修行点の行は比べない。
    bool same(String line) => !line.contains('新宿区') && !line.contains('修行点');
    expect(with_.where(same), without.where(same));
  });

  group('節目・間隔・特別な日', () {
    test('通算10杯目と、3日連続を書く', () {
      final lines = journalOf([
        for (var d = 1; d <= 10; d++)
          buildEntry(
            shop: buildShop(id: 'shop$d'),
            eatenAt: day(3, d),
          ),
      ]);

      expect(lines, contains('通算十杯目の節目。'));
      expect(lines, contains('十日連続の麺修行。'));
    });

    test('同じ日の2杯目と、年明け最初の一杯を書く', () {
      final lines = journalOf([
        buildEntry(
          shop: buildShop(id: 'a'),
          eatenAt: DateTime(2027, 1, 1, 11),
        ),
        buildEntry(
          shop: buildShop(id: 'b'),
          eatenAt: DateTime(2027, 1, 1, 19),
        ),
      ]);

      // 2杯目なので「年明け最初」とは言わない。
      expect(lines, isNot(contains('年明け最初の一杯。')));
      expect(lines, contains('本日二杯目。'));
    });

    test('その店に1年以上あいたら「〇年ぶりの再会」、5度目は「常連の域」', () {
      final again = journalOf([
        buildEntry(shop: shop, eatenAt: DateTime(2024, 5, 1, 12)),
        buildEntry(shop: shop, eatenAt: DateTime(2026, 5, 2, 12)),
      ]);
      expect(again, contains('二年ぶりの再会。'));

      final regular = journalOf([
        for (var w = 0; w < 5; w++)
          buildEntry(shop: shop, eatenAt: DateTime(2026, 4, 1 + w * 7, 12)),
      ]);
      expect(regular, contains('常連の域に入った。'));
    });
  });

  group('記録の更新', () {
    test('自己最高の修行点と、この店で着丼までの最長記録を書く（1つまで）', () {
      final lines = journalOf([
        buildEntry(shop: shop, eatenAt: day(9, 1), waitMinutes: 10),
        buildEntry(
          shop: shop,
          eatenAt: day(9, 2),
          waitMinutes: 40,
          isLimited: true,
        ),
      ]);

      expect(lines, contains('自己最高の修行点を更新。'));
      expect(lines, isNot(contains('この店で着丼までの最長記録。')));
    });

    test('この店で初めて55点以上なら、印が「極」になったと書く', () {
      final rare = buildShop(id: 'rare', isFamous: true);
      final lines = journalOf([
        buildEntry(
          shop: buildShop(id: 'big'),
          eatenAt: day(9, 1),
          isLimited: true,
          waitMinutes: 120,
        ),
        buildEntry(shop: rare, eatenAt: day(9, 2)),
        // 10 + 限定 20 + 待ち 15 + 名店 15 = 60
        buildEntry(
          shop: rare,
          eatenAt: day(9, 3),
          isLimited: true,
          waitMinutes: 30,
        ),
      ]);

      expect(lines, contains('この道場の印は「極」に。'));
    });
  });

  test('短いメモは引用して書き残す。共有カード用には入れない', () {
    final entry = buildEntry(shop: shop, eatenAt: day(9, 5), memo: '海苔多めが正解');
    expect(journalOf([entry]), contains('――「海苔多めが正解」と書き残す。'));

    final scored = scoreVisits([entry]);
    expect(
      buildJournal(scored.single, scored, includeMemo: false),
      isNot(contains('――「海苔多めが正解」と書き残す。')),
    );
  });

  test('撤退した日も、その店に行った日として数える（久しぶりとは言わない）', () {
    final lines = journalOf([
      buildEntry(shop: shop, eatenAt: day(1, 10)),
      buildEntry(shop: shop, eatenAt: day(5, 1), result: VisitResult.retreated),
      buildEntry(shop: shop, eatenAt: day(5, 8)),
    ]);

    expect(lines, isNot(contains('久しぶりの暖簾。')));
  });

  test('系統ごとの一文は、添える1杯と添えない1杯がある', () {
    final lines = {
      for (var i = 0; i < 20; i++)
        ...journalOf([
          buildEntry(
            shop: buildShop(id: 'iekei$i'),
            eatenAt: day(10, 1 + i),
            style: RamenStyle.iekei,
          ),
        ]),
    };

    expect(
      lines.contains('海苔をスープに浸して。') || lines.contains('「お好みは？」に「硬め濃いめ多め」。'),
      isTrue,
    );
  });
}
