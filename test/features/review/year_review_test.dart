import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/quests/quests.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/review/year_review.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/scoring/ranks.dart';

import '../../support/builders.dart';

void main() {
  final shopA = buildShop(id: 'a', name: 'A店');
  final shopB = buildShop(id: 'b', name: 'B店');
  final scored = scoreVisits([
    // 25点（初訪問・深夜）
    buildEntry(shop: shopA, eatenAt: DateTime(2025, 12, 31, 4, 30)),
    // 10点
    buildEntry(shop: shopA, eatenAt: DateTime(2026, 1, 1, 12)),
    // 30点（45分待ち）。累計65点で四級
    buildEntry(shop: shopA, eatenAt: DateTime(2026, 3, 5, 12), waitMinutes: 45),
    buildEntry(
      shop: shopB,
      eatenAt: DateTime(2026, 3, 10, 12),
      result: VisitResult.retreated,
    ),
    // 35点（初訪問・再挑戦成功・10分待ち）
    buildEntry(
      shop: shopB,
      eatenAt: DateTime(2026, 7, 1, 12),
      style: RamenStyle.shoyu,
      waitMinutes: 10,
    ),
    buildEntry(shop: shopB, eatenAt: DateTime(2027, 1, 1)),
  ]);
  YearReview review(int year) =>
      yearReview(scored, year, questProgress: evaluateQuests(scored));

  test('その年の記録だけを数え、撤退は杯数に入れない', () {
    final r = review(2026);

    expect(r.bowls, 3);
    // 印は食べた1杯だけを、古い順に並べる。
    expect(r.stamps, hasLength(3));
    expect(
      r.stamps.map((e) => e.visit.eatenAt).toList(),
      [...r.stamps.map((e) => e.visit.eatenAt)]..sort(),
    );
    expect(r.shops, 2);
    expect(r.retreats, 1);
    expect(r.points, 75);
    expect(r.isEmpty, isFalse);
    expect(r.monthlyBowls, [1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0]);
    expect(r.styles.length, 2);
  });

  test('いちばん通った店・最高の一杯・いちばん並んだ一杯', () {
    final r = review(2026);

    expect(r.favoriteShop?.shop.id, 'a');
    expect(r.favoriteShop?.count, 2);
    expect(r.highestPoints?.entry.shop.id, 'b');
    expect(r.highestPoints?.value, 35);
    expect(r.longestWait?.value, 45);
    expect(r.longestWait?.entry.visit.eatenAt, DateTime(2026, 3, 5, 12));
  });

  test('2杯以上の店が無ければ、いちばん通った店は無い', () {
    expect(review(2025).favoriteShop, isNull);
    expect(review(2025).longestWait, isNull);
  });

  test('その年に上がった段位と、届いた型・秘伝', () {
    final r = review(2026);

    // 累計 25（2025年・五級）→ 35 → 65（四級）→ 100。
    expect(r.ranks.map((a) => a.rank), [AdventurerRank.kyu4]);
    expect(r.quests.map((q) => q.quest.id), containsAll(['queue', 'retry']));
    expect(r.quests.map((q) => q.quest.id), isNot(contains('first_bowl')));
    expect(r.hasAchievements, isTrue);

    final r2025 = review(2025);
    expect(r2025.ranks.map((a) => a.rank), [AdventurerRank.kyu5]);
    // 2025年の1杯は12月31日なので、秘伝「年越しの一杯」も届く。
    expect(r2025.quests.map((q) => q.quest.id), ['first_bowl', 'new_year_eve']);
  });

  test('型は、その年に上がったいちばん上の段だけを出す', () {
    final r = yearReview(
      const [],
      2026,
      questProgress: [
        QuestProgress(
          quest: quests.first,
          current: 30,
          levelAchievedBy: scoreVisits([
            buildEntry(eatenAt: DateTime(2025, 6, 1)),
            buildEntry(eatenAt: DateTime(2026, 2, 1)),
            buildEntry(eatenAt: DateTime(2026, 11, 1)),
          ]),
        ),
      ],
    );

    expect(r.quests.single.level, 3);
  });

  test('記録の無い年は空', () {
    final r = review(2024);

    expect(r.isEmpty, isTrue);
    expect(r.bowls, 0);
    expect(r.styles, isEmpty);
    expect(r.highestPoints, isNull);
    expect(r.monthlyBowls, List.filled(12, 0));
    expect(r.hasAchievements, isFalse);
  });

  test('撤退だけの年も空ではない', () {
    final onlyRetreat = scoreVisits([
      buildEntry(
        shop: shopA,
        eatenAt: DateTime(2026, 5, 1),
        result: VisitResult.retreated,
      ),
    ]);
    final r = yearReview(onlyRetreat, 2026, questProgress: const []);

    expect(r.isEmpty, isFalse);
    expect(r.bowls, 0);
    expect(r.retreats, 1);
  });

  test('記録のある年を新しい順に返す', () {
    expect(reviewYears(scored), [2027, 2026, 2025]);
    expect(reviewYears(const []), isEmpty);
  });

  test('振り返りを勧めるのは12月（その年）と1月（前の年）だけ', () {
    expect(reviewSeasonYear(DateTime(2026, 11, 30, 23, 59)), isNull);
    expect(reviewSeasonYear(DateTime(2026, 12, 1)), 2026);
    expect(reviewSeasonYear(DateTime(2027, 1, 31, 23, 59)), 2026);
    expect(reviewSeasonYear(DateTime(2027, 2, 1)), isNull);
  });
}
