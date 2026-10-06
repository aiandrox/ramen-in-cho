import '../shop_search/geo.dart';

/// 共有してきたアプリ（きっかけの初期値に使う）。
enum SharedSource { googleMaps, appleMaps, youtube, web, text }

/// ほかのアプリの「共有」から届いた文から、願の下書きにするもの。
class SharedWish {
  const SharedWish({
    required this.name,
    required this.source,
    this.link,
    this.host,
    this.location,
    this.address,
  });

  /// 店名の候補。わからなければ空。
  final String name;
  final SharedSource source;
  final String? link;

  /// リンクのホスト（`www.` を除く）。リンクが無ければnull。
  final String? host;

  /// リンクそのものに書かれていた位置。短縮リンクは開いて確かめない（通信先を増やさないため）。
  final GeoPoint? location;

  /// 共有の文に書かれていた住所（Google マップの共有など）。位置にするのはサーバーに頼む。
  final String? address;
}

final _urlPattern = RegExp(r'https?://[^\s<>"「」（）]+', caseSensitive: false);

/// 共有された文（と件名）を読み解く。何も読み取れなければnull。
SharedWish? parseSharedWish(String text, {String? subject}) {
  final body = [
    if (subject != null && subject.trim().isNotEmpty && !text.contains(subject))
      subject,
    text,
  ].join('\n');
  final match = _urlPattern.firstMatch(body);
  final link = match == null ? null : _trimTrailing(match.group(0)!);
  final uri = link == null ? null : Uri.tryParse(link);
  final lines = [
    for (final line in body.split(RegExp(r'\r?\n')))
      if (line.replaceAll(_urlPattern, '').trim() case final rest
          when rest.isNotEmpty)
        rest,
  ];
  if (uri == null && lines.isEmpty) return null;

  final source = uri == null ? SharedSource.text : _sourceOf(uri);
  final isPlace = switch (source) {
    SharedSource.googleMaps ||
    SharedSource.appleMaps ||
    SharedSource.text => true,
    SharedSource.youtube || SharedSource.web => false,
  };
  final parts = [
    for (final line in lines)
      for (final part in line.split(' · '))
        if (part.trim().isNotEmpty) part.trim(),
  ];
  final address = isPlace ? addressIn(parts.skip(1)) : null;
  var name = isPlace && parts.isNotEmpty && !_looksLikeAddress(parts.first)
      ? parts.first
      : '';
  if (name.isEmpty && uri != null && source == SharedSource.googleMaps) {
    name = _placeNameOf(uri);
  }
  return SharedWish(
    name: name,
    source: source,
    link: link,
    host: uri == null ? null : _hostOf(uri),
    location: uri == null ? null : locationInUrl(uri),
    address: address,
  );
}

final _postalCode = RegExp(r'〒?\s*\d{3}[-－ー‐]\d{4}\s*');
final _prefecture = RegExp(r'^(東京都|北海道|(?:京都|大阪)府|.{2,3}県)');
final _cityAndBlock = RegExp(r'[市区町村郡].*[0-9０-９]');

bool _looksLikeAddress(String line) {
  final rest = _stripAddressPrefix(line);
  return line.contains('〒') ||
      (_prefecture.hasMatch(rest) && _cityAndBlock.hasMatch(rest));
}

String _stripAddressPrefix(String line) => line
    .trim()
    .replaceFirst(RegExp(r'^日本[、,]\s*'), '')
    .replaceFirst(_postalCode, '')
    .trim();

/// 共有の文のうち、住所らしい行（都道府県から始まり、番地の数字を含む。〒があればそれでもよい）。
String? addressIn(Iterable<String> lines) {
  for (final line in lines) {
    if (!_looksLikeAddress(line)) continue;
    final address = _stripAddressPrefix(line);
    if (address.isNotEmpty) return address;
  }
  return null;
}

String _trimTrailing(String url) =>
    url.replaceFirst(RegExp(r'''[.,。、!！?？'"』】\]]+$'''), '');

String _hostOf(Uri uri) => uri.host.toLowerCase().replaceFirst('www.', '');

SharedSource _sourceOf(Uri uri) {
  final host = _hostOf(uri);
  final path = uri.path;
  if (host == 'maps.app.goo.gl' ||
      (host == 'goo.gl' && path.startsWith('/maps')) ||
      host.startsWith('maps.google.') ||
      (host.startsWith('google.') && path.startsWith('/maps'))) {
    return SharedSource.googleMaps;
  }
  if (host == 'maps.apple.com' || host == 'maps.apple') {
    return SharedSource.appleMaps;
  }
  if (host == 'youtu.be' ||
      host == 'youtube.com' ||
      host.endsWith('.youtube.com')) {
    return SharedSource.youtube;
  }
  return SharedSource.web;
}

/// google.com/maps/place/店名/@… の店名。
String _placeNameOf(Uri uri) {
  final segments = uri.pathSegments;
  final index = segments.indexOf('place');
  if (index < 0 || index + 1 >= segments.length) return '';
  return segments[index + 1].replaceAll('+', ' ').trim();
}

final _pinPattern = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)');
final _atPattern = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
final _pairPattern = RegExp(
  r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
);

/// リンクに書かれた位置。店のピン（!3d…!4d…）、座標の問い合わせ（?q=緯度,経度 など）、
/// 地図の中心（/@緯度,経度）の順に探す。
GeoPoint? locationInUrl(Uri uri) {
  final full = Uri.decodeFull(uri.toString());
  final pin = _pinPattern.firstMatch(full);
  if (pin != null) return _point(pin.group(1)!, pin.group(2)!);
  for (final key in const ['q', 'query', 'll', 'center', 'daddr', 'sll']) {
    final value = uri.queryParameters[key];
    if (value == null) continue;
    final pair = _pairPattern.firstMatch(value);
    if (pair == null) continue;
    final point = _point(pair.group(1)!, pair.group(2)!);
    if (point != null) return point;
  }
  final at = _atPattern.firstMatch(full);
  if (at != null) return _point(at.group(1)!, at.group(2)!);
  return null;
}

GeoPoint? _point(String latitude, String longitude) {
  final lat = double.tryParse(latitude);
  final lng = double.tryParse(longitude);
  if (lat == null || lng == null) return null;
  if (lat.abs() > 90 || lng.abs() > 180 || (lat == 0 && lng == 0)) return null;
  return GeoPoint(lat, lng);
}

/// 願に残したリンクを開くときの URL。http・https 以外（アプリを直接呼ぶものなど）は開かない。
Uri? openableLink(String link) {
  final trimmed = link.trim();
  if (trimmed.isEmpty) return null;
  final withScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed)
      ? trimmed
      : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

/// リンクの見出しに出すホスト（`www.` を除く）。開けないリンクならnull。
String? linkHost(String link) {
  final uri = openableLink(link);
  return uri == null ? null : _hostOf(uri);
}
