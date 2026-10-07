import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/notifications/notification_labels.dart';
import 'package:ramen_in_cho/features/notifications/notification_settings.dart';

import '../../support/l10n.dart';

void main() {
  test('並び中の通知の説明は、経過時間が進まない iOS では「数え続ける」と言わない', () {
    expect(
      notificationKindNote(
        ja,
        NotificationKind.checkin,
        platform: TargetPlatform.iOS,
      ),
      ja.notificationKindCheckinNoteIos,
    );
    expect(
      notificationKindNote(
        ja,
        NotificationKind.checkin,
        platform: TargetPlatform.android,
      ),
      ja.notificationKindCheckinNote,
    );
  });

  test('画面の文言は「チェックイン」と言わず「並ぶ」にそろえる', () {
    // 文言は app_ja.arb のほか、型と秘伝・道中記・言葉の定義ファイルにも直接書いてある。
    const paths = [
      'lib/l10n/app_ja.arb',
      'lib/features/quests/quests.dart',
      'lib/features/journal/journal_phrases.dart',
      'lib/features/words/words.dart',
    ];
    for (final file in paths.map(File.new)) {
      expect(
        file.readAsStringSync(),
        isNot(contains('チェックイン')),
        reason: file.path,
      );
    }
  });
}
