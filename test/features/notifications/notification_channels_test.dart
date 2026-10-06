import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/features/notifications/notification_calendar.dart';
import 'package:ramen_in_cho/features/notifications/notification_channels.dart';
import 'package:ramen_in_cho/features/notifications/notification_plan.dart';
import 'package:ramen_in_cho/features/notifications/notification_scheduler.dart';
import 'package:ramen_in_cho/features/notifications/notification_service.dart';
import 'package:ramen_in_cho/features/notifications/notification_settings.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/photo_storage.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/wishes/wish_repository.dart';

import '../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2026-10-29 は木曜。先週（10/20）に食べていて、今週はまだ。
  final now = DateTime(2026, 10, 29, 12);
  final halloween = DateTime(2026, 10, 31);
  final shop = Shop(id: 'shop', name: '麺屋', createdAt: DateTime(2026));
  final visits = [
    VisitWithShop(
      shop: shop,
      visit: Visit(
        id: 'v',
        shopId: shop.id,
        result: VisitResult.eaten,
        eatenAt: DateTime(2026, 10, 20, 12),
        rating: 3,
        isLimited: false,
        memo: '',
        createdAt: DateTime(2026, 10, 20, 12),
      ),
    ),
  ];

  late FakeNotificationService notifications;
  setUp(() => notifications = FakeNotificationService());

  /// 連続記録を土曜18時（ハロウィンの知らせと同じ日）に知らせる設定で作る。
  ProviderContainer create({
    required bool android,
    NotificationSettings settings = const NotificationSettings(
      streakWeekday: DateTime.saturday,
    ),
  }) {
    final directory = createTempDirectory();
    NotificationSettingsStore(directory).save(settings);
    final container = ProviderContainer(
      overrides: [
        usesSystemNotificationCategoriesProvider.overrideWithValue(android),
        notificationServiceProvider.overrideWithValue(notifications),
        documentsDirectoryProvider.overrideWithValue(directory),
        visitsProvider.overrideWithValue(AsyncData(visits)),
        wishesProvider.overrideWithValue(const AsyncData([])),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<List<PlannedNotification>> onHalloween(
    ProviderContainer container,
  ) async {
    await container.read(blockedNotificationKindsProvider.future);
    return [
      for (final plan in container.read(notificationPlanProvider)!)
        if (DateUtils.isSameDay(plan.at, halloween)) plan,
    ];
  }

  test('Android: 止められた種類が分かるまでは予約しない', () {
    final container = create(android: true);
    expect(container.read(notificationPlanProvider), isNull);
  });

  test('Android: スマホの設定で止めた種類は予約せず、1日の枠をほかの種類に譲る', () async {
    expect(await onHalloween(create(android: true)), [
      StreakNotice(DateTime(2026, 10, 31, 18), weeks: 1),
    ]);

    notifications.blocked = {NotificationKind.streak};
    expect(await onHalloween(create(android: true)), [
      EventNotice(DateTime(2026, 10, 31, 18), event: RamenEvent.halloween),
    ]);
  });

  test('Android: アプリに戻ってきて読み直すと、予約もやり直す', () async {
    final container = create(android: true);
    expect(await onHalloween(container), [isA<StreakNotice>()]);

    notifications.blocked = {NotificationKind.streak};
    await container.read(blockedNotificationKindsProvider.notifier).refresh();
    expect(await onHalloween(container), [isA<EventNotice>()]);
  });

  test('Android: アプリに残っていた種類ごとのオフは使わない（スマホの設定に任せる）', () async {
    final container = create(
      android: true,
      settings: const NotificationSettings(
        disabled: {NotificationKind.streak},
        streakWeekday: DateTime.saturday,
      ),
    );
    expect(await onHalloween(container), [isA<StreakNotice>()]);
  });

  test('iOS: アプリの設定でオフにした種類を予約しない', () async {
    notifications.blocked = {NotificationKind.seasonal};
    final container = create(
      android: false,
      settings: const NotificationSettings(
        disabled: {NotificationKind.streak},
        streakWeekday: DateTime.saturday,
      ),
    );
    expect(await onHalloween(container), [isA<EventNotice>()]);
  });
}
