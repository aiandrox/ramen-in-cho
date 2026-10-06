import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/motion.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';
import '../../theme/washi_sheet.dart';
import '../map/shop_pins.dart';
import '../map/washi_map.dart';
import '../quests/quest_seal.dart';
import '../quests/quests.dart';
import '../records/clock.dart';
import '../records/date_format.dart';
import '../records/models.dart';
import '../scoring/scoring_providers.dart';
import '../shop_search/geo.dart';
import '../shop_search/location_service.dart';
import 'home_base.dart';
import 'home_base_repository.dart';

/// 拠点を選ぶときの地図の倍率。駅や街のあたりが見分けられる広さ。
const homeBasePickZoom = 13.0;

/// 拠点を決める画面。地図を動かして真ん中の「拠」の場所にするか、現在地にする。決めたら true を返して閉じる。
/// [editing]を渡すと、その拠点の場所を直す画面になる。
/// 場所はどこにも送らない（地図の画像を取るときに表示範囲が伝わるだけ）。
class HomeBasePickerScreen extends ConsumerStatefulWidget {
  const HomeBasePickerScreen({super.key, this.editing});

  final HomeBaseSetting? editing;

  @override
  ConsumerState<HomeBasePickerScreen> createState() =>
      _HomeBasePickerScreenState();
}

class _HomeBasePickerScreenState extends ConsumerState<HomeBasePickerScreen> {
  final _controller = MapController();
  var _saving = false;
  var _locating = false;
  var _userMoved = false;
  GeoPoint? _here;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHere());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 開いたときは許可を聞かない。拠点がまだ無く、地図を動かしていなければ現在地へ寄せる。
  Future<void> _loadHere() async {
    final location = ref.read(locationServiceProvider);
    if (!await location.isReady()) return;
    final here = await location.currentPosition(requestPermission: false);
    if (!mounted || here == null) return;
    setState(() => _here = here);
    if (widget.editing == null &&
        ref.read(currentHomeBaseProvider) == null &&
        !_userMoved) {
      _controller.move(LatLng(here.latitude, here.longitude), homeBasePickZoom);
    }
  }

  Future<GeoPoint?> _locate() async {
    setState(() => _locating = true);
    try {
      return await ref
          .read(locationServiceProvider)
          .currentPosition(requestPermission: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _moveToHere() async {
    final l10n = AppLocalizations.of(context);
    final here = await _locate();
    if (!mounted) return;
    if (here == null) {
      _showMessage(l10n.homeBaseHereFailed);
      return;
    }
    setState(() => _here = here);
    _controller.move(LatLng(here.latitude, here.longitude), homeBasePickZoom);
  }

  /// 地図が出ないとき（電波が無いなど）でも、現在地なら決められるようにする。
  Future<void> _useHere() async {
    final l10n = AppLocalizations.of(context);
    final here = await _locate();
    if (!mounted) return;
    if (here == null) {
      _showMessage(l10n.homeBaseHereFailed);
      return;
    }
    await _choose(here);
  }

  Future<void> _useCenter() {
    final center = _controller.camera.center;
    final location = GeoPoint(center.latitude, center.longitude);
    return switch (widget.editing) {
      final editing? => _relocate(editing, location),
      null => _choose(location),
    };
  }

  Future<void> _relocate(HomeBaseSetting editing, GeoPoint location) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(homeBaseRepositoryProvider)
          .updateHomeBase(
            editing.copyWith(
              latitude: location.latitude,
              longitude: location.longitude,
            ),
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeBaseRelocated(editing.name))),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Home base relocate failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.homeBaseSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _choose(GeoPoint location) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (name == null || !mounted) return;
    await _save(name, location);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(String name, GeoPoint location) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(homeBaseRepositoryProvider);
    setState(() => _saving = true);
    try {
      final isFirst = (await repository.allSettings()).isEmpty;
      final setting = await repository.setHomeBase(
        name: name,
        latitude: location.latitude,
        longitude: location.longitude,
        now: ref.read(clockProvider)(),
      );
      if (!mounted) return;
      if (isFirst) await showHomeBaseHidenDialog(context, setting.setAt);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeBaseSaved(setting.name))),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Home base save failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.homeBaseSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final history = ref.watch(homeBaseSettingsProvider).value ?? const [];
    final editing = widget.editing;
    final current = editing ?? ref.watch(currentHomeBaseProvider);
    final pins = shopPins(ref.watch(scoredVisitsProvider));
    final tilesEnabled = ref.watch(mapTilesEnabledProvider);
    final here = _here;
    final busy = _saving || _locating;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeBaseTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: current == null
                        ? mapJapanCenter
                        : LatLng(current.latitude, current.longitude),
                    initialZoom: current == null
                        ? mapJapanZoom
                        : homeBasePickZoom,
                    initialCameraFit: current != null || pins.isEmpty
                        ? null
                        : CameraFit.coordinates(
                            coordinates: [
                              for (final pin in pins)
                                LatLng(pin.latitude, pin.longitude),
                            ],
                            padding: const EdgeInsets.all(48),
                            maxZoom: homeBasePickZoom,
                          ),
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture) _userMoved = true;
                    },
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    if (tilesEnabled) const WashiTileLayer(),
                    // 行った店を目印に選べるよう、地図のタブと同じ印を出す（ここでは押せない）。
                    IgnorePointer(
                      child: MarkerLayer(
                        markers: [
                          if (current != null)
                            Marker(
                              point: LatLng(
                                current.latitude,
                                current.longitude,
                              ),
                              width: 24,
                              height: 24,
                              child: HomeBaseMapPin(base: current),
                            ),
                          ...visitedShopMarkers(l10n, pins),
                          if (here != null)
                            Marker(
                              point: LatLng(here.latitude, here.longitude),
                              width: 22,
                              height: 22,
                              child: const MapHereDot(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const IgnorePointer(child: Center(child: _CenterSeal())),
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        editing == null
                            ? l10n.homeBaseIntro
                            : l10n.homeBaseRelocateIntro(editing.name),
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
                const Positioned(left: 0, bottom: 0, child: MapAttribution()),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: SealFab(
                    sumi: true,
                    small: true,
                    tooltip: l10n.mapMyLocation,
                    onPressed: busy ? null : _moveToHere,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                if (_locating)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(switch ((editing, current)) {
                    (final editing?, _) => l10n.homeBaseRelocateLine(
                      editing.name,
                    ),
                    (null, final current?) => l10n.homeBaseLine(current.name),
                    (null, null) => l10n.homeBaseNotSet,
                  }, style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  AiFuda(
                    expand: true,
                    onPressed: busy ? null : _useCenter,
                    child: Text(
                      editing == null
                          ? l10n.homeBaseUseCenter
                          : l10n.homeBaseRelocateHere,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (editing == null)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        FudeLink(
                          icon: const Icon(Icons.my_location),
                          onPressed: busy ? null : _useHere,
                          child: Text(l10n.homeBaseUseHere),
                        ),
                        if (history.isNotEmpty)
                          FudeLink(
                            icon: const Icon(Icons.history),
                            onPressed: () => showWashiSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => const _HistorySheet(),
                            ),
                            child: Text(l10n.homeBaseHistoryTitle),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 地図の真ん中に重ねる「拠」の印。この印の下の場所が拠点になる。
class _CenterSeal extends StatelessWidget {
  const _CenterSeal();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.homeBaseCenterLabel,
      child: SizedBox.square(
        dimension: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 72, height: 1.5, color: Washi.ink),
            Container(width: 1.5, height: 72, color: Washi.ink),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Washi.page.withValues(alpha: 0.9),
                border: Border.all(color: Washi.ink, width: 2),
              ),
              child: Text(
                l10n.homeBaseSealChar,
                style: const TextStyle(
                  fontFamily: Washi.brush,
                  fontSize: 19,
                  height: 1,
                  color: Washi.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// これまでの拠点（新しい順）。タップで日付・呼び名・場所を直したり消したりする。
class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = homeBasesNewestFirst(
      ref.watch(homeBaseSettingsProvider).value ?? const [],
    );
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(
            l10n.homeBaseHistoryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final setting in history)
            ListTile(
              key: ValueKey(setting.id),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(setting.name),
              subtitle: Text(
                l10n.homeBaseHistoryFrom(formatDate(setting.setAt)),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => showWashiSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _EditSheet(setting: setting),
              ),
            ),
        ],
      ),
    );
  }
}

/// これまでの拠点の1件を直す・消す。
class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.setting});

  final HomeBaseSetting setting;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late var _setting = widget.setting;

  Future<void> _update(HomeBaseSetting updated) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref
          .read(homeBaseRepositoryProvider)
          .updateHomeBase(updated);
      if (mounted) setState(() => _setting = saved);
    } catch (e) {
      debugPrint('Home base update failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.homeBaseSaveFailed)));
    }
  }

  Future<void> _pickDate() async {
    final today = homeBaseDayStart(ref.read(clockProvider)());
    final current = homeBaseDayStart(_setting.setAt);
    final day = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (day == null || !mounted) return;
    await _update(_setting.copyWith(setAt: homeBaseDayStart(day)));
  }

  Future<void> _rename() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: _setting.name),
    );
    if (name == null || !mounted) return;
    await _update(_setting.copyWith(name: name));
  }

  Future<void> _relocate() async {
    final moved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HomeBasePickerScreen(editing: _setting),
      ),
    );
    if (moved == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final setting = _setting;
    final all =
        ref.read(homeBaseSettingsProvider).value ?? const <HomeBaseSetting>[];
    final others = [
      for (final other in all)
        if (other.id != setting.id) other,
    ];
    final previous = homeBaseAt(others, setting.setAt);
    final date = formatDate(setting.setAt);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.homeBaseDeleteConfirm(setting.name)),
        content: Text(switch (previous) {
          final previous? => l10n.homeBaseDeleteToPrevious(date, previous.name),
          null when others.isEmpty => l10n.homeBaseDeleteLast,
          null => l10n.homeBaseDeleteToNone(date),
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          KeshiFuda(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(homeBaseRepositoryProvider).deleteHomeBase(setting.id);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeBaseDeleted(setting.name))),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Home base delete failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.homeBaseSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setting = _setting;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(
            l10n.homeBaseEditTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.homeBaseEditDate),
            subtitle: Text(l10n.homeBaseHistoryFrom(formatDate(setting.setAt))),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.homeBaseEditName),
            subtitle: Text(setting.name),
            onTap: _rename,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.map_outlined),
            title: Text(l10n.homeBaseEditPlace),
            subtitle: Text(l10n.homeBaseEditPlaceHint),
            onTap: _relocate,
          ),
          const SizedBox(height: 16),
          KeshiFuda(
            expand: true,
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            child: Text(l10n.homeBaseDelete),
          ),
        ],
      ),
    );
  }
}

/// 初めて拠点を決めたときに、秘伝「拠点を構える」の会得を知らせる。
Future<void> showHomeBaseHidenDialog(BuildContext context, DateTime setAt) {
  final l10n = AppLocalizations.of(context);
  final quest = quests.firstWhere((q) => q.byHomeBase);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 秘伝の印がにじむように現れ、少しおくれて文が出る。
          InkBleed(
            delay: const Duration(milliseconds: 120),
            child: QuestSeal(
              quest: quest,
              level: 1,
              size: 112,
              achievedAt: setAt,
            ),
          ),
          const SizedBox(height: 16),
          RiseIn(
            delay: const Duration(milliseconds: 360),
            child: Text(
              l10n.homeBaseHidenGained,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.homeBaseHidenOk),
        ),
      ],
    ),
  );
}

/// 拠点の呼び名を聞く。閉じる動きの間も入力欄が残るので、入力の中身は窓と一緒に片付ける。
class _NameDialog extends StatefulWidget {
  const _NameDialog({this.initial});

  /// 直すときの今の呼び名。無ければ「このあたり」。
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  // 初めの呼び名は全体を選んでおき、打てばそのまま置き換わるようにする。
  late final _controller = () {
    final text =
        widget.initial ?? AppLocalizations.of(context).homeBaseNameDefault;
    return TextEditingController.fromValue(
      TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
    );
  }();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.homeBaseNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        decoration: InputDecoration(
          helperText: l10n.homeBaseNameHint,
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            final name = _controller.text.trim();
            Navigator.of(context)
                .pop(name.isEmpty ? l10n.homeBaseNameDefault : name);
          },
          child: Text(l10n.homeBaseDecide),
        ),
      ],
    );
  }
}
