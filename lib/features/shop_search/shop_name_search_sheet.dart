import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../credits/source_credit.dart';
import '../../l10n/app_localizations.dart';
import 'builtin_shops.dart';
import 'curated_shops_store.dart';
import 'found_shop.dart';
import 'geo.dart';
import 'openpoi_client.dart';
import 'ramen_in_cho_api.dart';
import '../../theme/washi_buttons.dart';
import '../../theme/washi_sheet.dart';
import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';

/// 店名で全国の店を探し、選んだ店を返す。やめたらnull。
/// [onPickOnMap]があれば、結果の下に「地図で場所を指す」を出し、押されたら窓を閉じて呼ぶ。
Future<FoundShop?> showShopNameSearch(
  BuildContext context, {
  required String initialName,
  GeoPoint? near,
  VoidCallback? onPickOnMap,
}) => showWashiSheet<FoundShop>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ShopNameSearchSheet(
    initialName: initialName,
    near: near,
    onPickOnMap: onPickOnMap,
  ),
);

class _ShopNameSearchSheet extends ConsumerStatefulWidget {
  const _ShopNameSearchSheet({
    required this.initialName,
    this.near,
    this.onPickOnMap,
  });

  final String initialName;
  final GeoPoint? near;
  final VoidCallback? onPickOnMap;

  @override
  ConsumerState<_ShopNameSearchSheet> createState() =>
      _ShopNameSearchSheetState();
}

class _ShopNameSearchSheetState extends ConsumerState<_ShopNameSearchSheet> {
  late final _controller = TextEditingController(text: widget.initialName);
  List<FoundShop>? _results;
  bool _isSearching = false;
  bool _failed = false;

  /// 探している途中で探し直したら、新しい方の結果だけを出す。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialName.trim().isNotEmpty) _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _log(String via, List<FoundShop>? results) => unawaited(
    ref
        .read(analyticsProvider)
        .log(AnalyticsEvents.shopNameSearch(via: via, results: results)),
  );

  Future<void> _search() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final generation = ++_generation;
    setState(() {
      _isSearching = true;
      _failed = false;
    });
    try {
      // まずサーバーに聞く（空白の言い換えもサーバーで行う）。だめなら端末から OpenPOI で直接探す。
      final curatedShops = ref.read(curatedShopsProvider);
      final curated = builtinShopsNamed(
        name,
        near: widget.near,
        shops: curatedShops,
      );
      final api = ref.read(ramenInChoApiProvider);
      if (api != null) {
        try {
          final shops = await api.searchByName(name, near: widget.near);
          if (!mounted || generation != _generation) return;
          final results = nearestFirst(
            mergeFoundShops(curated, shops),
            widget.near,
          );
          _log('server', results);
          setState(() {
            _results = results;
            _isSearching = false;
          });
          return;
        } catch (e) {
          debugPrint('Ramen-In-Cho API name search failed: $e');
        }
      }
      // 空白の有無で結果が変わるので、空白を詰めた言葉でも探してまとめる。
      final queries = nameQueryVariants(name);
      Future<List<FoundShop>?> searchAll(
        String label,
        Future<List<FoundShop>> Function(String query) search,
      ) async {
        final results = await Future.wait([
          for (final query in queries)
            search(query).then<List<FoundShop>?>(
              (shops) => shops,
              onError: (Object e) {
                debugPrint('$label name search failed: $e');
                return null;
              },
            ),
        ]);
        if (results.every((shops) => shops == null)) return null;
        return [for (final shops in results) ...?shops];
      }

      final poi = searchAll(
        'OpenPOI',
        (query) => ref
            .read(openPoiClientProvider)
            .searchByName(query, near: widget.near),
      );
      final poiShops = await poi;
      // アプリに持たせている店（ラーメン二郎の直系店）は、通信できなくても出す。
      final builtin = curated;
      if (poiShops == null && builtin.isEmpty) {
        throw StateError('店名の検索がすべて失敗しました');
      }
      final results = nearestFirst(
        mergeFoundShops(builtin, poiShops ?? const []),
        widget.near,
      );
      if (!mounted || generation != _generation) return;
      _log('device', results);
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Shop name search failed: $e');
      if (!mounted || generation != _generation) return;
      _log('device', null);
      setState(() {
        _failed = true;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final results = _results;
    final near = widget.near;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l10n.nameSearchTitle, style: textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: l10n.shopNameLabel,
                  suffixIcon: IconButton(
                    tooltip: l10n.nameSearchButton,
                    icon: const Icon(Icons.search),
                    onPressed: _search,
                  ),
                ),
              ),
            ),
            if (_isSearching) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  8,
                  8,
                  8,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (_failed)
                    ListTile(title: Text(l10n.nameSearchFailed))
                  else if (results != null && results.isEmpty)
                    ListTile(title: Text(l10n.nameSearchNone)),
                  for (final shop in results ?? const <FoundShop>[])
                    ListTile(
                      leading: const Icon(Icons.storefront),
                      title: Text(shop.name),
                      subtitle: Text(
                        [
                          ?shop.address,
                          if (near != null)
                            l10n.nameSearchDistance(
                              (distanceMeters(near, shop.location) / 1000)
                                  .toStringAsFixed(1),
                            ),
                        ].join('・'),
                      ),
                      onTap: () => Navigator.of(context).pop(shop),
                    ),
                  // 探しても見つからないときの逃げ道。最初からは使わない想定なので、結果の下に置く。
                  if ((results != null || _failed) &&
                      widget.onPickOnMap != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FudeLink(
                          icon: const Icon(Icons.push_pin_outlined),
                          onPressed: () {
                            closeWashiSheet(context);
                            widget.onPickOnMap!();
                          },
                          child: Text(l10n.nameSearchPickOnMap),
                        ),
                      ),
                    ),
                  if (results != null && results.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SourceCredit(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
