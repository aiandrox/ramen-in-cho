import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../credits/source_credit.dart';
import '../../l10n/app_localizations.dart';
import '../home_base/home_base_repository.dart';
import '../records/date_format.dart';
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
import '../settings/settings_action.dart';
import 'home_base_line.dart';
import 'journey.dart';
import 'map_camera.dart';
import 'map_places.dart';
import 'pin_clusters.dart';
import 'washi_map.dart';
import 'shop_pins.dart';
import '../../theme/washi_buttons.dart';
import '../../theme/washi_sheet.dart';
import '../analytics/analytics_events.dart';
import '../analytics/analytics.dart';

/// 「このあたりを探す」で探す半径。記録のときの候補（300m）より広く、歩いて行ける範囲。
const nearbySearchRadiusMeters = 1000;

/// 行った店が無く、現在地もわからないときに最初に見せる場所（東京駅）。
const _fallbackCenter = LatLng(35.6812, 139.7671);

/// 右上の「旅路」の丸印（48）と、その左右の余白の分。上に重ねる札はここまでで止める。
const _topControlsInset = 64.0;

/// 右下に縦に並ぶ丸いボタンの幅（余白込み）。
const _bottomControlsInset = 80.0;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
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

  /// 旅路を再生しているときの段取り。再生していなければnull。
  JourneyReplayPlan? _replayPlan;
  late final _replayController = AnimationController(vsync: this)
    ..addListener(_followReplay)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _finishReplay();
    });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate(move: false));
  }

  @override
  void dispose() {
    _replayController.dispose();
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
      _log(
        AnalyticsEvents.mapNearbySearch(succeeded: true, count: nearby.length),
      );
      _showMessage(
        nearby.isEmpty
            ? l10n.mapNearbyNone
            : l10n.mapNearbyFound(nearby.length),
      );
    } catch (e) {
      debugPrint('Nearby search failed: $e');
      _log(AnalyticsEvents.mapNearbySearch(succeeded: false, count: 0));
      if (mounted) _showMessage(l10n.mapSearchFailed);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _log(AnalyticsEvent event) =>
      unawaited(ref.read(analyticsProvider).log(event));

  void _toggleJourney(List<JourneyStop> stops) {
    _stopReplay();
    setState(() => _showJourney = !_showJourney);
    // 地図は現在地のまわりから始まるので、旅路を開いたら道のり全体が入る範囲に合わせる。
    if (_showJourney) _fitTo(stops);
  }

  void _stopReplay() {
    _replayController.stop();
    _replayPlan = null;
  }

  /// 終わったときと「止める」では、引き終えた旅路の全体を見せる。
  void _finishReplay() {
    final stops = _replayPlan?.stops;
    setState(_stopReplay);
    if (stops != null) _fitTo(stops);
  }

  /// 1杯目の店に寄せ、倍率を変えずに線の先を追って店から店へ進み、着いた店を1つずつ灯していく。
  /// 動きを減らす設定のときは、引き終えた旅路をそのまま見せる。
  void _replay(List<JourneyStop> stops) {
    _stopReplay();
    if (stops.isEmpty) return;
    _log(AnalyticsEvents.journeyReplay);
    if (MediaQuery.disableAnimationsOf(context)) {
      _fitTo(stops);
      setState(() {});
      return;
    }
    final plan = JourneyReplayPlan(stops);
    setState(() => _replayPlan = plan);
    _moveTo(plan.cameraAt(0));
    _replayController
      ..duration = plan.duration
      ..forward(from: 0);
  }

  void _followReplay() {
    final plan = _replayPlan;
    if (plan == null) return;
    _moveTo(plan.cameraAt(_replayController.value));
  }

  void _moveTo(GeoPoint point) => _controller.move(
    LatLng(point.latitude, point.longitude),
    journeyFollowZoom,
  );

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

  void _showPlaceDetails(MapPlace place) {
    showWashiSheet<void>(
      context: context,
      builder: (_) => switch (place) {
        VisitedPlace(:final pin) => _PinDetails(pin: pin),
        WishedPlace(:final wish) => _WishDetails(wish: wish),
        UnvisitedPlace(:final shop) => _UnvisitedDetails(
          shop: shop,
          here: _here,
        ),
      },
    );
  }

  /// まとめた印をタップしたら、中の店がおさまるまで寄る。もう寄れなければ、中の店を一覧で見せる。
  void _openCluster(PinCluster<MapPlace> cluster) {
    _log(AnalyticsEvents.mapClusterTap);
    final camera = _controller.camera;
    final fitted = CameraFit.coordinates(
      coordinates: [
        for (final place in cluster.members)
          LatLng(place.location.latitude, place.location.longitude),
      ],
      padding: const EdgeInsets.all(72),
      maxZoom: clusterFitMaxZoom,
    ).fit(camera);
    if (fitted.zoom.floor() <= camera.zoom.floor()) {
      _showPlaceList(
        cluster.members,
        title: AppLocalizations.of(context)
            .mapClusterTitle(cluster.members.length),
        withFilters: false,
      );
      return;
    }
    _userMoved = true;
    _controller.move(fitted.center, fitted.zoom);
  }

  void _showPlaceList(
    List<MapPlace> places, {
    required String title,
    required bool withFilters,
  }) {
    if (withFilters) _log(AnalyticsEvents.mapListOpened);
    final center = _controller.camera.center;
    showWashiSheet<void>(
      context: context,
      builder: (context) => _PlaceListSheet(
        places: places,
        center: GeoPoint(center.latitude, center.longitude),
        title: title,
        withFilters: withFilters,
        onSelect: _focusPlace,
        onFilter: (filter) => _log(AnalyticsEvents.mapFilter(filter.name)),
      ),
    );
  }

  void _focusPlace(MapPlace place) {
    _userMoved = true;
    _controller.move(
      LatLng(place.location.latitude, place.location.longitude),
      math.max(_controller.camera.zoom, 17),
    );
    _showPlaceDetails(place);
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
    final replayPlan = _replayPlan;
    final replayStops = replayPlan?.stops;
    // 再生中は、旅路の店のピンだけを、線が着いた順に灯す。
    final pins = replayStops == null
        ? allPins
        : [
            for (final pin in allPins)
              if (replayStops.any((stop) => stop.shop.id == pin.shop.id)) pin,
          ];
    final base = ref.watch(currentHomeBaseProvider);
    final tilesEnabled = ref.watch(mapTilesEnabledProvider);
    final here = _here;
    final places = <MapPlace>[
      for (final shop in _nearby)
        if (!pendingWishes.any(
          (wish) => wishMatchesPlace(
            wish,
            osmId: shop.osmId,
            name: shop.name,
            location: shop.location,
          ),
        ))
          UnvisitedPlace(shop),
      for (final wish in pendingWishes) WishedPlace(wish),
      for (final pin in pins) VisitedPlace(pin),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: const [SettingsAction()],
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
              // 再生中に地図に触れたら、追うのをやめて引き終えた旅路を見せる（地図はその場のまま）。
              onPointerDown: (_, _) {
                if (_replayPlan != null) setState(_stopReplay);
              },
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) _userMoved = true;
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              if (tilesEnabled) const WashiTileLayer(),
              if (_showJourney && (replayStops ?? stops).length > 1)
                AnimatedBuilder(
                  animation: _replayController,
                  builder: (context, _) => PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          for (final point
                              in replayStops == null
                                  ? [for (final stop in stops) stop.location]
                                  : journeyLineTo(
                                      replayStops,
                                      replayPlan!.reachAt(
                                        _replayController.value,
                                      ),
                                    ))
                            LatLng(point.latitude, point.longitude),
                        ],
                        color: Washi.ai.withValues(alpha: 0.8),
                        strokeWidth: 3,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),
                ),
              if (base != null && replayStops == null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(base.latitude, base.longitude),
                      width: 24,
                      height: 24,
                      child: HomeBaseMapPin(base: base),
                    ),
                  ],
                ),
              _ClusteredPlaceLayer(
                places: places,
                // 旅路の再生中は、灯していくピンを1つずつ見せるため、まとめない。
                clustered: replayStops == null,
                pinBuilder: (place) {
                  final pin = _PlacePin(
                    place: place,
                    onTap: () => _showPlaceDetails(place),
                  );
                  if (replayStops == null || place is! VisitedPlace) {
                    return pin;
                  }
                  return _LightingPin(
                    animation: _replayController,
                    plan: replayPlan!,
                    orders: [
                      for (var i = 0; i < replayStops.length; i++)
                        if (replayStops[i].shop.id == place.pin.shop.id) i,
                    ],
                    child: pin,
                  );
                },
                onCluster: _openCluster,
              ),
              if (here != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(here.latitude, here.longitude),
                      width: 22,
                      height: 22,
                      // 現在地の点の下にある店の印も押せるように。
                      child: const IgnorePointer(child: MapHereDot()),
                    ),
                  ],
                ),
            ],
          ),
          // 下のタブの真ん中の判子に隠れないよう、判子がはみ出す分だけ上げる。右下のボタンは避ける。
          Positioned(
            left: 0,
            right: _bottomControlsInset,
            bottom: RecordSealButton.overhang + 4,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SourceCredit(yahoo: _nearby.isNotEmpty, onMap: true),
            ),
          ),
          if (_showJourney)
            Positioned(
              left: 8,
              right: _topControlsInset,
              top: 8,
              child: _JourneyPanel(
                years: years,
                year: _journeyYear,
                stops: stops,
                isReplaying: replayStops != null,
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
                onReplay: () =>
                    replayPlan == null ? _replay(stops) : _finishReplay(),
                onExpeditions: () =>
                    _showExpeditions(expeditions(scored, year: _journeyYear)),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: Semantics(
              selected: _showJourney,
              child: SealFab(
                sumi: !_showJourney,
                small: true,
                tooltip: l10n.journeyToggle,
                onPressed: () => _toggleJourney(stops),
                child: Icon(_showJourney ? Icons.route : Icons.route_outlined),
              ),
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
              right: _topControlsInset,
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
            if (places.isNotEmpty) ...[
              SealFab(
                sumi: true,
                small: true,
                tooltip: l10n.mapListButton,
                onPressed: () {
                  // 一覧は、いま地図の画面に見えている店だけにする。
                  final bounds = _controller.camera.visibleBounds;
                  final visible = [
                    for (final place in places)
                      if (bounds.contains(
                        LatLng(
                          place.location.latitude,
                          place.location.longitude,
                        ),
                      ))
                        place,
                  ];
                  _showPlaceList(
                    visible,
                    title: l10n.mapListTitle(visible.length),
                    withFilters: true,
                  );
                },
                child: const Icon(Icons.format_list_bulleted),
              ),
              const SizedBox(height: 12),
            ],
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

/// 地図の1軒のピン。行った店は朱で塗った印に店ランクの字、願の店は朱の輪郭に「願」、
/// まだ行っていない店は灰色の印。細い足の先が店の場所を指す（字が場所に重ならないように）。
class _PlacePin extends StatelessWidget {
  const _PlacePin({required this.place, required this.onTap});

  final MapPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, pin) = switch (place) {
      VisitedPlace(:final pin) => (
        pin.shop.name,
        MapSealPin(
          color: pin.rank == null ? Washi.faded : Washi.shu,
          filled: true,
          label: switch (pin.rank) {
            final rank? => shopRankLabel(l10n, rank),
            null => null,
          },
        ),
      ),
      WishedPlace(:final wish) => (
        l10n.mapWishedLabel(wish.name),
        MapSealPin(color: Washi.shu, filled: false, label: l10n.wishSealChar),
      ),
      UnvisitedPlace(:final shop) => (
        shop.name,
        const MapSealPin(color: Washi.faded, filled: true),
      ),
    };
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(child: pin),
      ),
    );
  }
}

/// 店の場所に置く印を、画面の上で重なるものはまとめて出す。
/// まとめ方は倍率の整数の段ごとに決めるので、動かしたり少し拡大したりしても入れ替わらない。
class _ClusteredPlaceLayer extends StatefulWidget {
  const _ClusteredPlaceLayer({
    required this.places,
    required this.clustered,
    required this.pinBuilder,
    required this.onCluster,
  });

  final List<MapPlace> places;
  final bool clustered;
  final Widget Function(MapPlace place) pinBuilder;
  final ValueChanged<PinCluster<MapPlace>> onCluster;

  @override
  State<_ClusteredPlaceLayer> createState() => _ClusteredPlaceLayerState();
}

class _ClusteredPlaceLayerState extends State<_ClusteredPlaceLayer> {
  List<PinCluster<MapPlace>>? _clusters;
  int? _zoom;

  @override
  void didUpdateWidget(_ClusteredPlaceLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clusters = null;
  }

  static int _order(PinCluster<MapPlace> cluster) => !cluster.isSingle
      ? 3
      : switch (cluster.members.single) {
          UnvisitedPlace() => 0,
          WishedPlace() => 1,
          VisitedPlace() => 2,
        };

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom.floor();
    if (_clusters == null || _zoom != zoom) {
      _zoom = zoom;
      final clusters = widget.clustered
          ? clusterPins(
              widget.places,
              locate: (place) => place.location,
              zoom: zoom,
            )
          : [
              for (final place in widget.places)
                PinCluster(members: [place], location: place.location),
            ];
      // 行った店の印が上に来るよう、まだ行っていない店・願・行った店・まとめた印の順に重ねる。
      _clusters = [
        for (var order = 0; order < 4; order++)
          ...clusters.where((cluster) => _order(cluster) == order),
      ];
    }
    return MarkerLayer(
      markers: [
        for (final cluster in _clusters!)
          if (cluster.isSingle)
            Marker(
              point: LatLng(
                cluster.location.latitude,
                cluster.location.longitude,
              ),
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              child: widget.pinBuilder(cluster.members.single),
            )
          else
            Marker(
              point: LatLng(
                cluster.location.latitude,
                cluster.location.longitude,
              ),
              width: MapClusterSeal.size,
              height: MapClusterSeal.size,
              child: _ClusterPin(
                cluster: cluster,
                onTap: () => widget.onCluster(cluster),
              ),
            ),
      ],
    );
  }
}

class _ClusterPin extends StatelessWidget {
  const _ClusterPin({required this.cluster, required this.onTap});

  final PinCluster<MapPlace> cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final members = cluster.members;
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: AppLocalizations.of(context).mapClusterLabel(members.length),
        child: ExcludeSemantics(
          child: MapClusterSeal(
            count: members.length,
            hasVisited: members.any((place) => place is VisitedPlace),
            hasWish: members.any((place) => place is WishedPlace),
          ),
        ),
      ),
    );
  }
}

/// 地図の店の一覧。地図の真ん中から近い順に並べ、タップでその店へ寄って詳しく見せる。
class _PlaceListSheet extends StatefulWidget {
  const _PlaceListSheet({
    required this.places,
    required this.center,
    required this.title,
    required this.withFilters,
    required this.onSelect,
    required this.onFilter,
  });

  final ValueChanged<MapListFilter> onFilter;
  final List<MapPlace> places;
  final GeoPoint center;
  final String title;
  final bool withFilters;
  final ValueChanged<MapPlace> onSelect;

  @override
  State<_PlaceListSheet> createState() => _PlaceListSheetState();
}

class _PlaceListSheetState extends State<_PlaceListSheet> {
  var _filter = MapListFilter.all;

  String _filterLabel(AppLocalizations l10n, MapListFilter filter) =>
      switch (filter) {
        MapListFilter.all => l10n.mapListFilterAll,
        MapListFilter.visited => l10n.mapListFilterVisited,
        MapListFilter.unvisited => l10n.mapListFilterUnvisited,
        MapListFilter.wished => l10n.mapListFilterWished,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final list = mapPlaceList(
      widget.places,
      center: widget.center,
      filter: _filter,
    );
    // 絞り込みで店の数が変わっても窓の高さが変わらないよう、高さを決めて中だけ流す。
    final height = MediaQuery.sizeOf(context).height * 0.6;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: textTheme.titleLarge),
              Text(l10n.mapListSortHint, style: textTheme.bodySmall),
              if (widget.withFilters) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final filter in MapListFilter.values)
                      ChoiceChip(
                        label: Text(_filterLabel(l10n, filter)),
                        selected: _filter == filter,
                        onSelected: (_) {
                          widget.onFilter(filter);
                          setState(() => _filter = filter);
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(l10n.mapListEmpty),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemBuilder: (context, index) {
                          final place = list[index];
                          return _PlaceRow(
                            place: place,
                            meters: distanceMeters(
                              widget.center,
                              place.location,
                            ),
                            onTap: () {
                              closeWashiSheet<void>(context);
                              widget.onSelect(place);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.meters,
    required this.onTap,
  });

  final MapPlace place;
  final double meters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (head, status) = switch (place) {
      VisitedPlace(:final pin) => (
        MapSealHead(
          color: pin.rank == null ? Washi.faded : Washi.shu,
          filled: true,
          size: 28,
          label: switch (pin.rank) {
            final rank? => shopRankLabel(l10n, rank),
            null => null,
          },
        ),
        [
          l10n.mapListVisited,
          if (pin.rank case final rank?)
            l10n.mapShopRank(shopRankLabel(l10n, rank)),
        ].join('・'),
      ),
      WishedPlace() => (
        MapSealHead(
          color: Washi.shu,
          filled: false,
          size: 28,
          label: l10n.wishSealChar,
        ),
        l10n.mapWished,
      ),
      UnvisitedPlace() => (
        const MapSealHead(color: Washi.faded, filled: true, size: 28),
        l10n.mapUnvisited,
      ),
    };
    final distance = meters < 1000
        ? l10n.mapListMeters(meters.round())
        : l10n.mapListKilometers((meters / 1000).toStringAsFixed(1));
    // 店名の長さや印の字に関わらず、どの行も同じ高さにそろえる。
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            SizedBox.square(dimension: 32, child: Center(child: head)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (place.isFamous)
                          TextSpan(
                            text: '${l10n.mapFamous}・',
                            style: TextStyle(color: Washi.shu),
                          ),
                        TextSpan(text: status),
                      ],
                    ),
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(distance, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _UnvisitedDetails extends ConsumerWidget {
  const _UnvisitedDetails({required this.shop, required this.here});

  final FoundShop shop;
  final GeoPoint? here;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final here = this.here;
    return SafeArea(
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
                  source: WishSource.map,
                );
              },
            ),
          ],
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

/// 願を掛けた（まだ行っていない）店。
class _WishDetails extends StatelessWidget {
  const _WishDetails({required this.wish});

  final Wish wish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
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
            Wrap(
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

/// 旅路の再生で、線が着いたときにふっと灯るピン。
class _LightingPin extends StatelessWidget {
  const _LightingPin({
    required this.animation,
    required this.plan,
    required this.orders,
    required this.child,
  });

  final Animation<double> animation;
  final JourneyReplayPlan plan;

  /// 旅路の何番目に着く店か（同じ店に何度も行っていれば、着くたびの番号）。
  final List<int> orders;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final t = animation.value;
      // 1杯目の店は寄せたときから灯し、ほかは線が着いて止まっている間に刺す。
      final lit = plan.pinAt(t, orders.first);
      if (lit == 0) return const SizedBox.shrink();
      final pop = Curves.easeOutBack.transform(lit);
      // 二度目からは、もう刺さっているピンを跳ねさせて「また来た」を見せる。
      var hop = 0.0;
      for (final order in orders.skip(1)) {
        final again = plan.pinAt(t, order);
        if (again > 0 && again < 1) hop = math.sin(again * math.pi);
      }
      return Opacity(
        opacity: lit,
        child: Transform.translate(
          offset: Offset(0, -10 * hop),
          child: Transform.scale(
            scale: (0.6 + 0.4 * pop) * (1 + 0.25 * hop),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
      );
    },
  );
}
