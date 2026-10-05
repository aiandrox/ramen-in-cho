import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi_buttons.dart';
import '../record/photo_metadata.dart';
import '../records/models.dart';
import '../records/photo_storage.dart';
import '../shop_search/geo.dart';
import '../shop_search/shop_candidate.dart';
import '../shop_search/shop_name_search_sheet.dart';
import '../shop_search/shop_search_service.dart';
import '../shop_search/shop_tile.dart';
import '../shop_search/yahoo_local.dart';

/// 保存した記録の店を選び直す。店の位置（無ければ写真の撮影場所、それも無ければ現在地）の
/// 近くの候補と、店名での全国検索から選ぶ。やめたらnull。
Future<ShopCandidate?> showShopRepick(
  BuildContext context, {
  required Shop shop,
  required String? photoPath,
  required String name,
}) => showModalBottomSheet<ShopCandidate>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _ShopRepickSheet(shop: shop, photoPath: photoPath, name: name),
);

class _ShopRepickSheet extends ConsumerStatefulWidget {
  const _ShopRepickSheet({
    required this.shop,
    required this.photoPath,
    required this.name,
  });

  final Shop shop;
  final String? photoPath;
  final String name;

  @override
  ConsumerState<_ShopRepickSheet> createState() => _ShopRepickSheetState();
}

class _ShopRepickSheetState extends ConsumerState<_ShopRepickSheet> {
  ShopSearchResult? _result;
  GeoPoint? _center;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    final center = await _searchCenter();
    final result = await ref
        .read(shopSearchServiceProvider)
        .search(requestPermission: true, near: center);
    if (!mounted) return;
    setState(() {
      _center = center ?? result.here;
      _result = result;
    });
  }

  Future<GeoPoint?> _searchCenter() async {
    final latitude = widget.shop.latitude;
    final longitude = widget.shop.longitude;
    if (latitude != null && longitude != null) {
      return GeoPoint(latitude, longitude);
    }
    final photoPath = widget.photoPath;
    if (photoPath == null) return null;
    final file = ref.read(photoStorageProvider).fileFor(photoPath);
    final metadata = await ref
        .read(photoMetadataReaderProvider)
        .read(file.path);
    return metadata.location;
  }

  Future<void> _searchByName() async {
    final found = await showShopNameSearch(
      context,
      initialName: widget.name,
      near: _center,
    );
    if (found == null || !mounted) return;
    Navigator.of(context).pop(
      ShopCandidate(
        osmId: found.osmId,
        name: found.name,
        location: found.location,
        dataSource: found.dataSource,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final result = _result;
    final empty = result?.candidates.isEmpty ?? false;
    final message = switch (result?.failure) {
      _ when result == null => null,
      ShopSearchFailure.noLocation => l10n.editShopRepickNoLocation,
      ShopSearchFailure.searchFailed when empty => l10n.editShopRepickFailed,
      ShopSearchFailure.searchFailed => l10n.shopSearchPartial,
      null when empty => l10n.editShopRepickNone,
      _ => null,
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(l10n.editShopRepickTitle, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            if (result == null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text(l10n.shopSearching),
              ),
            for (final candidate in result?.candidates ?? const [])
              ShopTile(
                shop: candidate,
                selected: candidate.shopId == widget.shop.id,
                onTap: () => Navigator.of(context).pop(candidate),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(message, style: textTheme.bodySmall),
              ),
            if (result != null &&
                result.failure != ShopSearchFailure.noLocation)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  [
                    l10n.shopSearchAttribution,
                    if (isYahooEnabled) l10n.yahooAttribution,
                  ].join('\n'),
                  style: textTheme.labelSmall,
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: FudeLink(
                icon: const Icon(Icons.travel_explore),
                onPressed: _searchByName,
                child: Text(l10n.editShopRepickByName),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
