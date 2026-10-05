import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
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

/// 下のタブ（印帳・願掛け・修行・地図）で画面を切り替える、アプリの外枠。
/// タブの真ん中には、どの画面からでも記録を始められる大きな判子を置く。
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = ref.watch(appTabProvider).index;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          const HomeScreen(),
          const WishListScreen(),
          const ShugyoScreen(),
          // 地図は開いたときだけ作る。開くたびに現在地のまわりへ寄せ直し（わかるまでは全部のピン）、
          // 地図を見ていないときにタイルを取りに行かないようにするため。
          if (index == _mapIndex)
            const MapScreen()
          else
            const SizedBox.shrink(),
        ],
      ),
      floatingActionButton: Padding(
        // タブの上に半分ほどはみ出すように、少し下げる。
        padding: const EdgeInsets.only(top: 36),
        child: RecordSealButton(
          tooltip: l10n.addRecord,
          onPressed: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const RecordScreen())),
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
          for (final (glyph, label) in [
            (l10n.navGlyphRecords, l10n.navRecords),
            (l10n.navGlyphWishes, l10n.navWishes),
          ])
            NavigationDestination(
              icon: _TabSeal(glyph: glyph, selected: false),
              selectedIcon: _TabSeal(glyph: glyph, selected: true),
              label: label,
            ),
          const NavigationDestination(
            icon: SizedBox(width: RecordSealButton.size),
            label: '',
            enabled: false,
          ),
          for (final (glyph, label) in [
            (l10n.navGlyphShugyo, l10n.navShugyo),
            (l10n.navGlyphMap, l10n.navMap),
          ])
            NavigationDestination(
              icon: _TabSeal(glyph: glyph, selected: false),
              selectedIcon: _TabSeal(glyph: glyph, selected: true),
              label: label,
            ),
        ],
      ),
    );
  }
}

/// タブのアイコン。筆文字1字の印で、選んでいるときは藍で塗る。
class _TabSeal extends StatelessWidget {
  const _TabSeal({required this.glyph, required this.selected});

  final String glyph;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Washi.ai : Colors.transparent,
        border: Border.all(
          color: selected ? Washi.ai : Washi.inkSoft,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        glyph,
        style: TextStyle(
          fontFamily: Washi.brush,
          fontSize: 18,
          height: 1.1,
          color: selected ? Washi.page : Washi.inkSoft,
        ),
      ),
    );
  }
}
