import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';
import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';
import '../analytics/analytics_user_properties.dart';
import '../checkin/checkin_banner.dart';
import '../checkin/checkin_controller.dart';
import '../checkin/checkin_screen.dart';
import '../checkin/retreat_screen.dart';
import '../words/words.dart';
import '../records/clock.dart';
import '../map/map_screen.dart';
import '../notifications/notification_plan.dart';
import '../notifications/notification_service.dart';
import '../review/year_review_list_screen.dart';
import '../visit_detail/visit_detail_screen.dart';
import '../shugyo/shugyo_screen.dart';
import '../wishes/wish_list_screen.dart';
import '../../theme/washi_buttons.dart';
import '../../theme/washi_sheet.dart';
import '../record/record_screen.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/onboarding_store.dart';
import '../records/record_repository.dart';
import '../shop_search/location_service.dart';
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

  final _sheetHost = GlobalKey<ShellSheetHostState>();
  late final StreamSubscription<LocationBlock> _locationBlocks;
  late final StreamSubscription<String> _notificationTaps;

  /// 同じ案内を何度も出さないよう、アプリを開いている間は1つの理由につき1回だけにする。
  final _shownLocationBlocks = <LocationBlock>{};

  @override
  void initState() {
    super.initState();
    _locationBlocks = locationBlocks.stream.listen(_explainLocationBlock);
    final analytics = ref.read(analyticsProvider);
    ref.listenManual(appTabProvider, (previous, tab) {
      // 別の画面からタブを切り替えたときも、前のタブで開いていた窓を残さない。
      if (previous != null) _sheetHost.currentState?.close();
      unawaited(analytics.logScreen(tab.name));
    }, fireImmediately: true);
    ref.listenManual(analyticsUserPropertiesProvider, (previous, next) {
      if (next != null && !mapEquals(previous, next)) {
        unawaited(analytics.setUserProperties(next));
      }
    }, fireImmediately: true);
    final notifications = ref.read(notificationServiceProvider);
    _notificationTaps = notifications.taps.listen(_openFromNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final payload = await notifications.takeLaunchPayload();
      if (payload != null) _openFromNotification(payload);
    });
    if (ref.read(showOnboardingOnLaunchProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
    }
  }

  @override
  void dispose() {
    _notificationTaps.cancel();
    _locationBlocks.cancel();
    super.dispose();
  }

  Future<void> _explainLocationBlock(LocationBlock block) async {
    if (!mounted || !_shownLocationBlocks.add(block)) return;
    unawaited(
      ref
          .read(analyticsProvider)
          .log(AnalyticsEvents.locationBlockedShown(snake(block.name))),
    );
    final l10n = AppLocalizations.of(context);
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.locationBlockedTitle),
        content: Text(
          block == LocationBlock.serviceOff
              ? l10n.locationServiceOffBody
              : l10n.locationDeniedForeverBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.locationOpenSettings),
          ),
        ],
      ),
    );
    if (open != true) return;
    await (block == LocationBlock.serviceOff
        ? Geolocator.openLocationSettings()
        : Geolocator.openAppSettings());
  }

  /// 通知をタップしたときに、その行き先（1杯・年の振り返り・願掛けタブ）を開く。
  Future<void> _openFromNotification(String payload) async {
    final route = NotificationRoute.parse(payload);
    if (route == null || !mounted) return;
    // 書きかけの記録などを消さないよう、開いている画面は閉じずにその上へ開く。
    final navigator = Navigator.of(context);
    _sheetHost.currentState?.close();
    final tabs = ref.read(appTabProvider.notifier);
    switch (route) {
      case WishesRoute():
        tabs.select(AppTab.wishes);
      case YearReviewRoute(:final year):
        tabs.select(AppTab.shugyo);
        openYearReview(context, year: year);
      case VisitRoute(:final visitId):
        final visits = await ref.read(visitsProvider.future);
        if (!mounted || !visits.any((entry) => entry.visit.id == visitId)) {
          return;
        }
        tabs.select(AppTab.records);
        await navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => VisitDetailScreen(visitId: visitId),
          ),
        );
    }
  }

  Future<void> _maybeOnboard() async {
    try {
      final progress = await ref.read(onboardingStoreProvider).load();
      final visits = await ref.read(visitsProvider.future);
      if (!mounted ||
          !shouldShowOnboarding(
            completed: progress.completed,
            visitCount: visits.length,
          )) {
        return;
      }
      await showOnboarding(context, ref, initialStep: progress.step);
    } catch (e) {
      debugPrint('Onboarding check failed: $e');
    }
  }

  Future<void> _onSeal() async {
    final navigator = Navigator.of(context);
    if (ref.read(activeCheckinProvider).value != null) {
      _sheetHost.currentState?.close();
      // 押した瞬間が待ち時間の終わり。写真はこのあと撮っても撮らなくてもよい。
      final arrivedAt = ref.read(clockProvider)();
      await navigator.push<void>(
        MaterialPageRoute(builder: (_) => RecordScreen(arrivedAt: arrivedAt)),
      );
      return;
    }
    final host = _sheetHost.currentState;
    if (host?.openTag == startSheetTag) {
      host!.close();
      return;
    }
    host?.close();
    final choice = await showStartSheet(context, host: host);
    if (!mounted) return;
    switch (choice) {
      case StartChoice.eaten:
        await navigator.push<void>(
          MaterialPageRoute(builder: (_) => const RecordScreen()),
        );
      case StartChoice.queue:
        await _startQueue();
      case StartChoice.retreat:
        await _startRetreat();
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

  Future<void> _startRetreat() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push<RetreatSaved>(
      MaterialPageRoute(builder: (_) => const RetreatScreen()),
    );
    if (saved == null || !mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${l10n.retreatSaved}\n${retreatConsolation(saved.memo, saved.visit.id)}',
        ),
      ),
    );
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
      // 窓（願を掛けるなど）でキーボードが出ても、後ろの下のタブと判子を持ち上げない。
      resizeToAvoidBottomInset: false,
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
              // 下から出る窓は、ここ（見出しと下のタブの間）に出す。
              child: ShellSheetHost(
                key: _sheetHost,
                footerOverlap: RecordSealButton.overhang + 8,
                child: tabs,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        // タブの上に半分ほどはみ出すように、少し下げる。
        padding: const EdgeInsets.only(top: RecordSealButton.drop),
        child: RecordSealButton(
          glyph: checkin == null ? '麺' : '着',
          tooltip: checkin == null ? l10n.addRecord : l10n.arriveSeal,
          onPressed: _onSeal,
        ),
      ),
      floatingActionButtonLocation: const _SealLocation(),
      bottomNavigationBar: NavigationBar(
        // 真ん中は判子の場所として空けておく（押しても何もしない）。
        selectedIndex: index < _gap ? index : index + 1,
        onDestinationSelected: (selected) {
          _sheetHost.currentState?.close();
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

/// 下のタブの真ん中に判子を据える。通知（SnackBar）が出ても判子を持ち上げず、通知のほうを判子の上に出す。
class _SealLocation extends StandardFabLocation with FabCenterOffsetX {
  const _SealLocation();

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) =>
      scaffoldGeometry.contentBottom -
      scaffoldGeometry.floatingActionButtonSize.height / 2;
}
