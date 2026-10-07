import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_flow.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_screen.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_store.dart';
import 'package:ramen_in_cho/features/records/clock.dart';
import 'package:ramen_in_cho/features/records/record_repository.dart';
import 'package:ramen_in_cho/features/shop_search/geo.dart';
import 'package:ramen_in_cho/features/shop_search/location_service.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';
import '../../support/l10n.dart';

void main() {
  test('入門 → 拠点 → 始め方。始め方から先へは進まない', () {
    expect(nextOnboardingStep(OnboardingStep.welcome), OnboardingStep.homeBase);
    expect(nextOnboardingStep(OnboardingStep.homeBase), OnboardingStep.start);
    expect(nextOnboardingStep(OnboardingStep.start), OnboardingStep.start);
  });

  test('記録が無く、案内を終えていないときだけ起動時に出す', () {
    expect(shouldShowOnboarding(completed: false, visitCount: 0), isTrue);
    expect(shouldShowOnboarding(completed: true, visitCount: 0), isFalse);
    expect(shouldShowOnboarding(completed: false, visitCount: 1), isFalse);
  });

  group('OnboardingStore', () {
    test('途中の段階を残し、次に開いたときにそこから続ける', () async {
      final store = OnboardingStore(createTempDirectory());
      expect(await store.load(), (
        completed: false,
        step: OnboardingStep.welcome,
      ));
      await store.saveStep(OnboardingStep.homeBase);
      expect(await store.load(), (
        completed: false,
        step: OnboardingStep.homeBase,
      ));
    });

    test('終えたら起動時に出さず、見直しの段階は残さない', () async {
      final store = OnboardingStore(createTempDirectory());
      await store.saveStep(OnboardingStep.start);
      await store.markCompleted(DateTime(2026, 10, 4));
      expect((await store.load()).completed, isTrue);
      await store.saveStep(OnboardingStep.homeBase);
      expect(await store.load(), (
        completed: true,
        step: OnboardingStep.welcome,
      ));
    });

    test('段階を残している途中で閉じても、終えた印が消えない', () async {
      final store = OnboardingStore(createTempDirectory());
      final saving = store.saveStep(OnboardingStep.start);
      final completing = store.markCompleted(DateTime(2026, 10, 4));
      await Future.wait([saving, completing]);
      expect((await store.load()).completed, isTrue);
    });

    test('壊れた中身は初めからにする', () async {
      final directory = createTempDirectory();
      File('${directory.path}/${OnboardingStore.fileName}')
          .writeAsStringSync('[');
      expect((await OnboardingStore(directory).load()).completed, isFalse);
    });
  });

  group('OnboardingScreen', () {
    const sapporo = GeoPoint(43.0687, 141.3508);
    final now = DateTime(2026, 10, 6, 12);
    late AppDatabase database;
    late FakeLocationService location;
    late _MemoryOnboardingStore store;
    Object? result;
    var closed = false;

    Future<void> pumpOnboarding(
      WidgetTester tester, {
      OnboardingStep initialStep = OnboardingStep.welcome,
      List<HomeBaseSetting> homeBases = const [],
    }) async {
      database = createTestDatabase();
      store = _MemoryOnboardingStore();
      closed = false;
      result = null;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            visitsProvider.overrideWithValue(const AsyncData([])),
            homeBaseSettingsProvider.overrideWithValue(AsyncData(homeBases)),
            locationServiceProvider.overrideWithValue(location),
            onboardingStoreProvider.overrideWithValue(store),
            clockProvider.overrideWithValue(() => now),
          ],
          child: localizedApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<OnboardingStart>(
                    MaterialPageRoute(
                      builder: (_) =>
                          OnboardingScreen(initialStep: initialStep),
                    ),
                  );
                  closed = true;
                },
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    setUp(() => location = FakeLocationService(position: sapporo));

    testWidgets('其の一で印・修行点・願掛けを説明し、外の画面へは移らない', (tester) async {
      await pumpOnboarding(tester);
      expect(find.text(ja.onboardingWelcomeChapter), findsOneWidget);
      expect(find.text(ja.onboardingWelcomeSealTitle), findsOneWidget);
      expect(find.text(ja.onboardingWelcomePointsTitle), findsOneWidget);
      expect(find.text(ja.onboardingWelcomeWishTitle), findsOneWidget);

      await tapText(tester, ja.onboardingNext);
      expect(find.text(ja.onboardingHomeBaseChapter), findsOneWidget);
      expect(store.steps, [OnboardingStep.homeBase]);
      expect(location.requests, isEmpty);
    });

    testWidgets('拠点をあとにして、始め方を選ぶと終える', (tester) async {
      await pumpOnboarding(tester, initialStep: OnboardingStep.homeBase);
      await tapText(tester, ja.onboardingHomeBaseLater);
      expect(find.text(ja.onboardingStartChapter), findsOneWidget);
      expect(store.steps, [OnboardingStep.start]);

      await tapText(tester, ja.onboardingStartRecord);
      expect(closed, isTrue);
      expect(result, OnboardingStart.record);
      expect(store.completed, isTrue);
    });

    testWidgets('現在地を拠点にすると、許可を求めて「このあたり」で決め、始め方へ進む', (tester) async {
      await pumpOnboarding(tester, initialStep: OnboardingStep.homeBase);
      await tapText(tester, ja.onboardingHomeBaseHere);
      expect(location.requests, [true]);
      expect(find.text(ja.homeBaseHidenGained), findsOneWidget);
      // 秘伝を知らせている間にアプリを閉じても、次は始め方から続ける。
      expect(store.steps, [OnboardingStep.start]);
      final settings = await HomeBaseRepository(database).allSettings();
      expect(settings.single.name, ja.homeBaseNameDefault);
      expect(settings.single.latitude, sapporo.latitude);

      await tapText(tester, ja.homeBaseHidenOk);
      expect(find.text(ja.onboardingStartChapter), findsOneWidget);
      expect(closed, isFalse);
    });

    testWidgets('拠点がもう決まっていれば、現在地で上書きせずに先へ進めるだけにする', (tester) async {
      await pumpOnboarding(
        tester,
        initialStep: OnboardingStep.homeBase,
        homeBases: [buildHomeBase(name: '札幌市', setAt: DateTime(2026))],
      );
      expect(find.text(ja.homeBaseLine('札幌市')), findsOneWidget);
      expect(find.text(ja.onboardingHomeBaseHere), findsNothing);

      await tapText(tester, ja.onboardingNext);
      expect(find.text(ja.onboardingStartChapter), findsOneWidget);
      expect(location.requests, isEmpty);
    });

    testWidgets('現在地がわからなければ、その段にとどまる', (tester) async {
      location = FakeLocationService();
      await pumpOnboarding(tester, initialStep: OnboardingStep.homeBase);
      await tapText(tester, ja.onboardingHomeBaseHere);
      expect(find.text(ja.homeBaseHereFailed), findsOneWidget);
      expect(find.text(ja.onboardingHomeBaseChapter), findsOneWidget);
    });

    testWidgets('「また今度」で閉じると、次からは出さない', (tester) async {
      await pumpOnboarding(tester);
      await tapText(tester, ja.onboardingLater);
      expect(closed, isTrue);
      expect(result, isNull);
      expect(store.completed, isTrue);
    });
  });
}

class _MemoryOnboardingStore extends OnboardingStore {
  _MemoryOnboardingStore() : super(Directory.systemTemp);

  final steps = <OnboardingStep>[];
  var completed = false;

  @override
  Future<OnboardingProgress> load() async =>
      (completed: completed, step: steps.lastOrNull ?? OnboardingStep.welcome);

  @override
  Future<void> saveStep(OnboardingStep step) async => steps.add(step);

  @override
  Future<void> markCompleted(DateTime now) async => completed = true;
}
