import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:ramen_in_cho/features/record/photo_metadata.dart';
import 'package:ramen_in_cho/features/records/photo_rotation.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';

import '../../support/fakes.dart';
import '../../support/photos.dart';

void main() {
  group('nextQuarterTurn', () {
    test('押すたびに90度ずつ進み、4回で元に戻る', () {
      var turns = 0;
      final seen = <int>[];
      for (var i = 0; i < 4; i++) {
        turns = nextQuarterTurn(turns);
        seen.add(turns);
      }
      expect(seen, [1, 2, 3, 0]);
    });
  });

  group('rotatePhotoBytes', () {
    test('時計回りに90度回すと縦横が入れ替わり、左側が上に来る', () {
      final rotated = img.decodeJpg(rotatePhotoBytes(halfRedJpeg(), 1))!;

      expect((rotated.width, rotated.height), (20, 40));
      expect(isRed(rotated.getPixel(10, 5)), isTrue);
      expect(isBlue(rotated.getPixel(10, 35)), isTrue);
    });

    test('180度では縦横はそのままで左右が入れ替わる', () {
      final rotated = img.decodeJpg(rotatePhotoBytes(halfRedJpeg(), 2))!;

      expect((rotated.width, rotated.height), (40, 20));
      expect(isBlue(rotated.getPixel(5, 10)), isTrue);
      expect(isRed(rotated.getPixel(35, 10)), isTrue);
    });

    test('4回ぶん回すと元の向きに戻る', () {
      var bytes = halfRedJpeg();
      for (var i = 0; i < 4; i++) {
        bytes = rotatePhotoBytes(bytes, 1);
      }
      final rotated = img.decodeJpg(bytes)!;

      expect((rotated.width, rotated.height), (40, 20));
      expect(isRed(rotated.getPixel(5, 10)), isTrue);
      expect(isBlue(rotated.getPixel(35, 10)), isTrue);
    });

    test('向きの情報のある写真は、見えている向きから回し、向きの情報を外す', () {
      // 向き6＝表示するときに時計回りに90度回す写真（見えているのは縦20×横40の、上が赤）。
      final rotated = img.decodeJpg(
        rotatePhotoBytes(halfRedJpeg(orientation: 6), 1),
      )!;

      expect((rotated.width, rotated.height), (40, 20));
      // 見えている向き（上が赤）を時計回りに回すと、右が赤になる。
      expect(isRed(rotated.getPixel(35, 10)), isTrue);
      expect(isBlue(rotated.getPixel(5, 10)), isTrue);
      expect(
        rotated.exif.imageIfd.hasOrientation &&
            rotated.exif.imageIfd.orientation != 1,
        isFalse,
      );
    });

    test('撮影日時と撮影場所は回したあとも残る', () async {
      final source = File('test/fixtures/photo_with_exif.jpg');
      final before = await const ExifPhotoMetadataReader().read(source.path);
      final rotated = File(p.join(createTempDirectory().path, 'rotated.jpg'))
        ..writeAsBytesSync(rotatePhotoBytes(source.readAsBytesSync(), 1));

      final after = await const ExifPhotoMetadataReader().read(rotated.path);

      expect(before.takenAt, isNotNull);
      expect(after.takenAt, before.takenAt);
      expect(after.location!.latitude, before.location!.latitude);
      expect(after.location!.longitude, before.location!.longitude);
    });

    test('写真として読めなければ例外にする', () {
      expect(
        () => rotatePhotoBytes(Uint8List.fromList([1, 2, 3]), 1),
        throwsA(anything),
      );
    });
  });

  group('PhotoStorage.saveRotated', () {
    test('回した写真を新しい名前で書き、もとのファイルには触れない', () async {
      final storage = PhotoStorage(createTempDirectory());
      final source = writeJpeg(
        p.join(createTempDirectory().path, 'picked.jpeg'),
      );
      final original = source.readAsBytesSync();

      final saved = await storage.saveRotated(source.path, 1);

      expect(p.dirname(saved), 'photos');
      expect(p.extension(saved), '.jpg');
      final rotated = img.decodeJpg(storage.fileFor(saved).readAsBytesSync())!;
      expect((rotated.width, rotated.height), (20, 40));
      expect(source.readAsBytesSync(), original);
      expect(
        Directory(p.dirname(storage.fileFor(saved).path)).listSync().length,
        1,
        reason: '書きかけのファイルを残さない',
      );
    });

    test('回していなければそのまま写す', () async {
      final storage = PhotoStorage(createTempDirectory());
      final source = File(p.join(createTempDirectory().path, 'a.png'))
        ..writeAsBytesSync([1, 2, 3]);

      final saved = await storage.saveRotated(source.path, 4);

      expect(p.extension(saved), '.png');
      expect(storage.fileFor(saved).readAsBytesSync(), [1, 2, 3]);
    });
  });
}
