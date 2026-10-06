import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/ramen_in_cho_api.dart';
import 'package:ramen_in_cho/features/wishes/wish_dialog.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  Future<FakeWishRepository> open(
    WidgetTester tester, {
    required Future<GeoPoint?> Function(String) geocoder,
    String name = '',
    String trigger = '',
    String? link,
    String? address,
  }) async {
    final repository = FakeWishRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishRepositoryProvider.overrideWithValue(repository),
          addressGeocoderProvider.overrideWithValue(geocoder),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 12)),
        ],
        child: localizedApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => addWishByName(
                  context,
                  ref,
                  name: name,
                  trigger: trigger,
                  link: link,
                  address: address,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('共有の下書き（店名・きっかけ・リンク）を入れておき、住所から場所を決める', (tester) async {
    final asked = <String>[];
    final repository = await open(
      tester,
      geocoder: (address) async {
        asked.add(address);
        return const GeoPoint(35.6896, 139.6917);
      },
      name: '麺屋さくら',
      trigger: ja.wishTriggerGoogleMaps,
      link: 'https://maps.app.goo.gl/AbC',
      address: '東京都新宿区西新宿2-8-1',
    );

    expect(asked, ['東京都新宿区西新宿2-8-1']);
    expect(find.text(ja.wishPlaceFromAddress), findsOneWidget);
    expect(find.text('https://maps.app.goo.gl/AbC'), findsOneWidget);

    await tester.tap(find.text(ja.wishAddButton).last);
    await tester.pumpAndSettle();

    final shop = repository.added.single;
    expect(shop.name, '麺屋さくら');
    expect((shop.latitude, shop.longitude), (35.6896, 139.6917));
    expect(repository.triggers.single, 'Google マップ');
    expect(repository.links.single, 'https://maps.app.goo.gl/AbC');
  });

  testWidgets('住所から場所がわからなければ、場所なしで掛けられる。外すこともできる', (tester) async {
    final repository = await open(
      tester,
      geocoder: (_) async => null,
      link: 'https://youtu.be/abc',
      address: '北海道札幌市中央区南2条西3丁目4-5',
    );

    expect(find.text(ja.wishPlaceNone), findsOneWidget);
    expect(find.text(ja.nameSearchOpen), findsOneWidget);
    expect(find.text(ja.locationPickOpen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '札幌の店');
    await tester.pump();
    await tester.tap(find.text(ja.wishAddButton).last);
    await tester.pumpAndSettle();

    expect(repository.added.single.latitude, isNull);
    expect(repository.links.single, 'https://youtu.be/abc');
  });
}
