import 'package:flutter_test/flutter_test.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_flow.dart';
import 'package:ramen_in_cho/features/onboarding/onboarding_store.dart';

import '../../support/fakes.dart';

void main() {
  group('nextOnboardingStep', () {
    OnboardingStep next(OnboardingStep step, OnboardingEvent event) =>
        nextOnboardingStep(step, event);

    test('写真から始めると、記録 → 共有 → 願掛け → 拠点 → 終わり', () {
      var step = next(OnboardingStep.welcome, OnboardingEvent.skipped);
      expect(step, OnboardingStep.record);
      step = next(step, OnboardingEvent.recorded);
      expect(step, OnboardingStep.share);
      step = next(step, OnboardingEvent.skipped);
      expect(step, OnboardingStep.wish);
      step = next(step, OnboardingEvent.wished);
      expect(step, OnboardingStep.homeBase);
      step = next(step, OnboardingEvent.homeBaseSet);
      expect(step, OnboardingStep.finish);
    });

    test('バックアップを読み込んだり並び始めたりしたら、記録を飛ばして願掛けへ', () {
      expect(
        next(OnboardingStep.welcome, OnboardingEvent.backupRestored),
        OnboardingStep.wish,
      );
      expect(
        next(OnboardingStep.welcome, OnboardingEvent.checkedIn),
        OnboardingStep.wish,
      );
      expect(
        next(OnboardingStep.record, OnboardingEvent.checkedIn),
        OnboardingStep.wish,
      );
    });

    test('「あとで」で次の段階へ。記録を飛ばすと共有も飛ばす', () {
      expect(
        next(OnboardingStep.record, OnboardingEvent.skipped),
        OnboardingStep.wish,
      );
      expect(
        next(OnboardingStep.wish, OnboardingEvent.skipped),
        OnboardingStep.homeBase,
      );
      expect(
        next(OnboardingStep.homeBase, OnboardingEvent.skipped),
        OnboardingStep.finish,
      );
    });

    test('関係の無いことが起きても段階は変わらない', () {
      expect(
        next(OnboardingStep.wish, OnboardingEvent.recorded),
        OnboardingStep.wish,
      );
      expect(
        next(OnboardingStep.homeBase, OnboardingEvent.wished),
        OnboardingStep.homeBase,
      );
      expect(
        next(OnboardingStep.finish, OnboardingEvent.skipped),
        OnboardingStep.finish,
      );
    });
  });

  test('記録が無く、案内を終えていないときだけ起動時に出す', () {
    expect(shouldShowOnboarding(completed: false, visitCount: 0), isTrue);
    expect(shouldShowOnboarding(completed: true, visitCount: 0), isFalse);
    expect(shouldShowOnboarding(completed: false, visitCount: 1), isFalse);
  });

  test('案内を終えたことを保存し、読み直せる', () async {
    final store = OnboardingStore(createTempDirectory());
    expect(await store.isCompleted(), isFalse);
    await store.markCompleted(DateTime(2026, 10, 4));
    expect(await store.isCompleted(), isTrue);
  });
}
