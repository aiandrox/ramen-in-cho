import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 不具合の知らせと Crashlytics の記録を突き合わせるための匿名の識別番号。
/// 端末の識別子からは作らず乱数で作り、端末の中（記録のバックアップには入らない場所）にだけ置く。
class InstallIdStorage {
  InstallIdStorage({
    Future<Directory> Function()? directory,
    String Function()? generate,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _generate = generate ?? const Uuid().v4;

  static const _fileName = 'install_id.txt';

  final Future<Directory> Function() _directory;
  final String Function() _generate;
  Future<String?>? _pending;

  /// 保存してある番号を返す。無ければ作って保存する。読み書きできなければ null。
  /// 起動時の登録と不具合の知らせが同時に呼んでも、別々の番号を作らないようにする。
  Future<String?> currentOrCreate() => _pending ??= _resolve();

  Future<String?> _resolve() async {
    try {
      final dir = await _directory();
      final file = File(p.join(dir.path, _fileName));
      if (await file.exists()) {
        final saved = (await file.readAsString()).trim();
        if (saved.isNotEmpty) return saved;
      }
      final generated = _generate();
      await dir.create(recursive: true);
      await file.writeAsString(generated, flush: true);
      return generated;
    } catch (_) {
      _pending = null;
      return null;
    }
  }
}

final installIdStorageProvider = Provider<InstallIdStorage>(
  (ref) => InstallIdStorage(),
);
