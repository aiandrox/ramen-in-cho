import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../records/clock.dart';
import '../records/photo_storage.dart';
import 'builtin_shops.dart';
import 'ramen_in_cho_api.dart';

/// 手で持つ店の一覧。起動したときは同梱分で始め、保存した分やサーバーの分が読めたら差し替える。
final curatedShopsProvider =
    NotifierProvider<CuratedShopsNotifier, List<BuiltinShop>>(
      CuratedShopsNotifier.new,
    );

class CuratedShopsNotifier extends Notifier<List<BuiltinShop>> {
  @override
  List<BuiltinShop> build() => builtinShops;

  /// 保存した一覧を読み、1日以上たっていればサーバーから取り直す。失敗しても今の一覧のまま。
  Future<void> refresh() async {
    try {
      final store = CuratedShopsStore(
        ref.read(documentsDirectoryProvider),
        api: ref.read(ramenInChoApiProvider),
      );
      final saved = await store.load();
      if (saved != null && ref.mounted) state = saved.shops;
      final fresh = await store.refreshIfStale(
        saved,
        ref.read(clockProvider)(),
      );
      if (fresh != null && ref.mounted) state = fresh.shops;
    } catch (e) {
      debugPrint('Curated shops refresh failed: $e');
    }
  }
}

class SavedCuratedShops {
  const SavedCuratedShops({
    required this.shops,
    required this.fetchedAt,
    this.etag,
  });

  final List<BuiltinShop> shops;
  final DateTime fetchedAt;
  final String? etag;
}

/// 手で持つ店の一覧を、documents ディレクトリの1つのファイルに保存する。
class CuratedShopsStore {
  CuratedShopsStore(this._documents, {required this._api});

  static const fileName = 'curated_shops.json';
  static const refreshInterval = Duration(days: 1);

  /// 保存したファイルの形の版。版の違うファイルは読まずに取り直す
  /// （同じ ETag で聞くと「変わっていない」と返され、古い形の一覧が残り続けるため）。
  static const formatVersion = 2;

  final Directory _documents;
  final RamenInChoApi? _api;

  File get _file => File(p.join(_documents.path, fileName));

  Future<SavedCuratedShops?> load() async {
    try {
      if (!await _file.exists()) return null;
      final json =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      if (json['format'] != formatVersion) return null;
      return SavedCuratedShops(
        shops: [
          for (final shop in json['shops'] as List)
            ?BuiltinShop.fromJson(shop as Map<String, dynamic>),
        ],
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        etag: json['etag'] as String?,
      );
    } catch (e) {
      debugPrint('Curated shops load failed: $e');
      return null;
    }
  }

  /// 前に取ってから[refreshInterval]たっていればサーバーから取り直して保存し、新しい一覧を返す。
  /// 取り直さなかった・失敗したときはnull。
  Future<SavedCuratedShops?> refreshIfStale(
    SavedCuratedShops? saved,
    DateTime now,
  ) async {
    final api = _api;
    if (api == null) return null;
    if (saved != null && now.difference(saved.fetchedAt) < refreshInterval) {
      return null;
    }
    try {
      final response = await api.curatedShops(etag: saved?.etag);
      final shops = response.shops ?? saved?.shops;
      if (shops == null) return null;
      final fresh = SavedCuratedShops(
        shops: shops,
        fetchedAt: now,
        etag: response.etag,
      );
      await _file.writeAsString(
        jsonEncode({
          'format': formatVersion,
          'fetchedAt': now.toUtc().toIso8601String(),
          'etag': ?fresh.etag,
          'shops': [for (final shop in shops) shop.toJson()],
        }),
      );
      return fresh;
    } catch (e) {
      debugPrint('Curated shops refresh failed: $e');
      return null;
    }
  }
}
