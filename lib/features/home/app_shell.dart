import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../checkin/checkin_banner.dart';
import '../checkin/checkin_controller.dart';
import '../checkin/checkin_screen.dart';
import '../records/clock.dart';
import '../map/map_screen.dart';
import '../shugyo/shugyo_screen.dart';
import '../wishes/wish_list_screen.dart';
import '../../theme/washi_buttons.dart';
import '../record/record_screen.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/onboarding_store.dart';
import '../records/record_repository.dart';
import 'app_tab.dart';
import 'home_screen.dart';
import 'start_sheet.dart';
import 'tab_seals.dart';

/// 下のタブ（印帳・願掛け・修行・地図）で画面を切り替える、アプリの外枠。
/// タブの真ん中には、どの画面からでも記録を始められる大きな判子を置く。
/// ふだんは「麺」（記録するか並ぶかを選ぶ）、並んでいる最中は「着」（着丼した時刻を残して記録へ）。
/// 並んでいる最中は、どのタブでも上に並びの帯を出す。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static final _mapIndex = AppTab.map.index;

  /// 下のタブで、真ん中の判子のために空けておく位置。
  static const _gap = 2;

  @override
  void initState() {
    super.initState();
    if (ref.read(showOnboardingOnLaunchProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
    }
  }

  Future<void> _maybeOnboard() async {
    try {
      final completed = await ref.read(onboardingStoreProvider).isCompleted();
      final visits = await ref.read(visitsProvider.future);
      if (!mounted ||
          !shouldShowOnboarding(
            completed: completed,
            visitCount: visits.length,
          )) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const OnboardingScreen(),
        ),
      );
    } catch (e) {
      debugPrint('Onboarding check failed: $e');
    }
  }

  Future<void> _onSeal() async {
    final navigator = Navigator.of(context);
    if (ref.read(activeCheckinProvider).value != null) {
      // 押した瞬間が待ち時間の終わり。写真はこのあと撮っても撮らなくてもよい。
      final arrivedAt = ref.read(clockProvider)();
      await navigator.push<void>(
        MaterialPageRoute(builder: (_) => RecordScreen(arrivedAt: arrivedAt)),
      );
      return;
    }
    final choice = await showStartSheet(context);
    if (!mounted) return;
    switch (choice) {
      case StartChoice.eaten:
        await navigator.push<void>(
          MaterialPageRoute(builder: (_) => const RecordScreen()),
        );
      case StartChoice.queue:
        await _startQueue();
      case null:
        break;
    }
  }

  Future<void> _startQueue() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shopName = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const CheckinScreen()));
    if (shopName == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.checkinDone(shopName))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = ref.watch(appTabProvider).index;
    final checkin = ref.watch(activeCheckinProvider).value;
    final tabs = IndexedStack(
      index: index,
      children: [
        const HomeScreen(),
        const WishListScreen(),
        const ShugyoScreen(),
        // 地図は開いたときだけ作る。開くたびに現在地のまわりへ寄せ直し（わかるまでは全部のピン）、
        // 地図を見ていないときにタイルを取りに行かないようにするため。
        if (index == _mapIndex) const MapScreen() else const SizedBox.shrink(),
      ],
    );
    return Scaffold(
      // 並び始め・終わりでタブの画面が作り直されないよう、形は変えずに帯だけを出し入れする。
      body: Column(
        children: [
          if (checkin != null)
            SafeArea(bottom: false, child: CheckinBanner(checkin: checkin)),
          // 帯が端末の上の帯（時刻など）の分を取ったので、タブの画面では空けない。
          Expanded(
            key: const ValueKey('tabs'),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: checkin != null,
              child: tabs,
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        // タブの上に半分ほどはみ出すように、少し下げる。
        padding: const EdgeInsets.only(top: 36),
        child: RecordSealButton(
          glyph: checkin == null ? '麺' : '着',
          tooltip: checkin == null ? l10n.addRecord : l10n.arriveSeal,
          onPressed: _onSeal,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        // 真ん中は判子の場所として空けておく（押しても何もしない）。
        selectedIndex: index < _gap ? index : index + 1,
        onDestinationSelected: (selected) {
          if (selected == _gap) return;
          ref
              .read(appTabProvider.notifier)
              .select(AppTab.values[selected < _gap ? selected : selected - 1]);
        },
        destinations: [
          for (final (tab, label) in [
            (AppTab.records, l10n.navRecords),
            (AppTab.wishes, l10n.navWishes),
          ])
            NavigationDestination(
              icon: TabSeal(tab: tab, selected: false),
              selectedIcon: TabSeal(tab: tab, selected: true),
              label: label,
            ),
          NavigationDestination(
            icon: const SizedBox(width: RecordSealButton.size),
            label: checkin == null ? '' : l10n.arriveSealLabel,
            enabled: false,
          ),
          for (final (tab, label) in [
            (AppTab.shugyo, l10n.navShugyo),
            (AppTab.map, l10n.navMap),
          ])
            NavigationDestination(
              icon: TabSeal(tab: tab, selected: false),
              selectedIcon: TabSeal(tab: tab, selected: true),
              label: label,
            ),
        ],
      ),
    );
  }
}
