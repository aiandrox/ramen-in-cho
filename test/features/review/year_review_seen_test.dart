import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/review/year_review_seen.dart';

import '../../support/fakes.dart';

void main() {
  test('開いた年を残し、作り直しても覚えている', () {
    final directory = createTempDirectory();
    ProviderContainer create() => ProviderContainer(
      overrides: [documentsDirectoryProvider.overrideWithValue(directory)],
    );
    final first = create();
    addTearDown(first.dispose);
    expect(first.read(yearReviewSeenProvider), isEmpty);
    first.read(yearReviewSeenProvider.notifier).markSeen(2026);

    final second = create();
    addTearDown(second.dispose);
    expect(second.read(yearReviewSeenProvider), {2026});
  });

  test('壊れたファイルは、まだ開いていないものとして読む', () {
    final directory = createTempDirectory();
    File(p.join(directory.path, YearReviewSeenStore.fileName))
        .writeAsStringSync('[');
    expect(YearReviewSeenStore(directory).load(), isEmpty);
  });
}
