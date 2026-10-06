import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';
import '../home_base/home_base_repository.dart';
import '../scoring/scoring_providers.dart';
import '../shop_search/geo.dart';
import '../shop_search/location_service.dart';
import 'shop_pins.dart';
import 'washi_map.dart';

/// 店の場所を指すときの地図の倍率。通りと建物が見分けられる広さ。
const locationPickZoom = 17.0;

/// 拠点や行った店から始めるときの倍率。街のあたりから寄せていく。
const _areaZoom = 14.0;

/// 店名で見つからない店の場所を、地図の真ん中の印に合わせて指す。決めた場所を返す（やめたらnull）。
/// 始める場所は[initial]（写真の撮影場所や今の店の位置）、無ければ現在地（許可済みのときだけ）、
/// 拠点、行った店のあたり、日本全体の順。
Future<GeoPoint?> showLocationPicker(
  BuildContext context, {
  required String shopName,
  GeoPoint? initial,
}) => Navigator.of(context).push<GeoPoint>(
  MaterialPageRoute(
    builder: (_) => LocationPickerScreen(shopName: shopName, initial: initial),
  ),
);

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, required this.shopName, this.initial});

  final String shopName;
  final GeoPoint? initial;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _controller = MapController();
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

  /// 開いたときは許可を聞かない。始める場所が無く、地図を動かしていなければ現在地へ寄せる。
  Future<void> _loadHere() async {
    final location = ref.read(locationServiceProvider);
    if (!await location.isReady()) return;
    final here = await location.currentPosition(requestPermission: false);
    if (!mounted || here == null) return;
    setState(() => _here = here);
    if (widget.initial == null && !_userMoved) {
      _controller.move(LatLng(here.latitude, here.longitude), locationPickZoom);
    }
  }

  Future<void> _moveToHere() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _locating = true);
    GeoPoint? here;
    try {
      here = await ref
          .read(locationServiceProvider)
          .currentPosition(requestPermission: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
    if (!mounted) return;
    if (here == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.homeBaseHereFailed)));
      return;
    }
    setState(() => _here = here);
    _controller.move(LatLng(here.latitude, here.longitude), locationPickZoom);
  }

  void _useCenter() {
    final center = _controller.camera.center;
    Navigator.of(context).pop(GeoPoint(center.latitude, center.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final initial = widget.initial;
    final base = ref.watch(currentHomeBaseProvider);
    final pins = shopPins(ref.watch(scoredVisitsProvider));
    final tilesEnabled = ref.watch(mapTilesEnabledProvider);
    final here = _here;
    final (LatLng center, double zoom) = switch ((initial, base)) {
      (final initial?, _) => (
        LatLng(initial.latitude, initial.longitude),
        locationPickZoom,
      ),
      (null, final base?) => (LatLng(base.latitude, base.longitude), _areaZoom),
      (null, null) => (mapJapanCenter, mapJapanZoom),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.locationPickTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: zoom,
                    initialCameraFit:
                        initial != null || base != null || pins.isEmpty
                        ? null
                        : CameraFit.coordinates(
                            coordinates: [
                              for (final pin in pins)
                                LatLng(pin.latitude, pin.longitude),
                            ],
                            padding: const EdgeInsets.all(48),
                            maxZoom: _areaZoom,
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
                    IgnorePointer(
                      child: MarkerLayer(
                        markers: [
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
                const IgnorePointer(child: Center(child: _CenterPin())),
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        l10n.locationPickIntro(widget.shopName),
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
                    onPressed: _locating ? null : _moveToHere,
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
              child: AiFuda(
                expand: true,
                onPressed: _useCenter,
                child: Text(l10n.locationPickUseCenter),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 地図の真ん中に重ねる十字とピン。ピンの足の先（十字の交わるところ）が店の場所になる。
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.locationPickCenterLabel,
      child: SizedBox.square(
        dimension: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: _size, height: 1, color: Washi.inkSoft),
            Container(width: 1, height: _size, color: Washi.inkSoft),
            // ピン（高さ44）の足の先を真ん中に合わせる。
            Transform.translate(
              offset: const Offset(0, -22),
              child: MapSealPin(
                color: Washi.ai,
                filled: true,
                label: l10n.locationPickSealChar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
