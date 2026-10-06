import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../records/models.dart';
import '../scoring/rank_labels.dart';
import 'shop_pins.dart';

/// 地図の画像は OpenStreetMap のタイルサーバーから取る。送るのは表示範囲だけ（issue #8）。
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// 拠点も行った店も現在地も無いときに見せる、日本全体。
const mapJapanCenter = LatLng(36.5, 137.0);
const mapJapanZoom = 5.0;

/// テストでは地図の画像を取りに行かないよう、falseに差し替える。
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

/// 地図の色を8割ほど抜き、少し明るく暖かい色にする。
const _washiTiles = ColorFilter.matrix(<double>[
  0.50, 0.42, 0.08, 0, 30, //
  0.15, 0.77, 0.08, 0, 26, //
  0.15, 0.42, 0.43, 0, 14, //
  0, 0, 0, 1, 0, //
]);

/// 色を抜いて和紙の色に寄せた地図。朱の印（ピン）が目立つようにする。
/// タイルごとではなく、地図全体に1回だけかける（描画の負担を減らすため）。
class WashiTileLayer extends StatelessWidget {
  const WashiTileLayer({super.key});

  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: _washiTiles,
    child: TileLayer(
      urlTemplate: _tileUrl,
      userAgentPackageName: 'com.aiandrox.ramen_in_cho',
    ),
  );
}

/// 地図の左下に出す出典（部品名は出さない）。
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Washi.paper.withValues(alpha: 0.85),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        AppLocalizations.of(context).mapAttribution,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ),
  );
}

class MapHereDot extends StatelessWidget {
  const MapHereDot({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
    );
  }
}

/// 今の拠点。店のピンと見分けられるよう、小さな墨の輪で出す。
class HomeBaseMapPin extends StatelessWidget {
  const HomeBaseMapPin({super.key, required this.base});

  final HomeBaseSetting base;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      child: Semantics(
        label: l10n.homeBasePinLabel(base.name),
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Washi.page,
              border: Border.all(color: Washi.ink, width: 1.5),
            ),
            child: Text(
              l10n.homeBaseSealChar,
              style: const TextStyle(
                fontFamily: Washi.brush,
                fontSize: 12,
                height: 1,
                color: Washi.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 地図の印のピン。上の丸に字を入れ、下の細い足の先が店の場所を指す。
class MapSealPin extends StatelessWidget {
  const MapSealPin({
    super.key,
    required this.color,
    required this.filled,
    this.label,
  });

  final Color color;
  final bool filled;
  final String? label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 44,
    child: Column(
      children: [
        MapSealHead(color: color, filled: filled, label: label),
        Container(width: 2.5, height: 14, color: color),
      ],
    ),
  );
}

/// 印のピンの頭（丸と字）。一覧の行の頭にも使う。
class MapSealHead extends StatelessWidget {
  const MapSealHead({
    super.key,
    required this.color,
    required this.filled,
    this.label,
    this.size = 30,
  });

  final Color color;
  final bool filled;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Washi.page,
        border: Border.all(color: color, width: size / 12),
      ),
      child: label == null
          ? null
          : Text(
              label,
              style: TextStyle(
                fontFamily: Washi.brush,
                fontSize: size * 16 / 30,
                height: 1,
                color: filled ? Washi.page : color,
              ),
            ),
    );
  }
}

/// 重なったピンをまとめた印。藍の丸に軒数を筆の字で入れる（まだ行っていない店だけなら灰色）。
/// 行った店を含めば朱の点、願を含めば朱の輪を右上に添える。
class MapClusterSeal extends StatelessWidget {
  const MapClusterSeal({
    super.key,
    required this.count,
    required this.hasVisited,
    required this.hasWish,
  });

  final int count;
  final bool hasVisited;
  final bool hasWish;

  static const size = 44.0;

  @override
  Widget build(BuildContext context) {
    final color = hasVisited || hasWish ? Washi.ai : Washi.faded;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Washi.page, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), blurRadius: 3),
                ],
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: Washi.brush,
                  fontSize: count >= 100 ? 13 : 17,
                  height: 1,
                  color: Washi.page,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasWish) const _ClusterDot(filled: false),
                if (hasVisited) const _ClusterDot(filled: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClusterDot extends StatelessWidget {
  const _ClusterDot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? Washi.shu : Washi.page,
      border: Border.all(color: filled ? Washi.page : Washi.shu, width: 2),
    ),
  );
}

/// 場所を選ぶ地図で、目印に出す行った店の印（地図のタブと同じ。押せない）。
List<Marker> visitedShopMarkers(AppLocalizations l10n, List<ShopPin> pins) => [
  for (final pin in pins)
    Marker(
      point: LatLng(pin.latitude, pin.longitude),
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: MapSealPin(
        color: pin.rank == null ? Washi.faded : Washi.shu,
        filled: true,
        label: switch (pin.rank) {
          final rank? => shopRankLabel(l10n, rank),
          null => null,
        },
      ),
    ),
];
