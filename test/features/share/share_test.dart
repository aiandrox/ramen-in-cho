import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/share/share_card.dart';
import 'package:ramen_in_cho/features/share/share_screen.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

import '../../support/builders.dart';
import '../../support/l10n.dart';

void main() {
  test('道中記の文から修行点だけを除く', () {
    expect(withoutPoints('着丼。醤油の一杯、修行点 85。'), '着丼。醤油の一杯。');
    expect(withoutPoints('今年 3杯目。'), '今年 3杯目。');
  });

  testWidgets('共有の前に、道中記と修行点を入れるかを切り替えられる', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final entry = buildEntry(
      shop: buildShop(name: 'はやし田'),
      style: RamenStyle.shoyu,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitsProvider.overrideWithValue(AsyncData([entry])),
          homeBaseSettingsProvider.overrideWithValue(const AsyncData([])),
          wishesProvider.overrideWithValue(const AsyncData([])),
        ],
        child: localizedApp(home: ShareScreen(visitId: entry.visit.id)),
      ),
    );
    await tester.pumpAndSettle();

    Finder pointsLine() => find.textContaining('修行点 ');
    expect(find.text(ja.journalTitle), findsOneWidget);
    expect(pointsLine(), findsOneWidget);
    // 写真の無い記録には「写真を入れる」を出さない。
    expect(find.text(ja.shareIncludePhoto), findsNothing);

    await tester.tap(find.text(ja.shareIncludePoints));
    await tester.pumpAndSettle();
    expect(pointsLine(), findsNothing);

    await tester.tap(find.text(ja.shareIncludeJournal));
    await tester.pumpAndSettle();
    expect(find.text(ja.journalTitle), findsNothing);
  });
}
