import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../home/rating_prompt.dart';
import '../record/star_rating.dart';
import '../records/date_format.dart';
import '../records/models.dart';
import '../records/photo_storage.dart';
import '../records/record_repository.dart';
import '../records/visit_photo.dart';
import '../records/wait_time.dart';
import '../inkan/inkan_stamp.dart';
import '../scoring/points.dart';
import '../scoring/points_breakdown_view.dart';
import '../../theme/washi.dart';
import '../shop/maps_link.dart';
import '../shop/shop_memo_dialog.dart';
import '../scoring/scoring_providers.dart';
import '../wishes/wish_dialog.dart';
import '../wishes/wish_providers.dart';
import '../wishes/wishes.dart';
import '../journal/journal.dart';
import '../journal/journal_view.dart';
import '../journal/shop_area.dart';
import '../share/share_screen.dart';
import '../map/location_picker_screen.dart';
import '../shop_search/geo.dart';
import '../shop_search/shop_name_search_sheet.dart';
import 'visit_edit_screen.dart';
import '../../theme/washi_buttons.dart';

/// 1つの店のページ。開いた1杯を大きく見せ、この店で集めた印をタップすると切り替わる。
class VisitDetailScreen extends ConsumerStatefulWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends ConsumerState<VisitDetailScreen> {
  late String _visitId = widget.visitId;

  Future<void> _delete(String visitId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmMessage),
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // 画面を閉じたあとは`ref`を使えないため、先に取り出しておく。
    final repository = ref.read(recordRepositoryProvider);
    final storage = ref.read(photoStorageProvider);
    final String? photoPath;
    try {
      photoPath = await repository.deleteVisit(visitId);
    } catch (e) {
      debugPrint('Visit delete failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
      return;
    }
    navigator.pop();
    if (photoPath == null) return;
    try {
      await storage.delete(photoPath);
    } catch (e) {
      debugPrint('Photo delete failed: $e');
    }
  }

  /// 位置のわからない店（過去の写真から手入力した店など）を、店名で探して地図に載せる。
  Future<void> _locateShop(Shop shop) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(recordRepositoryProvider);
    final found = await showShopNameSearch(context, initialName: shop.name);
    if (found == null) return;
    try {
      await repository.setShopLocation(
        shop.id,
        latitude: found.location.latitude,
        longitude: found.location.longitude,
        osmId: found.osmId,
        dataSource: found.dataSource,
      );
      if (mounted) ref.invalidate(ensureShopAreaProvider(shop.id));
      messenger.showSnackBar(SnackBar(content: Text(l10n.shopLocated)));
    } catch (e) {
      debugPrint('Shop locate failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.editSaveFailed)));
    }
  }

  /// 店名で見つからない店の場所を地図で指す。位置のある店（OpenStreetMap 以外）は場所を直す。
  Future<void> _pinShop(Shop shop) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(recordRepositoryProvider);
    final latitude = shop.latitude;
    final longitude = shop.longitude;
    final picked = await showLocationPicker(
      context,
      shopName: shop.name,
      initial: latitude != null && longitude != null
          ? GeoPoint(latitude, longitude)
          : null,
    );
    if (picked == null) return;
    try {
      await repository.setShopLocation(
        shop.id,
        latitude: picked.latitude,
        longitude: picked.longitude,
      );
      if (mounted) ref.invalidate(ensureShopAreaProvider(shop.id));
      messenger.showSnackBar(SnackBar(content: Text(l10n.shopLocated)));
    } catch (e) {
      debugPrint('Shop pin failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.editSaveFailed)));
    }
  }

  Future<void> _openInMaps(Shop shop) async {
    final latitude = shop.latitude;
    final longitude = shop.longitude;
    if (latitude == null || longitude == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).openInMapsFailed;
    final opened = await openInMaps(
      latitude: latitude,
      longitude: longitude,
      name: shop.name,
    );
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  Future<void> _setFamous(Shop shop, bool isFamous) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).editSaveFailed;
    try {
      await ref.read(recordRepositoryProvider).setShopFamous(shop.id, isFamous);
    } catch (e) {
      debugPrint('Shop famous save failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _editShopMemo(Shop shop) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).editSaveFailed;
    final repository = ref.read(recordRepositoryProvider);
    final memo = await showShopMemoDialog(context, shop.strategyMemo);
    if (memo == null) return;
    try {
      await repository.setShopMemo(shop.id, memo);
    } catch (e) {
      debugPrint('Shop memo save failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visits = ref.watch(visitsProvider).value ?? const [];
    final entry = visits.where((e) => e.visit.id == _visitId).firstOrNull;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.visitNotFound)),
      );
    }
    final visit = entry.visit;
    // 道中記で地名に触れるため、まだなら店の市区町村を調べておく。
    ref.watch(ensureShopAreaProvider(entry.shop.id));
    final scored = ref.watch(scoredVisitByIdProvider)[visit.id];
    final shopStamps = [
      for (final stamp in ref.watch(scoredVisitsProvider))
        if (stamp.visit.shopId == entry.shop.id) stamp,
    ];
    final textTheme = Theme.of(context).textTheme;
    final waited = waitMinutes(visit);
    // 撤退・系統・日付は印に入っているので、札にはしない。
    final tags = [
      if (waited != null) l10n.waitTime(waited),
      if (visit.isLimited) l10n.limitedBadge,
    ];

    final statuses = ref.watch(wishStatusesProvider);
    final pendingWish = pendingWishFor(statuses, entry.shop);
    final canFulfill =
        visit.result == VisitResult.eaten &&
        pendingWish != null &&
        wishPrecedes(pendingWish, visit.eatenAt) &&
        !statuses.any((s) => s.fulfilledBy?.visit.id == visit.id);

    void addWish() => addWishFor(
      context,
      ref,
      ShopInput(
        shopId: entry.shop.id,
        osmId: entry.shop.osmId,
        name: entry.shop.name,
        latitude: entry.shop.latitude,
        longitude: entry.shop.longitude,
        dataSource: entry.shop.dataSource,
      ),
    );

    return Scaffold(
      // 店名はページの縦書きにあるので、上には出さない。よく使う「共有」以外は「…」にまとめる。
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l10n.shareTitle,
            icon: const Icon(Icons.ios_share),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShareScreen(visitId: visit.id),
              ),
            ),
          ),
          PopupMenuButton<_DetailAction>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _DetailAction.wish => addWish(),
              _DetailAction.relocate => _pinShop(entry.shop),
              _DetailAction.edit => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VisitEditScreen(entry: entry),
                ),
              ),
              _DetailAction.delete => _delete(visit.id),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _DetailAction.wish,
                enabled: pendingWish == null,
                child: Text(
                  pendingWish == null ? l10n.wishMakeButton : l10n.wishAlready,
                ),
              ),
              PopupMenuItem(value: _DetailAction.edit, child: Text(l10n.edit)),
              // OpenStreetMap の店は地図のデータの位置を正とし、ここでは直さない。
              if (entry.shop.osmId == null && entry.shop.latitude != null)
                PopupMenuItem(
                  value: _DetailAction.relocate,
                  child: Text(l10n.shopRelocate),
                ),
              PopupMenuItem(
                value: _DetailAction.delete,
                child: Text(l10n.delete),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Washi.desk,
      body: ListView(
        // スマホの下の操作バーに重ならないよう、その高さぶん余白をとる。
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _ShopPage(entry: entry, scored: scored),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: entry.shop.latitude == null || entry.shop.longitude == null
                  ? Wrap(
                      spacing: 8,
                      children: [
                        FudeLink(
                          icon: const Icon(Icons.travel_explore),
                          child: Text(l10n.shopLocate),
                          onPressed: () => _locateShop(entry.shop),
                        ),
                        FudeLink(
                          icon: const Icon(Icons.push_pin_outlined),
                          child: Text(l10n.locationPickOpen),
                          onPressed: () => _pinShop(entry.shop),
                        ),
                      ],
                    )
                  : FudeLink(
                      icon: const Icon(Icons.map_outlined),
                      child: Text(l10n.openInMaps),
                      onPressed: () => _openInMaps(entry.shop),
                    ),
            ),
          ),
          if (canFulfill)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(l10n.wishFulfillPrompt(pendingWish.name)),
                  trailing: FudeLink(
                    onPressed: () => ref
                        .read(recordRepositoryProvider)
                        .fulfillWish(
                          pendingWish.id,
                          visitId: visit.id,
                          shopId: entry.shop.id,
                        ),
                    child: Text(l10n.wishFulfillButton),
                  ),
                ),
              ),
            ),
          if (shopStamps.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ShopStamps(
                stamps: shopStamps,
                selectedId: visit.id,
                onSelect: (id) => setState(() => _visitId = id),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (visit.result == VisitResult.eaten) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StarRating(
                      rating: visit.rating,
                      onChanged: (rating) =>
                          saveRating(context, ref, visit.id, rating),
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [for (final tag in tags) Chip(label: Text(tag))],
                  ),
                ],
                if (visit.memo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(visit.memo, style: textTheme.bodyLarge),
                ],
                if (scored != null) ...[
                  const SizedBox(height: 16),
                  JournalView(
                    lines: buildJournal(
                      scored,
                      ref.watch(scoredVisitsProvider),
                    ),
                  ),
                ],
                const Divider(height: 32),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.shopFamousToggle),
                  subtitle: Text(l10n.shopFamousHint),
                  value: entry.shop.isFamous,
                  onChanged: (value) => _setFamous(entry.shop, value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.shopMemoSection,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.shopMemoEdit,
                      icon: const Icon(Icons.edit_note),
                      onPressed: () => _editShopMemo(entry.shop),
                    ),
                  ],
                ),
                Text(
                  entry.shop.strategyMemo.isEmpty
                      ? l10n.shopMemoEmpty
                      : entry.shop.strategyMemo,
                  style: textTheme.bodyMedium,
                ),
                if (scored != null) ...[
                  const Divider(height: 32),
                  // 修行点は1行だけ。押すと内訳を開く。
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.pointsSection,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          l10n.points(scored.points.total),
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                    children: [PointsBreakdownView(scored: scored)],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 台紙に貼った写真と、写真の端にかぶせて押した印、縦書きの店名。
class _ShopPage extends StatelessWidget {
  const _ShopPage({required this.entry, required this.scored});

  final VisitWithShop entry;
  final ScoredVisit? scored;

  @override
  Widget build(BuildContext context) {
    final scored = this.scored;
    final visit = entry.visit;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Washi.page,
        border: Border.all(color: Washi.line),
        boxShadow: const [BoxShadow(color: Washi.line, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: PastedPhoto(
                      angle: -1.5 * math.pi / 180,
                      border: 6,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: VisitPhoto(photoPath: visit.photoPath),
                      ),
                    ),
                  ),
                  if (scored != null)
                    Positioned(
                      right: 4,
                      bottom: 0,
                      child: InkanStamp(scored: scored, size: 120),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Washi.line)),
              ),
              child: VerticalText(
                entry.shop.name,
                maxChars: 11,
                style: const TextStyle(
                  fontFamily: Washi.brush,
                  fontSize: 28,
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

/// この店で集めた印（古い順）。タップするとその1杯に切り替わる。
class _ShopStamps extends StatelessWidget {
  const _ShopStamps({
    required this.stamps,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ScoredVisit> stamps;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shopStamps,
          style: textTheme.titleMedium?.copyWith(fontFamily: Washi.brush),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final stamp in stamps)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _ShopStampChoice(
                    stamp: stamp,
                    selected: stamp.visit.id == selectedId,
                    onTap: () => onSelect(stamp.visit.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// この道場の印の1つ。いま見ている1杯の印だけを濃く押し、下に藍の筆を引く。ほかの印は薄くする。
class _ShopStampChoice extends StatelessWidget {
  const _ShopStampChoice({
    required this.stamp,
    required this.selected,
    required this.onTap,
  });

  final ScoredVisit stamp;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
          child: Column(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: selected ? 1 : 0.4,
                child: InkanStamp(scored: stamp, size: 72),
              ),
              const SizedBox(height: 2),
              Text(
                formatDate(stamp.visit.eatenAt),
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? Washi.ink : Washi.faded,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: selected ? 1 : 0,
                child: CustomPaint(
                  size: const Size(48, 6),
                  painter: _SelectedStrokePainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedStrokePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    brushStroke(
      canvas,
      Offset(2, size.height * 0.6),
      Offset(size.width - 2, size.height * 0.4),
      3.2,
      1,
      Paint()..color = Washi.ai,
    );
  }

  @override
  bool shouldRepaint(_SelectedStrokePainter oldDelegate) => false;
}

enum _DetailAction { wish, edit, relocate, delete }
