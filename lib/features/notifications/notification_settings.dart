import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../records/photo_storage.dart';

/// 通知の種類。種類ごとに設定でオン・オフでき、Android では通知チャンネルも分ける。
/// 種類を足すときは、ここと文言（`notificationKind…`）とチャンネルの名前を足す。
enum NotificationKind {
  checkin('checkin'),
  rating('rating'),
  yearReview('year_review'),
  newYearWish('new_year_wish'),
  streak('streak'),
  monthly('monthly'),
  event('event');

  const NotificationKind(this.key);

  /// 保存と Android の通知チャンネルの ID に使う名前。変えると設定が引き継がれない。
  final String key;
}

@immutable
class NotificationSettings {
  const NotificationSettings({
    this.disabled = const {},
    this.streakWeekday = DateTime.sunday,
    this.streakHour = 18,
    this.streakMinute = 0,
    this.quietNight = false,
  });

  static const defaults = NotificationSettings();

  /// オフにした種類。新しく足した種類は、はじめはオンになる。
  final Set<NotificationKind> disabled;

  /// 連続記録の知らせを出す曜日（[DateTime.monday]〜[DateTime.sunday]）と時刻。
  final int streakWeekday;
  final int streakHour;
  final int streakMinute;

  /// 夜（22時〜8時）は知らせない。
  final bool quietNight;

  bool isEnabled(NotificationKind kind) => !disabled.contains(kind);

  NotificationSettings copyWith({
    Set<NotificationKind>? disabled,
    int? streakWeekday,
    int? streakHour,
    int? streakMinute,
    bool? quietNight,
  }) => NotificationSettings(
    disabled: disabled ?? this.disabled,
    streakWeekday: streakWeekday ?? this.streakWeekday,
    streakHour: streakHour ?? this.streakHour,
    streakMinute: streakMinute ?? this.streakMinute,
    quietNight: quietNight ?? this.quietNight,
  );

  NotificationSettings withEnabled(NotificationKind kind, bool enabled) =>
      copyWith(
        disabled: enabled
            ? (Set.of(disabled)..remove(kind))
            : (Set.of(disabled)..add(kind)),
      );

  Map<String, dynamic> toJson() => {
    'disabled': [for (final kind in disabled) kind.key],
    'streakWeekday': streakWeekday,
    'streakHour': streakHour,
    'streakMinute': streakMinute,
    'quietNight': quietNight,
  };

  /// 読めない値は初期値にする（壊れたファイルで通知が止まらないように）。
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    int read(String key, int min, int max, int fallback) {
      final value = json[key];
      return value is int && value >= min && value <= max ? value : fallback;
    }

    final disabled = json['disabled'];
    return NotificationSettings(
      disabled: {
        if (disabled is List)
          for (final kind in NotificationKind.values)
            if (disabled.contains(kind.key)) kind,
      },
      streakWeekday: read('streakWeekday', 1, 7, defaults.streakWeekday),
      streakHour: read('streakHour', 0, 23, defaults.streakHour),
      streakMinute: read('streakMinute', 0, 59, defaults.streakMinute),
      quietNight: json['quietNight'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      setEquals(other.disabled, disabled) &&
      other.streakWeekday == streakWeekday &&
      other.streakHour == streakHour &&
      other.streakMinute == streakMinute &&
      other.quietNight == quietNight;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(disabled),
    streakWeekday,
    streakHour,
    streakMinute,
    quietNight,
  );
}

final notificationSettingsStoreProvider = Provider<NotificationSettingsStore>(
  (ref) => NotificationSettingsStore(ref.watch(documentsDirectoryProvider)),
);

/// 通知の設定を、documents の `notification_settings.json` に残す。
/// 小さなファイルなので同期で読み書きし、起動直後から設定どおりに予約できるようにする。
class NotificationSettingsStore {
  NotificationSettingsStore(this._documents);

  static const fileName = 'notification_settings.json';

  final Directory _documents;

  File get _file => File(p.join(_documents.path, fileName));

  NotificationSettings load() {
    try {
      final json = jsonDecode(_file.readAsStringSync());
      if (json is Map<String, dynamic>) {
        return NotificationSettings.fromJson(json);
      }
    } on FileSystemException {
      // まだ保存していない。
    } on FormatException {
      // 壊れたファイルは初期値で上書きされるまで無視する。
    }
    return NotificationSettings.defaults;
  }

  void save(NotificationSettings settings) {
    try {
      _file.writeAsStringSync(jsonEncode(settings.toJson()));
    } on FileSystemException catch (e) {
      debugPrint('Notification settings save failed: $e');
    }
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsController, NotificationSettings>(
      NotificationSettingsController.new,
    );

class NotificationSettingsController extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() =>
      ref.watch(notificationSettingsStoreProvider).load();

  void update(NotificationSettings settings) {
    if (settings == state) return;
    ref.read(notificationSettingsStoreProvider).save(settings);
    state = settings;
  }

  void setEnabled(NotificationKind kind, bool enabled) =>
      update(state.withEnabled(kind, enabled));
}
