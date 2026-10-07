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
    final arb = File('lib/l10n/app_ja.arb').readAsStringSync();
    expect(arb, isNot(contains('チェックイン')));
  });
}
