import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';
import '../backup/backup_screen.dart';
import '../checkin/checkin_screen.dart';
import '../error_reporting/error_reporting.dart';
import '../home/app_tab.dart';
import '../home_base/home_base_picker_screen.dart';
import '../home_base/home_base_repository.dart';
import '../inkan/inkan_stamp.dart';
import '../record/record_screen.dart';
import '../records/clock.dart';
import '../records/models.dart';
import '../scoring/points.dart';
import '../shop_search/location_service.dart';
import 'onboarding_flow.dart';
import 'onboarding_store.dart';

/// 案内を開き、最後に選んだ始め方の画面へ移る。案内の上に積んだ画面（設定など）は閉じて、印帳から始める。
Future<void> showOnboarding(
  BuildContext context,
  WidgetRef ref, {
  OnboardingStep initialStep = OnboardingStep.welcome,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final tabs = ref.read(appTabProvider.notifier);
  final start = await navigator.push<OnboardingStart>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => OnboardingScreen(initialStep: initialStep),
    ),
  );
  if (start == null || start == OnboardingStart.browse) return;
  navigator.popUntil((route) => route.isFirst);
  tabs.select(AppTab.records);
  switch (start) {
    case OnboardingStart.record:
      await navigator.push<void>(
        MaterialPageRoute(builder: (_) => const RecordScreen()),
      );
    case OnboardingStart.checkin:
      final shopName = await navigator.push<String>(
        MaterialPageRoute(builder: (_) => const CheckinScreen()),
      );
      if (shopName != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.checkinDone(shopName))),
        );
      }
    case OnboardingStart.backup:
      await navigator.push<void>(
        MaterialPageRoute(builder: (_) => const BackupScreen()),
      );
    case OnboardingStart.browse:
      return;
  }
}

/// 初めて開いたときの案内。三つの段階をこの画面の中で進め、最後の始め方を選ぶと[OnboardingStart]を返して閉じる。
/// 外の画面へ移るのは「地図で選ぶ」（拠点を決めて戻ってくる）だけ。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    this.initialStep = OnboardingStep.welcome,
  });

  /// 途中でアプリを閉じた人は、その段階から続ける。
  final OnboardingStep initialStep;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final OnboardingStore _store;
  late final DateTime Function() _clock;
  late final ScoredVisit _sample;
  late var _step = widget.initialStep;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(onboardingStoreProvider);
    _clock = ref.read(clockProvider);
    _sample = _sampleSeal(_clock());
  }

  @override
  void dispose() {
    // 閉じたら（×・「また今度」・始め方を選ぶ）、次からは起動時に出さない。設定から見直せる。
    // アプリごと閉じたときはここを通らないので、次に開いたときに残した段階から続く。
    _store.markCompleted(_clock()).catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'Onboarding completion save failed');
    });
    super.dispose();
  }

  void _advance() {
    final next = nextOnboardingStep(_step);
    setState(() => _step = next);
    _store.saveStep(next).catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'Onboarding step save failed');
    });
  }

  void _close([OnboardingStart? start]) => Navigator.of(context).pop(start);

  Future<void> _useHere() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final here = await ref
          .read(locationServiceProvider)
          .currentPosition(requestPermission: true);
      if (!mounted) return;
      if (here == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.homeBaseHereFailed)),
        );
        return;
      }
      await saveHomeBase(
        context,
        ref,
        name: l10n.homeBaseNameDefault,
        location: here,
        onSaved: () {
          if (!mounted) return;
          setState(() => _busy = false);
          _advance();
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickOnMap() async {
    final chosen = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const HomeBasePickerScreen()),
    );
    if (chosen == true && mounted) _advance();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = switch (_step) {
      OnboardingStep.welcome => _OnboardingPage(
        chapter: l10n.onboardingWelcomeChapter,
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
        hero: InkanStamp(scored: _sample, size: 120),
        points: [
          (l10n.onboardingWelcomeSealTitle, l10n.onboardingWelcomeSealBody),
          (l10n.onboardingWelcomePointsTitle, l10n.onboardingWelcomePointsBody),
          (l10n.onboardingWelcomeWishTitle, l10n.onboardingWelcomeWishBody),
        ],
        actions: [
          AiFuda(
            expand: true,
            onPressed: _advance,
            child: Text(l10n.onboardingNext),
          ),
          FudeLink(onPressed: _close, child: Text(l10n.onboardingLater)),
        ],
      ),
      OnboardingStep.homeBase => switch (ref.watch(currentHomeBaseProvider)) {
        // 設定から見直している人の拠点を、呼び名「このあたり」の現在地で黙って上書きしないよう、決めてあれば先へ進めるだけにする。
        final base? => _OnboardingPage(
          chapter: l10n.onboardingHomeBaseChapter,
          title: l10n.onboardingHomeBaseTitle,
          body: l10n.onboardingHomeBaseBody,
          note: l10n.homeBaseLine(base.name),
          actions: [
            AiFuda(
              expand: true,
              onPressed: _advance,
              child: Text(l10n.onboardingNext),
            ),
          ],
        ),
        null => _OnboardingPage(
          chapter: l10n.onboardingHomeBaseChapter,
          title: l10n.onboardingHomeBaseTitle,
          body: l10n.onboardingHomeBaseBody,
          busy: _busy,
          actions: [
            AiFuda(
              expand: true,
              icon: const Icon(Icons.my_location),
              onPressed: _busy ? null : _useHere,
              child: Text(l10n.onboardingHomeBaseHere),
            ),
            SumiFuda(
              expand: true,
              icon: const Icon(Icons.map_outlined),
              onPressed: _busy ? null : _pickOnMap,
              child: Text(l10n.onboardingHomeBaseMap),
            ),
            FudeLink(
              onPressed: _busy ? null : _advance,
              child: Text(l10n.onboardingHomeBaseLater),
            ),
          ],
        ),
      },
      OnboardingStep.start => _OnboardingPage(
        chapter: l10n.onboardingStartChapter,
        title: l10n.onboardingStartTitle,
        body: l10n.onboardingStartBody,
        actions: [
          AiFuda(
            expand: true,
            onPressed: () => _close(OnboardingStart.record),
            child: Text(l10n.onboardingStartRecord),
          ),
          SumiFuda(
            expand: true,
            onPressed: () => _close(OnboardingStart.checkin),
            child: Text(l10n.onboardingStartQueue),
          ),
          SumiFuda(
            expand: true,
            onPressed: () => _close(OnboardingStart.backup),
            child: Text(l10n.onboardingStartBackup),
          ),
          FudeLink(
            onPressed: () => _close(OnboardingStart.browse),
            child: Text(l10n.onboardingStartBrowse),
          ),
        ],
      ),
    };
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Washi.paper,
        appBar: AppBar(
          backgroundColor: Washi.paper,
          leading: IconButton(
            tooltip: l10n.onboardingClose,
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : _close,
          ),
          centerTitle: true,
          title: Text(
            l10n.onboardingScroll,
            style: const TextStyle(
              fontFamily: Washi.brush,
              fontSize: 18,
              color: Washi.inkSoft,
              letterSpacing: 4,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _StepMarks(current: _step.index),
            ),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(key: ValueKey(_step), child: page),
          ),
        ),
      ),
    );
  }
}

/// 其の一で見せる見本の印（醤油の一杯、初めての店で少し並んだくらい）。
ScoredVisit _sampleSeal(DateTime now) => ScoredVisit(
  visit: Visit(
    id: 'onboarding-sample',
    shopId: 'onboarding-sample',
    result: VisitResult.eaten,
    eatenAt: now,
    style: RamenStyle.shoyu,
    isLimited: false,
    memo: '',
    createdAt: now,
  ),
  shop: Shop(id: 'onboarding-sample', name: '', createdAt: now),
  points: const PointsBreakdown(
    base: 10,
    waitBonus: 15,
    limitedBonus: 0,
    firstVisitBonus: 10,
    retryBonus: 0,
  ),
  isFirstVisit: true,
  isRetrySuccess: false,
);

/// 心得の進み具合。済んだ段は藍の小さな角印、いまの段は藍の枠、先の段は薄墨の枠。
class _StepMarks extends StatelessWidget {
  const _StepMarks({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < OnboardingStep.values.length; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(left: 5),
            decoration: BoxDecoration(
              color: i < current ? Washi.ai : null,
              border: Border.all(
                color: i <= current ? Washi.ai : Washi.line,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.chapter,
    required this.title,
    required this.body,
    this.hero,
    this.points = const [],
    required this.actions,
    this.note,
    this.busy = false,
  });

  final String chapter;
  final String title;
  final String body;
  final Widget? hero;

  /// 見出しと短い説明の組。
  final List<(String, String)> points;
  final List<Widget> actions;
  final String? note;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  chapter,
                  style: const TextStyle(
                    fontFamily: Washi.brush,
                    fontSize: 16,
                    color: Washi.ai,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: Washi.brush,
                    fontSize: 32,
                    height: 1.3,
                    color: Washi.ink,
                  ),
                ),
                const SizedBox(height: 12),
                const _BrushRule(),
                if (hero case final hero?) ...[
                  const SizedBox(height: 20),
                  Center(child: hero),
                ],
                const SizedBox(height: 18),
                Text(
                  body,
                  style: textTheme.bodyLarge?.copyWith(
                    height: 1.9,
                    color: Washi.ink,
                  ),
                ),
                for (final (heading, text) in points) ...[
                  const SizedBox(height: 16),
                  Text(
                    heading,
                    style: const TextStyle(
                      fontFamily: Washi.brush,
                      fontSize: 18,
                      color: Washi.ai,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.8,
                      color: Washi.ink,
                    ),
                  ),
                ],
                if (note case final note?) ...[
                  const SizedBox(height: 16),
                  Text(
                    note,
                    style: textTheme.bodyMedium?.copyWith(color: Washi.ai),
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 28),
                if (busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                for (final (i, action) in actions.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 題の下に引く、藍の短い筆の線（入りが太く、抜けが細い）。
class _BrushRule extends StatelessWidget {
  const _BrushRule();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: CustomPaint(size: const Size(64, 6), painter: _BrushRulePainter()),
    );
  }
}

class _BrushRulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.7, 0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Washi.ai);
  }

  @override
  bool shouldRepaint(_BrushRulePainter oldDelegate) => false;
}
