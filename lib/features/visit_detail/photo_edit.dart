import '../records/photo_storage.dart';

/// 編集画面での写真の差し替え。選んだ写真はすぐdocumentsにコピーし（一時ファイルは
/// OSに消されることがあるため）、前の写真は記録に新しいパスを書けたあとにだけ消す。
class PhotoEdit {
  PhotoEdit(this._storage, {required this.original});

  final PhotoStorage _storage;

  /// 編集を始めたときの写真の相対パス。
  final String? original;

  String? _copied;
  bool _changed = false;

  bool get isChanged => _changed;

  /// いま画面に出す写真の相対パス。
  String? get current => _changed ? _copied : original;

  Future<void> replace(String sourcePath) async {
    final saved = await _storage.save(sourcePath);
    await _deleteCopy();
    _copied = saved;
    _changed = true;
  }

  Future<void> remove() async {
    await _deleteCopy();
    _changed = true;
  }

  /// 保存せずに閉じたとき。コピーした写真だけを消し、前の写真は残す。
  Future<void> discard() => _deleteCopy();

  /// 記録に保存できたあと。[unusedPhoto]はどの記録も使わなくなった前の写真。
  Future<void> commit(String? unusedPhoto) async {
    _copied = null;
    if (unusedPhoto != null) await _storage.delete(unusedPhoto);
  }

  Future<void> _deleteCopy() async {
    final copied = _copied;
    _copied = null;
    if (copied != null) await _storage.delete(copied);
  }
}
