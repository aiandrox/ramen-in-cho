import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/wishes/shared_wish.dart';

(double, double)? _latLng(GeoPoint? point) =>
    point == null ? null : (point.latitude, point.longitude);

void main() {
  group('Google マップの共有', () {
    test('店名・住所・短縮リンクの3行', () {
      final wish = parseSharedWish(
        '麺屋さくら 新宿店\n'
        '〒160-0023 東京都新宿区西新宿１丁目２−３ 新宿ビル 1F\n'
        'https://maps.app.goo.gl/AbCdEf123456',
      )!;
      expect(wish.name, '麺屋さくら 新宿店');
      expect(wish.source, SharedSource.googleMaps);
      expect(wish.link, 'https://maps.app.goo.gl/AbCdEf123456');
      expect(wish.host, 'maps.app.goo.gl');
      expect(wish.address, '東京都新宿区西新宿１丁目２−３ 新宿ビル 1F');
      // 短縮リンクは開かないので、位置はわからない。
      expect(wish.location, isNull);
    });

    test('店名とリンクが1行（iPhone）', () {
      final wish = parseSharedWish(
        '中華そば つばめ https://maps.app.goo.gl/Xyz987?g_st=ic',
      )!;
      expect(wish.name, '中華そば つばめ');
      expect(wish.link, 'https://maps.app.goo.gl/Xyz987?g_st=ic');
      expect(wish.address, isNull);
    });

    test('「 · 」のあとの説明や「日本、」の住所', () {
      final wish = parseSharedWish(
        '札幌味噌 ゆきだるま · 日本、〒060-0062 北海道札幌市中央区南2条西3丁目4-5\n'
        'https://maps.app.goo.gl/Snow12345',
      )!;
      expect(wish.name, '札幌味噌 ゆきだるま');
      expect(wish.address, '北海道札幌市中央区南2条西3丁目4-5');
    });

    test('place の URL から店名と店のピンの位置を読む', () {
      final wish = parseSharedWish(
        'https://www.google.com/maps/place/%E9%BA%BA%E5%B1%8B+%E3%81%AF%E3%81%BE/'
        '@35.4437,139.6380,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2'
        '!3d35.4440123!4d139.6382456!16s',
      )!;
      expect(wish.source, SharedSource.googleMaps);
      expect(wish.name, '麺屋 はま');
      expect(_latLng(wish.location), (35.4440123, 139.6382456));
    });

    test('地図の中心（/@）しかなければそれを位置にする', () {
      final wish = parseSharedWish(
        'https://www.google.co.jp/maps/@43.0621,141.3544,16z',
      )!;
      expect(_latLng(wish.location), (43.0621, 141.3544));
    });

    test('?q=緯度,経度 の位置', () {
      final wish = parseSharedWish(
        '横浜の店\nhttps://maps.google.com/?q=35.4660,139.6223',
      )!;
      expect(_latLng(wish.location), (35.4660, 139.6223));
      expect(wish.name, '横浜の店');
    });
  });

  group('YouTube の共有', () {
    test('URLだけ', () {
      final wish = parseSharedWish('https://youtu.be/abcDEF12345?si=xyz')!;
      expect(wish.source, SharedSource.youtube);
      expect(wish.name, '');
      expect(wish.link, 'https://youtu.be/abcDEF12345?si=xyz');
      expect(wish.host, 'youtu.be');
      expect(wish.address, isNull);
    });

    test('件名に動画の題があっても、店名にはしない', () {
      final wish = parseSharedWish(
        'https://www.youtube.com/watch?v=abcDEF12345',
        subject: '【新宿】行列の絶えない一杯をすする',
      )!;
      expect(wish.source, SharedSource.youtube);
      expect(wish.name, '');
      expect(wish.host, 'youtube.com');
    });
  });

  test('ほかのサイトはホストを残し、店名は空', () {
    final wish = parseSharedWish(
      '新宿で食べたい一杯10選 https://example.com/ramen/shinjuku。',
    )!;
    expect(wish.source, SharedSource.web);
    expect(wish.name, '');
    expect(wish.link, 'https://example.com/ramen/shinjuku');
    expect(wish.host, 'example.com');
  });

  test('リンクの無い文は、1行目を店名にする', () {
    final wish = parseSharedWish('らぁ麺 しらかば\n友だちのおすすめ')!;
    expect(wish.source, SharedSource.text);
    expect(wish.name, 'らぁ麺 しらかば');
    expect(wish.link, isNull);
  });

  test('空の文は読めない', () {
    expect(parseSharedWish('  \n '), isNull);
  });

  test('ありえない座標は位置にしない', () {
    expect(
      locationInUrl(Uri.parse('https://maps.google.com/?q=135.0,139.0')),
      isNull,
    );
  });

  group('住所らしい行', () {
    test('都道府県と番地の数字があれば住所', () {
      expect(addressIn(['神奈川県横浜市西区南幸1-2-3']), '神奈川県横浜市西区南幸1-2-3');
      expect(addressIn(['★4.2 ラーメン屋', '営業中']), isNull);
    });
  });

  group('願のリンクを開く', () {
    test('http・https だけ開く。スキームが無ければ https を付ける', () {
      expect(
        openableLink('maps.app.goo.gl/AbC')!.toString(),
        'https://maps.app.goo.gl/AbC',
      );
      expect(openableLink('javascript:alert(1)'), isNull);
      expect(openableLink('intent://x#Intent;end'), isNull);
      expect(openableLink(''), isNull);
      expect(linkHost('https://www.youtube.com/watch?v=a'), 'youtube.com');
    });
  });
}
