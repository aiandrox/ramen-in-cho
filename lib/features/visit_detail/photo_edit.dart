import '../records/photo_rotation.dart';
import '../records/photo_storage.dart';

/// 編集画面での写真の差し替え。選んだ写真はすぐdocumentsにコピーし（一時ファイルは
/// OSに消されることがあるため）、前の写真は記録に新しいパスを書けたあとにだけ消す。
class PhotoEdit {
  PhotoEdit(this._storage, {required this.original});

  final PhotoStorage _storage;

  /// 編集を始めたときの写真の相対パス。
  final String? original;

  String? _copied;

  /// 保存の前に書いた、回した写真。
  String? _rotated;
  bool _changed = false;
  int _quarterTurns = 0;

  bool get isChanged => _changed || _quarterTurns != 0;

  /// 画面で回して見せる回数（時計回りに90度ずつ、0〜3）。
  int get quarterTurns => _quarterTurns;

  /// いま画面に出す写真の相対パス。
  String? get current => _changed ? _copied : original;

  Future<void> replace(String sourcePath) async {
    final saved = await _storage.save(sourcePath);
    await _deleteCopy();
    _copied = saved;
    _changed = true;
    _quarterTurns = 0;
  }

  Future<void> remove() async {
    await _deleteCopy();
    _changed = true;
    _quarterTurns = 0;
  }

  void rotate() {
    if (current == null) return;
    _quarterTurns = nextQuarterTurn(_quarterTurns);
  }

  /// 保存の直前に呼ぶ。回していれば回した写真を新しいファイルに書き、記録に書く相対パスを返す。
  /// もとの写真はここでは消さない（記録に書けたあとに[commit]で消す）。
  Future<String?> prepare() async {
    await _deleteRotated();
    final source = current;
    if (source == null || _quarterTurns == 0) return source;
    final rotated = await _storage.saveRotated(
      _storage.fileFor(source).path,
      _quarterTurns,
    );
    _rotated = rotated;
    return rotated;
  }

  /// 記録に書けなかったとき。[prepare]で書いた写真だけを消す。
  Future<void> abandonPrepared() => _deleteRotated();

  /// 保存せずに閉じたとき。コピーした写真と回した写真だけを消し、前の写真は残す。
  Future<void> discard() async {
    await _deleteRotated();
    await _deleteCopy();
  }

  /// 記録に保存できたあと。[unusedPhoto]はどの記録も使わなくなった前の写真。
  /// 選び直した写真を回して保存したときは、回す前のコピーも使わなくなる。
  Future<void> commit(String? unusedPhoto) async {
    final copied = _copied;
    final rotated = _rotated;
    _copied = null;
    _rotated = null;
    if (rotated != null && copied != null) await _storage.delete(copied);
    if (unusedPhoto != null) await _storage.delete(unusedPhoto);
  }

  Future<void> _deleteRotated() async {
    final rotated = _rotated;
    _rotated = null;
    if (rotated != null) await _storage.delete(rotated);
  }

  Future<void> _deleteCopy() async {
    final copied = _copied;
    _copied = null;
    if (copied != null) await _storage.delete(copied);
  }
}
