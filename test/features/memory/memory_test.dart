import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/memory/memory.dart';
import 'package:ramen_in_cho/features/memory/memory_card.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';
import 'package:ramen_in_cho/features/words/words.dart';

import '../../support/builders.dart';
import '../../support/l10n.dart';

void main() {
  final a = buildShop(id: 'a', name: 'はやし田');
  final b = buildShop(id: 'b', name: '藤ろう');
  final today = DateTime(2026, 10, 3, 9);

  test('前の年の同じ月日に食べた1杯のうち、いちばん近い年のものを返す', () {
    final memory = memoryOfTheDay(
      scoreVisits([
        buildEntry(shop: a, eatenAt: DateTime(2024, 10, 3, 12)),
        buildEntry(shop: b, eatenAt: DateTime(2025, 10, 3, 12)),
        buildEntry(
          shop: b,
          result: VisitResult.retreated,
          eatenAt: DateTime(2023, 10, 3, 12),
        ),
        buildEntry(shop: a, eatenAt: DateTime(2025, 10, 4, 12)),
        buildEntry(shop: a, eatenAt: DateTime(2026, 10, 3, 8)),
      ]),
      today,
    )!;

    expect(memory.scored.shop.id, 'b');
    expect(memory.yearsAgo, 1);
    expect(memory.notVisitedSince, isTrue);
  });

  test('あれから同じ店で食べていれば、行っていないとは言わない', () {
    final memory = memoryOfTheDay(
      scoreVisits([
        buildEntry(shop: a, eatenAt: DateTime(2024, 10, 3, 12)),
        buildEntry(shop: a, eatenAt: DateTime(2025, 5, 1, 12)),
      ]),
      today,
    )!;

    expect(memory.yearsAgo, 2);
    expect(memory.notVisitedSince, isFalse);
  });

  test('同じ月日の記録が無ければ出さない', () {
    expect(
      memoryOfTheDay(
        scoreVisits([buildEntry(shop: a, eatenAt: DateTime(2025, 10, 2))]),
        today,
      ),
      isNull,
    );
  });

  test('うるう年でない年の2月28日には、2月29日の1杯を思い出す', () {
    final memory = memoryOfTheDay(
      scoreVisits([buildEntry(shop: a, eatenAt: DateTime(2024, 2, 29, 12))]),
      DateTime(2025, 2, 28, 9),
    );

    expect(memory?.yearsAgo, 1);
    expect(
      memoryOfTheDay(
        scoreVisits([buildEntry(shop: a, eatenAt: DateTime(2024, 2, 29, 12))]),
        DateTime(2028, 2, 28, 9),
      ),
      isNull,
    );
  });

  testWidgets('一覧の上に一年前の今日の1杯を出し、×で閉じられる', (tester) async {
    final entry = buildEntry(shop: a, eatenAt: DateTime(2025, 10, 3, 12));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData([entry])),
          wishesProvider.overrideWithValue(const AsyncData([])),
          clockProvider.overrideWithValue(() => today),
        ],
        child: localizedApp(home: const Scaffold(body: MemoryCard())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ja.memoryYearsAgo('一')), findsOneWidget);
    expect(find.text(ja.memoryLine('はやし田')), findsOneWidget);
    expect(find.text(ja.memoryNotSince), findsOneWidget);
    expect(find.text(memoryWhisper(entry.visit.id, 1)), findsOneWidget);
    expect(find.text(ja.wishMakeButton), findsOneWidget);

    await tester.tap(find.byTooltip(ja.memoryDismiss));
    await tester.pumpAndSettle();
    expect(find.text(ja.memoryLine('はやし田')), findsNothing);
  });
}
