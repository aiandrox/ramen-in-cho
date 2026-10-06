import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../records/photo_storage.dart';

final yearReviewSeenStoreProvider = Provider<YearReviewSeenStore>(
  (ref) => YearReviewSeenStore(ref.watch(documentsDirectoryProvider)),
);

/// 年の振り返りを開いた年を、documents の `year_review_seen.json` に残す。
/// 開いた年には、振り返りを勧める通知を出さないため。
class YearReviewSeenStore {
  YearReviewSeenStore(this._documents);

  static const fileName = 'year_review_seen.json';

  final Directory _documents;

  File get _file => File(p.join(_documents.path, fileName));

  Set<int> load() {
    try {
      final json = jsonDecode(_file.readAsStringSync());
      if (json is Map<String, dynamic> && json['years'] is List) {
        return {...(json['years'] as List).whereType<int>()};
      }
    } on FileSystemException {
      // まだ一度も開いていない。
    } on FormatException {
      // 壊れたファイルは、次に開いたときに書き直される。
    }
    return {};
  }

  void save(Set<int> years) {
    try {
      _file.writeAsStringSync(jsonEncode({'years': years.toList()..sort()}));
    } on FileSystemException catch (e) {
      debugPrint('Year review seen save failed: $e');
    }
  }
}

final yearReviewSeenProvider = NotifierProvider<YearReviewSeen, Set<int>>(
  YearReviewSeen.new,
);

class YearReviewSeen extends Notifier<Set<int>> {
  @override
  Set<int> build() => ref.watch(yearReviewSeenStoreProvider).load();

  void markSeen(int year) {
    if (state.contains(year)) return;
    final years = {...state, year};
    ref.read(yearReviewSeenStoreProvider).save(years);
    state = years;
  }
}
