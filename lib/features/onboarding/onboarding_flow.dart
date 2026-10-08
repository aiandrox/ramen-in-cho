/// 初めて開いたときの案内の段階。案内の中で完結し、最後に選んだ始め方の画面へ移る。
enum OnboardingStep { welcome, start }

/// 最後の段階で選ぶ始め方。選ぶと案内を終える。
enum OnboardingStart { record, checkin, backup, browse }

/// 入門を読んだら始め方へ。
OnboardingStep nextOnboardingStep(OnboardingStep step) => OnboardingStep.start;

/// 残した段階の名前を読む。前にあった拠点の段（`homeBase`）は、其の一を読み終えたところなので始め方として続ける。
OnboardingStep? onboardingStepNamed(Object? name) => name == 'homeBase'
    ? OnboardingStep.start
    : OnboardingStep.values.where((s) => s.name == name).firstOrNull;

/// 記録が1杯も無く、まだ案内を終えていない人にだけ、起動したときに案内を出す。
bool shouldShowOnboarding({required bool completed, required int visitCount}) =>
    !completed && visitCount == 0;
