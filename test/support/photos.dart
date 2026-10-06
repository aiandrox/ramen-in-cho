import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 横40×縦20、左半分が赤・右半分が青のJPEG。回した向きを色で確かめる。
Uint8List halfRedJpeg({int? orientation}) {
  final image = img.Image(width: 40, height: 20);
  for (final pixel in image) {
    if (pixel.x < 20) {
      pixel.setRgb(255, 0, 0);
    } else {
      pixel.setRgb(0, 0, 255);
    }
  }
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(image, quality: 100);
}

File writeJpeg(String path, [Uint8List? bytes]) =>
    File(path)..writeAsBytesSync(bytes ?? halfRedJpeg());

bool isRed(img.Pixel pixel) => pixel.r > 200 && pixel.b < 60;

bool isBlue(img.Pixel pixel) => pixel.b > 200 && pixel.r < 60;
