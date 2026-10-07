/// 初めて開いたときの案内の段階。案内の中で完結し、最後に選んだ始め方の画面へ移る。
enum OnboardingStep { welcome, homeBase, start }

/// 最後の段階で選ぶ始め方。選ぶと案内を終える。
enum OnboardingStart { record, checkin, backup, browse }

/// 入門を読んだら拠点へ、拠点を決めた（あとにした）ら始め方へ。
OnboardingStep nextOnboardingStep(OnboardingStep step) => switch (step) {
  OnboardingStep.welcome => OnboardingStep.homeBase,
  OnboardingStep.homeBase || OnboardingStep.start => OnboardingStep.start,
};

/// 記録が1杯も無く、まだ案内を終えていない人にだけ、起動したときに案内を出す。
bool shouldShowOnboarding({required bool completed, required int visitCount}) =>
    !completed && visitCount == 0;
