import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';
import '../backup/backup_screen.dart';
import '../checkin/checkin_screen.dart';
import '../home/app_tab.dart';
import '../inkan/inkan_stamp.dart';
import '../map/map_screen.dart';
import '../record/record_screen.dart';
import '../records/clock.dart';
import '../records/record_repository.dart';
import '../scoring/scoring_providers.dart';
import '../share/share_screen.dart';
import '../wishes/wish_dialog.dart';
import '../wishes/wish_repository.dart';
import 'onboarding_flow.dart';
import 'onboarding_store.dart';

/// 初めて開いたときの案内。1枚ずつ説明し、ボタンで本物の画面（記録・共有・地図）を開く。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final OnboardingStore _store;
  late final DateTime Function() _clock;
  var _step = OnboardingStep.welcome;
  String? _visitId;
  var _noWishYet = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(onboardingStoreProvider);
    _clock = ref.read(clockProvider);
  }

  @override
  void dispose() {
    // どこで閉じても（途中で閉じても）、次からは起動時に出さない。修行の設定から見直せる。
    _store.markCompleted(_clock()).catchError((Object e) {
      debugPrint('Onboarding completion save failed: $e');
    });
    super.dispose();
  }

  void _advance(OnboardingEvent event) =>
      setState(() => _step = nextOnboardingStep(_step, event));

  Future<T?> _open<T>(Widget screen) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

  Future<void> _restoreBackup() async {
    setState(() => _busy = true);
    try {
      final summary = await pickAndRestoreBackup(context, ref);
      if (mounted && summary != null && summary.totalVisits > 0) {
        _advance(OnboardingEvent.backupRestored);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkIn() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shopName = await _open<String>(const CheckinScreen());
    if (shopName == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.checkinDone(shopName))));
    _advance(OnboardingEvent.checkedIn);
  }

  Future<void> _record() async {
    final repository = ref.read(recordRepositoryProvider);
    // 監視の値は遅れて届くことがあるので、記録と並びは保存先から直接読み直して比べる。
    final checkinBefore = await repository.watchActiveCheckin().first;
    final visitsBefore = {
      for (final entry in await repository.watchVisits().first) entry.visit.id,
    };
    if (!mounted) return;
    await _open<void>(const RecordScreen());
    final checkinAfter = await repository.watchActiveCheckin().first;
    final added = [
      for (final entry in await repository.watchVisits().first)
        if (!visitsBefore.contains(entry.visit.id)) entry.visit,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    if (added.isNotEmpty) {
      _visitId = added.first.id;
      _advance(OnboardingEvent.recorded);
    } else if (checkinAfter != null &&
        checkinAfter.checkedInAt != checkinBefore?.checkedInAt) {
      // 記録の画面から「いま並んでいる」で並び始めたとき。
      _advance(OnboardingEvent.checkedIn);
    }
  }

  Future<int> _wishCount() async =>
      (await ref.read(wishRepositoryProvider).watchWishes().first).length;

  Future<void> _wishOnMap() async {
    final before = await _wishCount();
    if (!mounted) return;
    await _open<void>(const MapScreen());
    final after = await _wishCount();
    if (!mounted) return;
    if (after > before) {
      _advance(OnboardingEvent.wished);
    } else {
      setState(() => _noWishYet = true);
    }
  }

  Future<void> _wishByName() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(wishRepositoryProvider);
    final text = await showWishDialog(context);
    if (text == null || !mounted) return;
    try {
      await repository.addWish(
        shop: ShopInput(name: text.name),
        trigger: text.trigger,
        note: text.note,
        hoursConditions: text.hoursConditions,
        now: _clock(),
      );
    } catch (e) {
      debugPrint('Wish save failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.wishSaveFailed)));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.wishAdded(text.name))));
    if (mounted) _advance(OnboardingEvent.wished);
  }

  void _finish({AppTab? tab}) {
    if (tab != null) ref.read(appTabProvider.notifier).select(tab);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skip = FudeLink(
      onPressed: () => _advance(OnboardingEvent.skipped),
      child: Text(l10n.onboardingLater),
    );
    final page = switch (_step) {
      OnboardingStep.welcome => _OnboardingPage(
        chapter: l10n.onboardingWelcomeChapter,
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
        actions: [
          AiFuda(
            expand: true,
            onPressed: _busy ? null : () => _advance(OnboardingEvent.skipped),
            child: Text(l10n.onboardingWelcomeRecord),
          ),
          SumiFuda(
            expand: true,
            onPressed: _busy ? null : _checkIn,
            child: Text(l10n.onboardingWelcomeQueue),
          ),
          SumiFuda(
            expand: true,
            onPressed: _busy ? null : _restoreBackup,
            child: Text(l10n.onboardingWelcomeBackup),
          ),
        ],
      ),
      OnboardingStep.record => _OnboardingPage(
        chapter: l10n.onboardingRecordChapter,
        title: l10n.onboardingRecordTitle,
        body: l10n.onboardingRecordBody,
        actions: [
          AiFuda(
            expand: true,
            onPressed: _record,
            child: Text(l10n.onboardingRecordButton),
          ),
          skip,
        ],
      ),
      OnboardingStep.share => _OnboardingPage(
        chapter: l10n.onboardingShareChapter,
        title: l10n.onboardingShareTitle,
        body: l10n.onboardingShareBody,
        hero: switch (ref.watch(scoredVisitByIdProvider)[_visitId]) {
          final scored? => InkanStamp(scored: scored, size: 132),
          null => null,
        },
        actions: [
          AiFuda(
            expand: true,
            onPressed: _visitId == null
                ? null
                : () => _open<void>(ShareScreen(visitId: _visitId!)),
            child: Text(l10n.onboardingShareButton),
          ),
          FudeLink(
            onPressed: () => _advance(OnboardingEvent.skipped),
            child: Text(l10n.onboardingNext),
          ),
        ],
      ),
      OnboardingStep.wish => _OnboardingPage(
        chapter: l10n.onboardingWishChapter,
        title: l10n.onboardingWishTitle,
        body: l10n.onboardingWishBody,
        note: _noWishYet ? l10n.onboardingWishNotYet : null,
        actions: [
          AiFuda(
            expand: true,
            onPressed: _wishOnMap,
            child: Text(l10n.onboardingWishMap),
          ),
          SumiFuda(
            expand: true,
            onPressed: _wishByName,
            child: Text(l10n.onboardingWishByName),
          ),
          skip,
        ],
      ),
      OnboardingStep.finish => _OnboardingPage(
        chapter: l10n.onboardingFinishChapter,
        title: l10n.onboardingFinishTitle,
        body: l10n.onboardingFinishBody,
        actions: [
          AiFuda(
            expand: true,
            onPressed: () => _finish(tab: AppTab.shugyo),
            child: Text(l10n.onboardingFinishShugyo),
          ),
          FudeLink(
            onPressed: () => _finish(tab: AppTab.records),
            child: Text(l10n.onboardingFinishRecords),
          ),
        ],
      ),
    };
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: AppBar(
        backgroundColor: Washi.paper,
        leading: IconButton(
          tooltip: l10n.onboardingClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
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
    );
  }
}

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
    required this.actions,
    this.note,
  });

  final String chapter;
  final String title;
  final String body;
  final Widget? hero;
  final List<Widget> actions;
  final String? note;

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
                  const SizedBox(height: 24),
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
                if (note case final note?) ...[
                  const SizedBox(height: 16),
                  Text(
                    note,
                    style: textTheme.bodyMedium?.copyWith(color: Washi.ai),
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 28),
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
