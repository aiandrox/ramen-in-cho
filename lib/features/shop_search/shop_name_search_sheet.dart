import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'builtin_shops.dart';
import 'curated_shops_store.dart';
import 'found_shop.dart';
import 'geo.dart';
import 'openpoi_client.dart';
import 'ramen_in_cho_api.dart';
import 'yahoo_local.dart';
import 'yahoo_local_client.dart';
import '../../theme/washi_sheet.dart';

/// 店名で全国の店を探し、選んだ店を返す。やめたらnull。
Future<FoundShop?> showShopNameSearch(
  BuildContext context, {
  required String initialName,
  GeoPoint? near,
}) => showWashiSheet<FoundShop>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ShopNameSearchSheet(initialName: initialName, near: near),
);

class _ShopNameSearchSheet extends ConsumerStatefulWidget {
  const _ShopNameSearchSheet({required this.initialName, this.near});

  final String initialName;
  final GeoPoint? near;

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

  Future<void> _search() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final generation = ++_generation;
    setState(() {
      _isSearching = true;
      _failed = false;
    });
    try {
      // 同じ店なら、ラーメン店の業種で絞れる Yahoo! のほうを残す。
      // Yahoo! が使えないとき（Client ID が無い・失敗）も、OpenPOI の結果は出す。
      // まずサーバーに聞く（空白の言い換えもサーバーで行う）。だめなら端末から直接探す。
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
          setState(() {
            _results = nearestFirst(
              withCuratedConditions(
                mergeFoundShops(curated, shops),
                curatedShops,
              ),
              widget.near,
            );
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

      final yahoo = isYahooEnabled
          ? searchAll(
              'Yahoo',
              (query) => ref
                  .read(yahooLocalClientProvider)
                  .searchByName(query, near: widget.near),
            )
          : Future<List<FoundShop>?>.value();
      final poi = searchAll(
        'OpenPOI',
        (query) => ref
            .read(openPoiClientProvider)
            .searchByName(query, near: widget.near),
      );
      final yahooShops = await yahoo;
      final poiShops = await poi;
      // アプリに持たせている店（ラーメン二郎の直系店）は、通信できなくても出す。
      final builtin = curated;
      if (yahooShops == null && poiShops == null && builtin.isEmpty) {
        throw StateError('店名の検索がすべて失敗しました');
      }
      final results = nearestFirst(
        withCuratedConditions(
          mergeFoundShops(builtin, [...?yahooShops, ...?poiShops]),
          curatedShops,
        ),
        widget.near,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Shop name search failed: $e');
      if (!mounted || generation != _generation) return;
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
                  if (results != null && results.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        [
                          l10n.openPoiAttribution,
                          if (isYahooEnabled) l10n.yahooAttribution,
                        ].join('\n'),
                        style: textTheme.labelSmall,
                        textAlign: TextAlign.right,
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
