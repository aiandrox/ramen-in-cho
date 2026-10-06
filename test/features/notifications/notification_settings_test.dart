import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ramen_in_cho/features/notifications/notification_settings.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';

import '../../support/fakes.dart';

void main() {
  test('保存していなければ、すべてオン・連続記録は日曜18時', () {
    final store = NotificationSettingsStore(createTempDirectory());
    final settings = store.load();

    expect(settings, NotificationSettings.defaults);
    for (final kind in NotificationKind.values) {
      expect(settings.isEnabled(kind), isTrue);
    }
    expect(settings.streakWeekday, DateTime.sunday);
    expect((settings.streakHour, settings.streakMinute), (18, 0));
    expect(settings.quietNight, isFalse);
  });

  test('保存した設定を読み直せる', () {
    final directory = createTempDirectory();
    const settings = NotificationSettings(
      disabled: {NotificationKind.streak},
      streakWeekday: DateTime.friday,
      streakHour: 20,
      streakMinute: 30,
      quietNight: true,
    );
    NotificationSettingsStore(directory).save(settings);

    expect(NotificationSettingsStore(directory).load(), settings);
  });

  test('壊れたファイルや範囲外の値は、初期値として読む', () {
    final directory = createTempDirectory();
    final file = File(
      p.join(directory.path, NotificationSettingsStore.fileName),
    );
    file.writeAsStringSync('{broken');
    expect(
      NotificationSettingsStore(directory).load(),
      NotificationSettings.defaults,
    );

    file.writeAsStringSync(
      '{"disabled":["unknown","checkin"],"streakWeekday":9,"streakHour":25}',
    );
    final settings = NotificationSettingsStore(directory).load();
    expect(settings.disabled, {NotificationKind.checkin});
    expect(settings.streakWeekday, DateTime.sunday);
    expect(settings.streakHour, 18);
  });

  test('切り替えた設定はファイルに残り、作り直しても保たれる', () {
    final directory = createTempDirectory();
    ProviderContainer create() => ProviderContainer(
      overrides: [documentsDirectoryProvider.overrideWithValue(directory)],
    );
    final first = create();
    addTearDown(first.dispose);
    first
        .read(notificationSettingsProvider.notifier)
        .setEnabled(NotificationKind.checkin, false);

    final second = create();
    addTearDown(second.dispose);
    expect(
      second
          .read(notificationSettingsProvider)
          .isEnabled(NotificationKind.checkin),
      isFalse,
    );
    second
        .read(notificationSettingsProvider.notifier)
        .setEnabled(NotificationKind.checkin, true);
    expect(NotificationSettingsStore(directory).load().disabled, isEmpty);
  });
}
