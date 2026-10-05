import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 店の位置を端末の地図アプリで開くための URL を、試す順に返す。
/// iOS は Apple のマップ、Android は geo: で既定の地図アプリ、どちらも開けなければブラウザの Google マップ。
List<Uri> mapsUris({
  required double latitude,
  required double longitude,
  required String name,
  required bool apple,
}) {
  final ll = '${_coord(latitude)},${_coord(longitude)}';
  final trimmed = name.trim();
  final Uri primary;
  if (apple) {
    primary = Uri.parse(
      'https://maps.apple.com/?ll=$ll&q=${Uri.encodeComponent(trimmed)}',
    );
  } else {
    // geo: のラベルは丸括弧で囲むので、店名の中の丸括弧は全角にして崩れないようにする。
    final label = trimmed.replaceAll('(', '（').replaceAll(')', '）');
    primary = Uri.parse('geo:$ll?q=$ll(${Uri.encodeComponent(label)})');
  }
  return [
    primary,
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$ll'),
  ];
}

String _coord(double value) => value.toStringAsFixed(6);

/// 地図アプリで開く。どれも開けなければ false。
Future<bool> openInMaps({
  required double latitude,
  required double longitude,
  required String name,
}) async {
  final apple =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  final uris = mapsUris(
    latitude: latitude,
    longitude: longitude,
    name: name,
    apple: apple,
  );
  for (final uri in uris) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } on PlatformException catch (e) {
      debugPrint('Open in maps failed: $e');
    }
  }
  return false;
}
