import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'photo_rotation.dart';

/// 起動時に`main`で実際のディレクトリへ差し替える。
final documentsDirectoryProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('documentsDirectoryProvider'),
);

final photoStorageProvider = Provider<PhotoStorage>(
  (ref) => PhotoStorage(ref.watch(documentsDirectoryProvider)),
);

/// 撮った写真をdocumentsディレクトリに保存する。image_pickerが返すのは一時ファイルで、
/// OSに消されることがあるため。
class PhotoStorage {
  PhotoStorage(this._documents, {this._uuid = const Uuid()});

  static const _directoryName = 'photos';

  final Directory _documents;
  final Uuid _uuid;

  /// 保存したファイルの、documentsディレクトリからの相対パスを返す。
  Future<String> save(String sourcePath) async {
    final extension = p.extension(sourcePath).toLowerCase();
    final relativePath = p.join(
      _directoryName,
      '${_uuid.v4()}${extension.isEmpty ? '.jpg' : extension}',
    );
    final destination = fileFor(relativePath);
    await destination.parent.create(recursive: true);
    await File(sourcePath).copy(destination.path);
    return relativePath;
  }

  /// [quarterTurns]回（時計回りに90度ずつ）回した写真を新しいファイルに書き、その相対パスを返す。
  /// 回さないときは[save]と同じ。もとのファイルには触れない。
  Future<String> saveRotated(String sourcePath, int quarterTurns) async {
    if (quarterTurns % 4 == 0) return save(sourcePath);
    final bytes = await File(sourcePath).readAsBytes();
    final rotated = await compute(
      (Uint8List bytes) => rotatePhotoBytes(bytes, quarterTurns),
      bytes,
    );
    final relativePath = p.join(_directoryName, '${_uuid.v4()}.jpg');
    final destination = fileFor(relativePath);
    await destination.parent.create(recursive: true);
    final partial = File('${destination.path}.tmp');
    try {
      await partial.writeAsBytes(rotated, flush: true);
      await partial.rename(destination.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    return relativePath;
  }

  File fileFor(String relativePath) =>
      File(p.join(_documents.path, relativePath));

  Future<void> delete(String relativePath) async {
    final file = fileFor(relativePath);
    if (await file.exists()) await file.delete();
  }
}
