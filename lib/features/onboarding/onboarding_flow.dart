/// 初めて開いたときの案内の段階。最初の一杯を記録して、願を掛け、拠点を決めるまで。
enum OnboardingStep { welcome, record, share, wish, homeBase, finish }

/// 案内の中で起きたこと。
enum OnboardingEvent {
  /// バックアップから記録を読み込んだ。
  backupRestored,

  /// 並び始めた。
  checkedIn,

  /// 1杯記録した。
  recorded,

  /// 願を掛けた。
  wished,

  /// 拠点を決めた。
  homeBaseSet,

  /// その段階を飛ばした（「あとで」「次へ」）。
  skipped,
}

/// 記録が無ければ、記録・共有の段階に進む。バックアップや並びから始めた人は、記録を飛ばして願掛けへ。
OnboardingStep nextOnboardingStep(OnboardingStep step, OnboardingEvent event) {
  return switch ((step, event)) {
    (_, OnboardingEvent.backupRestored) => OnboardingStep.wish,
    (_, OnboardingEvent.checkedIn) => OnboardingStep.wish,
    (OnboardingStep.welcome, OnboardingEvent.skipped) => OnboardingStep.record,
    (OnboardingStep.record, OnboardingEvent.recorded) => OnboardingStep.share,
    (OnboardingStep.record || OnboardingStep.share, OnboardingEvent.skipped) =>
      OnboardingStep.wish,
    (OnboardingStep.wish, OnboardingEvent.wished || OnboardingEvent.skipped) =>
      OnboardingStep.homeBase,
    (
      OnboardingStep.homeBase,
      OnboardingEvent.homeBaseSet || OnboardingEvent.skipped,
    ) =>
      OnboardingStep.finish,
    _ => step,
  };
}

/// 記録が1杯も無く、まだ案内を終えていない人にだけ、起動したときに案内を出す。
bool shouldShowOnboarding({required bool completed, required int visitCount}) =>
    !completed && visitCount == 0;
