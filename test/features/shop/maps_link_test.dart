import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/features/shop/maps_link.dart';

void main() {
  group('mapsUris', () {
    test('iOS は Apple のマップを開き、だめならブラウザの Google マップ', () {
      final uris = mapsUris(
        latitude: 35.443708,
        longitude: 139.362543,
        name: 'らーめん 一番',
        apple: true,
      );
      expect(uris.map((u) => u.toString()), [
        'https://maps.apple.com/?ll=35.443708,139.362543'
            '&q=%E3%82%89%E3%83%BC%E3%82%81%E3%82%93%20%E4%B8%80%E7%95%AA',
        'https://www.google.com/maps/search/?api=1&query=35.443708,139.362543',
      ]);
      expect(uris.first.queryParameters['q'], 'らーめん 一番');
    });

    test('Android は geo: で既定の地図アプリを開く', () {
      final uris = mapsUris(
        latitude: 35.6812,
        longitude: 139.7671,
        name: ' Ramen Jiro ',
        apple: false,
      );
      expect(
        uris.first.toString(),
        'geo:35.681200,139.767100?q=35.681200,139.767100(Ramen%20Jiro)',
      );
      expect(
        uris.last.toString(),
        'https://www.google.com/maps/search/?api=1&query=35.681200,139.767100',
      );
    });

    test('店名の丸括弧は全角にしてラベルを崩さない', () {
      final uri = mapsUris(
        latitude: 35,
        longitude: 139,
        name: '麺屋(本店)',
        apple: false,
      ).first;
      expect(uri.toString(), isNot(contains('本店)')));
      expect(Uri.decodeComponent(uri.query), 'q=35.000000,139.000000(麺屋（本店）)');
    });

    test('& を含む店名でも Apple のマップの q がひとまとまりになる', () {
      final uri = mapsUris(
        latitude: 35,
        longitude: 139,
        name: 'A&B',
        apple: true,
      ).first;
      expect(uri.queryParameters['q'], 'A&B');
      expect(uri.queryParameters['ll'], '35.000000,139.000000');
    });
  });
}
