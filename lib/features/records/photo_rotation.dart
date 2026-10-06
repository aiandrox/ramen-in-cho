import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 「写真を回す」を1回押したあとの向き（時計回りに90度ずつ。4回で元に戻る）。
int nextQuarterTurn(int quarterTurns) => (quarterTurns + 1) % 4;

/// 写真を時計回りに[quarterTurns]×90度回したJPEGを返す。
/// 先に写真の向きの情報どおりに起こし、向きの情報は「そのまま」にする（画面に出ている向きと同じにするため）。
/// 撮影日時・撮影場所などの情報は残す。読めない写真なら例外にする。
Uint8List rotatePhotoBytes(Uint8List bytes, int quarterTurns) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported photo');
  final exif = img.ExifData.from(decoded.exif);
  final upright = img.bakeOrientation(decoded);
  final turns = quarterTurns % 4;
  final rotated = turns == 0
      ? upright
      : img.copyRotate(upright, angle: 90 * turns);
  exif.imageIfd.orientation = null;
  // 小さな見本の画像と縦横の大きさは回す前のままなので外す。
  exif.directories.remove('ifd1');
  exif.thumbnailData = null;
  exif.exifIfd.data
    ..remove(0xA002)
    ..remove(0xA003);
  try {
    rotated.exif = exif;
    return img.encodeJpg(rotated, quality: 90);
  } catch (_) {
    // 書き出せない情報が混じっていたら、撮影日時と撮影場所だけを残す。
    rotated.exif = _dateAndPlace(exif);
    return img.encodeJpg(rotated, quality: 90);
  }
}

img.ExifData _dateAndPlace(img.ExifData source) {
  final kept = img.ExifData();
  const imageTags = [0x0132]; // DateTime
  const exifTags = [0x9003, 0x9004, 0x9010, 0x9011, 0x9012];
  for (final tag in imageTags) {
    final value = source.imageIfd[tag];
    if (value != null) kept.imageIfd[tag] = value;
  }
  for (final tag in exifTags) {
    final value = source.exifIfd[tag];
    if (value != null) kept.exifIfd[tag] = value;
  }
  for (final MapEntry(:key, :value) in source.gpsIfd.data.entries) {
    kept.gpsIfd[key] = value;
  }
  return kept;
}
