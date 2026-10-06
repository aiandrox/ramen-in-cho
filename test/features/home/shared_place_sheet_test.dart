import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home/shared_place_sheet.dart';
import 'package:ramen_in_cho/features/wishes/shared_wish.dart';

import '../../support/l10n.dart';

void main() {
  test('記録と願掛けを選べるのは、地図アプリの店の共有だけ', () {
    expect(
      parseSharedWish('麺屋さくら\nhttps://maps.app.goo.gl/AbC')!.isMapPlace,
      isTrue,
    );
    expect(
      parseSharedWish('https://maps.apple.com/?ll=35.69,139.70&q=X')!
          .isMapPlace,
      isTrue,
    );
    expect(parseSharedWish('https://youtu.be/abc')!.isMapPlace, isFalse);
    expect(parseSharedWish('https://example.com/ramen')!.isMapPlace, isFalse);
  });

  for (final (label, expected) in [
    (ja.sharedPlaceRecordTitle, SharedPlaceChoice.record),
    (ja.sharedPlaceWishTitle, SharedPlaceChoice.wish),
  ]) {
    testWidgets('「$label」を選ぶ', (tester) async {
      SharedPlaceChoice? chosen;
      await tester.pumpWidget(
        localizedApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => chosen = await showSharedPlaceSheet(
                  context,
                  shopName: '麺屋さくら',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('麺屋さくら'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(chosen, expected);
    });
  }
}
