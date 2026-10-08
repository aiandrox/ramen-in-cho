import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home/rating_prompt.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  testWidgets('★を押すと保存し、付けた数を知らせる', (tester) async {
    final repository = FakeRecordRepository();
    final entry = buildEntry(shop: buildShop(name: '麺屋テスト'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [recordRepositoryProvider.overrideWithValue(repository)],
        child: localizedApp(
          home: Scaffold(body: RatingPrompt(entry: entry)),
        ),
      ),
    );

    await tester.tap(find.byTooltip(ja.ratingStar(4)));
    await tester.pump();

    expect(repository.ratings[entry.visit.id], 4);
    expect(find.text(ja.ratingSaved('★★★★')), findsOneWidget);
  });
}
