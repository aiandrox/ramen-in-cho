import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';
import '../home_base/home_base_repository.dart';
import '../records/date_format.dart';
import '../records/labels.dart';
import '../scoring/rank_labels.dart';
import '../scoring/scoring_providers.dart';
import '../shop_search/geo.dart';
import '../shop_search/location_service.dart';
import '../shop_search/nearby_shop_finder.dart';
import '../shop_search/overpass.dart';
import '../visit_detail/visit_detail_screen.dart';
import '../../theme/washi.dart';
import '../records/models.dart';
import '../records/record_repository.dart';
import '../wishes/wish_dialog.dart';
import '../wishes/wish_providers.dart';
import '../wishes/wishes.dart';
import 'home_base_line.dart';
import 'journey.dart';
import 'map_camera.dart';
import 'washi_map.dart';
import '../shop_search/yahoo_local.dart';
import 'shop_pins.dart';
import '../../theme/washi_buttons.dart';
import '../../theme/washi_sheet.dart';

/// 「このあたりを探す」で探す半径。記録のときの候補（300m）より広く、歩いて行ける範囲。
const nearbySearchRadiusMeters = 1000;

/// 行った店が無く、現在地もわからないときに最初に見せる場所（東京駅）。
const _fallbackCenter = LatLng(35.6812, 139.7671);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _controller = MapController();
  GeoPoint? _here;
  List<FoundShop> _nearby = const [];
  bool _isSearching = false;

  /// 現在地を確かめている回数。開いたときと「現在地」ボタンで重なることがあるため数える。
  int _locating = 0;
  bool _showJourney = false;

  /// 指で地図を動かしたか。動かしたあとに現在地がわかっても、地図を寄せない。
  bool _userMoved = false;

  /// 旅路を見せる年。nullならすべての年。
  int? _journeyYear;

  /// 旅路を再生しているときの、灯っている店の数。再生していなければnull。
  int? _replayCount;
  Timer? _replayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate(move: false));
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _locate({required bool move}) async {
    setState(() => _locating++);
    final GeoPoint? here;
    try {
      here = await ref
          .read(locationServiceProvider)
          .currentPosition(requestPermission: true);
    } finally {
      if (mounted) setState(() => _locating--);
    }
    if (!mounted) return;
    if (here == null) {
      if (move) _showMessage(AppLocalizations.of(context).mapNoLocation);
      return;
    }
    setState(() => _here = here);
    if (move ||
        shouldCenterOnArrivedLocation(
          userMoved: _userMoved,
          showingJourney: _showJourney,
        )) {
      _controller.move(LatLng(here.latitude, here.longitude), neighborhoodZoom);
    }
  }

  Future<void> _searchHere() async {
    final l10n = AppLocalizations.of(context);
    final center = _controller.camera.center;
    setState(() => _isSearching = true);
    try {
      final found = await ref
          .read(nearbyShopFinderProvider)
          .searchNearby(
            GeoPoint(center.latitude, center.longitude),
            radiusMeters: nearbySearchRadiusMeters,
            // 店内で急ぐ記録と違い待てる場面なので、混んでいるサーバーにも長めに待つ。
            timeout: const Duration(seconds: 25),
          );
      if (!mounted) return;
      // 位置のわからない手入力の店や、撤退しただけの店も「行った店」として除く。
      final visited = {
        for (final entry in ref.read(scoredVisitsProvider))
          entry.shop.id: entry.shop,
      };
      final nearby = unvisitedShops(
        found: found,
        eatenShops: visited.values.toList(),
      );
      setState(() => _nearby = nearby);
      _showMessage(
        nearby.isEmpty
            ? l10n.mapNearbyNone
            : l10n.mapNearbyFound(nearby.length),
      );
    } catch (e) {
      debugPrint('Nearby search failed: $e');
      if (mounted) _showMessage(l10n.mapSearchFailed);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _toggleJourney(List<JourneyStop> stops) {
    _stopReplay();
    setState(() => _showJourney = !_showJourney);
    // 地図は現在地のまわりから始まるので、旅路を開いたら道のり全体が入る範囲に合わせる。
    if (_showJourney) _fitTo(stops);
  }

  void _stopReplay() {
    _replayTimer?.cancel();
    _replayTimer = null;
    _replayCount = null;
  }

  /// 1杯目から順に、店を1つずつ灯していく。
  void _replay(List<JourneyStop> stops) {
    _stopReplay();
    if (stops.isEmpty) return;
    _fitTo(stops);
    setState(() => _replayCount = 1);
    _replayTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) return timer.cancel();
      final next = (_replayCount ?? 0) + 1;
      if (next > stops.length) {
        timer.cancel();
        setState(_stopReplay);
        return;
      }
      setState(() => _replayCount = next);
    });
  }

  void _fitTo(List<JourneyStop> stops) {
    if (stops.isEmpty) return;
    if (stops.length == 1) {
      final only = stops.single.location;
      _controller.move(LatLng(only.latitude, only.longitude), 15);
      return;
    }
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          for (final stop in stops)
            LatLng(stop.location.latitude, stop.location.longitude),
        ],
        padding: const EdgeInsets.fromLTRB(48, 160, 48, 120),
        maxZoom: 16,
      ),
    );
  }

  void _showExpeditions(List<Expedition> list) {
    final l10n = AppLocalizations.of(context);
    showWashiSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              l10n.journeyExpeditionsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const HomeBaseLine(),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l10n.journeyExpeditionsNone),
              ),
            for (final expedition in list)
              ListTile(
                leading: const Icon(Icons.flag),
                title: Text(
                  l10n.journeyExpeditionName(
                    expedition.day.month,
                    expedition.day.day,
                    expedition.stops.first.shop.name,
                  ),
                ),
                subtitle: Text(
                  expedition.stops.map((s) => s.shop.name).join('・'),
                ),
                onTap: () {
                  closeWashiSheet<void>(context);
                  _fitTo(expedition.stops);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allPins = shopPins(ref.watch(scoredVisitsProvider));
    final pendingWishes = [
      for (final status in ref.watch(wishStatusesProvider))
        if (!status.isFulfilled &&
            wishLocation(status.wish) != null &&
            // 行ったことのある店に掛けた（再訪の）願は、その店のピンで見せる。
            !allPins.any((pin) => wishMatchesShop(status.wish, pin.shop)))
          status.wish,
    ];
    final scored = ref.watch(scoredVisitsProvider);
    final allStops = journeyStops(scored);
    final years = {for (final stop in allStops) stop.eatenAt.year}.toList()
      ..sort((a, b) => b.compareTo(a));
    final stops = _journeyYear == null
        ? allStops
        : [
            for (final stop in allStops)
              if (stop.eatenAt.year == _journeyYear) stop,
          ];
    final shownStops = _replayCount == null
        ? stops
        : stops.take(_replayCount!).toList();
    // 再生中は、灯った店のピンだけを出す。
    final pins = _replayCount == null
        ? allPins
        : [
            for (final pin in allPins)
              if (shownStops.any((stop) => stop.shop.id == pin.shop.id)) pin,
          ];
    final base = ref.watch(currentHomeBaseProvider);
    final tilesEnabled = ref.watch(mapTilesEnabledProvider);
    final here = _here;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: [
          IconButton(
            tooltip: l10n.journeyToggle,
            isSelected: _showJourney,
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            onPressed: () => _toggleJourney(stops),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _fallbackCenter,
              initialZoom: 13,
              initialCameraFit: pins.isEmpty
                  ? null
                  : CameraFit.coordinates(
                      coordinates: [
                        for (final pin in pins)
                          LatLng(pin.latitude, pin.longitude),
                      ],
                      padding: const EdgeInsets.all(48),
                      maxZoom: 16,
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
              if (_showJourney && shownStops.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        for (final stop in shownStops)
                          LatLng(
                            stop.location.latitude,
                            stop.location.longitude,
                          ),
                      ],
                      color: Washi.ai.withValues(alpha: 0.8),
                      strokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final shop in _nearby)
                    if (!pendingWishes.any(
                      (wish) => wishMatchesPlace(
                        wish,
                        osmId: shop.osmId,
                        name: shop.name,
                        location: shop.location,
                      ),
                    ))
                      Marker(
                        point: LatLng(
                          shop.location.latitude,
                          shop.location.longitude,
                        ),
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: _UnvisitedPin(shop: shop, here: here),
                      ),
                  for (final wish in pendingWishes)
                    Marker(
                      point: LatLng(wish.latitude!, wish.longitude!),
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: _WishPin(wish: wish),
                    ),
                  if (base != null && _replayCount == null)
                    Marker(
                      point: LatLng(base.latitude, base.longitude),
                      width: 24,
                      height: 24,
                      child: HomeBaseMapPin(base: base),
                    ),
                  for (final pin in pins)
                    Marker(
                      point: LatLng(pin.latitude, pin.longitude),
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: _Pin(pin: pin),
                    ),
                  if (here != null)
                    Marker(
                      point: LatLng(here.latitude, here.longitude),
                      width: 22,
                      height: 22,
                      child: const MapHereDot(),
                    ),
                ],
              ),
            ],
          ),
          // 出典は必要なものだけを小さく出す（部品名は出さない）。
          // 下のタブの真ん中の判子に隠れないよう、判子がはみ出す分だけ上げる。
          const Positioned(
            left: 0,
            bottom: RecordSealButton.overhang + 4,
            child: MapAttribution(),
          ),
          if (_nearby.isNotEmpty)
            Positioned(
              left: 8,
              top: 8,
              right: 8,
              child: ColoredBox(
                color: const Color(0xCCFFFFFF),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(
                    [
                      l10n.openPoiAttribution,
                      if (isYahooEnabled) l10n.yahooAttribution,
                    ].join('\n'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          if (_showJourney)
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: _JourneyPanel(
                years: years,
                year: _journeyYear,
                stops: stops,
                isReplaying: _replayCount != null,
                onYear: (year) {
                  setState(() {
                    _stopReplay();
                    _journeyYear = year;
                  });
                  _fitTo([
                    for (final stop in allStops)
                      if (year == null || stop.eatenAt.year == year) stop,
                  ]);
                },
                onReplay: () => _replayCount == null
                    ? _replay(stops)
                    : setState(_stopReplay),
                onExpeditions: () =>
                    _showExpeditions(expeditions(scored, year: _journeyYear)),
              ),
            ),
          if (_isSearching || _locating > 0) ...[
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),
            Align(
              child: _LoadingBadge(
                message: _isSearching ? l10n.mapSearching : l10n.mapLocating,
              ),
            ),
          ],
          if (!_showJourney &&
              pins.isEmpty &&
              _nearby.isEmpty &&
              pendingWishes.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l10n.mapEmpty),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SealFab(
              sumi: true,
              small: true,
              tooltip: l10n.mapMyLocation,
              onPressed: () => _locate(move: true),
              child: const Icon(Icons.my_location),
            ),
            const SizedBox(height: 12),
            SealFab(
              tooltip: l10n.mapSearchHere,
              onPressed: _isSearching ? null : _searchHere,
              child: _isSearching
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Washi.page,
                      ),
                    )
                  : const Icon(Icons.search),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnvisitedPin extends ConsumerWidget {
  const _UnvisitedPin({required this.shop, required this.here});

  final FoundShop shop;
  final GeoPoint? here;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final here = this.here;
    return GestureDetector(
      onTap: () => showWashiSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(l10n.mapUnvisited),
                if (here != null)
                  Text(
                    l10n.mapDistanceFromHere(
                      distanceMeters(here, shop.location).round(),
                    ),
                  ),
                if (shop.suggestedConditions case final conditions?)
                  Text(
                    switch (shop.suggestedConditionsSource) {
                      ConditionsDraftSource.curatedShops =>
                        l10n.mapCuratedConditions,
                      _ => l10n.mapOpeningHoursConditions,
                    }(hoursConditionsLabel(l10n, conditions)),
                  ),
                const SizedBox(height: 16),
                AiFuda(
                  icon: const Icon(Icons.bookmark_add),
                  child: Text(l10n.wishMakeButton),
                  onPressed: () {
                    closeWashiSheet<void>(context);
                    addWishFor(
                      context,
                      ref,
                      ShopInput(
                        osmId: shop.osmId,
                        name: shop.name,
                        latitude: shop.location.latitude,
                        longitude: shop.location.longitude,
                        dataSource: shop.dataSource,
                      ),
                      suggestedConditions: shop.suggestedConditions,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      child: Semantics(
        button: true,
        label: shop.name,
        child: const MapSealPin(color: Washi.faded, filled: true),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.pin});

  final ShopPin pin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rank = pin.rank;
    return GestureDetector(
      onTap: () => showWashiSheet<void>(
        context: context,
        builder: (_) => _PinDetails(pin: pin),
      ),
      child: Semantics(
        button: true,
        label: pin.shop.name,
        // 丸い印の頭に格の字を入れ、細い足の先を店の場所にする（字が場所に重ならないように）。
        // 行った店は朱で塗った印に、店ランク（易・厳・難・極）の字を入れる。
        child: MapSealPin(
          color: rank == null ? Washi.faded : Washi.shu,
          filled: true,
          label: rank == null ? null : shopRankLabel(l10n, rank),
        ),
      ),
    );
  }
}

class _PinDetails extends StatelessWidget {
  const _PinDetails({required this.pin});

  final ShopPin pin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final rank = pin.rank;
    final details = [
      if (pin.eatenCount > 0) l10n.mapShopBowls(pin.eatenCount),
      if (pin.retreatCount > 0) l10n.mapShopRetreats(pin.retreatCount),
      if (rank != null) l10n.mapShopRank(shopRankLabel(l10n, rank)),
    ];
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pin.shop.name, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(details.join('・'), style: textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              l10n.mapLastVisit(formatDate(pin.lastVisitAt)),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SumiFuda(
                icon: const Icon(Icons.menu_book_outlined),
                child: Text(l10n.mapOpenShopPage),
                onPressed: () {
                  final navigator = Navigator.of(context);
                  closeWashiSheet<void>(context);
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          VisitDetailScreen(visitId: pin.lastVisitId),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 願を掛けた（まだ行っていない）店。輪郭だけの朱のピンに「願」の字。
class _WishPin extends StatelessWidget {
  const _WishPin({required this.wish});

  final Wish wish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => showWashiSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wish.name, style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(l10n.mapWished),
                if (wish.note.isNotEmpty) Text(wish.note),
                if (wish.trigger.isNotEmpty)
                  Text(l10n.wishTriggerLine(wish.trigger)),
              ],
            ),
          ),
        ),
      ),
      child: Semantics(
        button: true,
        label: l10n.mapWishedLabel(wish.name),
        child: MapSealPin(
          color: Washi.shu,
          filled: false,
          label: l10n.wishSealChar,
        ),
      ),
    );
  }
}

class _JourneyPanel extends StatelessWidget {
  const _JourneyPanel({
    required this.years,
    required this.year,
    required this.stops,
    required this.isReplaying,
    required this.onYear,
    required this.onReplay,
    required this.onExpeditions,
  });

  final List<int> years;
  final int? year;
  final List<JourneyStop> stops;
  final bool isReplaying;
  final ValueChanged<int?> onYear;
  final VoidCallback onReplay;
  final VoidCallback onExpeditions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final shops = {for (final stop in stops) stop.shop.id}.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(l10n.journeyAllYears),
                    selected: year == null,
                    onSelected: (_) => onYear(null),
                  ),
                  for (final y in years) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(l10n.journeyYear(y)),
                      selected: year == y,
                      onSelected: (_) => onYear(y),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stops.isEmpty
                  ? l10n.journeyEmpty
                  : l10n.journeySummary(
                      shops,
                      journeyKilometers(stops).toStringAsFixed(1),
                    ),
              style: textTheme.bodyMedium,
            ),
            Row(
              children: [
                FudeLink(
                  onPressed: stops.isEmpty ? null : onReplay,
                  icon: Icon(isReplaying ? Icons.stop : Icons.play_arrow),
                  child: Text(
                    isReplaying ? l10n.journeyStop : l10n.journeyReplay,
                  ),
                ),
                FudeLink(
                  onPressed: stops.isEmpty ? null : onExpeditions,
                  icon: const Icon(Icons.flag_outlined),
                  child: Text(l10n.journeyExpeditions),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 地図の真ん中に出す「探しています」の札。地図の操作は止めない。
class _LoadingBadge extends StatelessWidget {
  const _LoadingBadge({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        child: Card(
          elevation: 3,
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
