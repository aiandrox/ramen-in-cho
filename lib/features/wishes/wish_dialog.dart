import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../error_reporting/error_reporting.dart';
import '../map/location_picker_screen.dart';
import '../records/clock.dart';
import '../records/models.dart';
import '../records/record_repository.dart';
import '../shop_search/geo.dart';
import '../shop_search/ramen_in_cho_api.dart';
import '../shop_search/shop_name_search_sheet.dart';
import 'wish_repository.dart';
import '../../theme/washi_buttons.dart';

/// 店名だけで掛ける願の場所（店名で探した店、地図で指した場所、住所から調べた場所）。
class WishPlace {
  const WishPlace({required this.location, this.osmId, this.dataSource});

  final GeoPoint location;
  final String? osmId;
  final ShopSource? dataSource;
}

class WishText {
  const WishText({
    required this.name,
    required this.trigger,
    required this.note,
    this.link,
    this.place,
  });

  final String name;
  final String trigger;
  final String note;

  /// 店を知ったページのリンク。空ならnull。
  final String? link;

  /// 店名だけで掛けるときに決めた場所。決めていなければnull。
  final WishPlace? place;
}

/// 願を書き留める・書き直す。[name]を渡すと店名は変えられない（地図や店のページから掛けるとき）。
/// [pickPlace]なら、店名から探す・地図で指す で場所も決められる（[address]があれば、まず住所から調べる）。
Future<WishText?> showWishDialog(
  BuildContext context, {
  String? name,
  String initialName = '',
  String trigger = '',
  String note = '',
  String? link,
  bool isEditing = false,
  bool pickPlace = false,
  WishPlace? place,
  String? address,
}) => showDialog<WishText>(
  context: context,
  builder: (_) => _WishDialog(
    name: name,
    initialName: initialName,
    trigger: trigger,
    note: note,
    link: link ?? '',
    isEditing: isEditing,
    pickPlace: pickPlace,
    place: place,
    address: address,
  ),
);

/// [shop]に願を掛ける。きっかけ・ひとことを尋ね、書き留めたら知らせる。
Future<void> addWishFor(
  BuildContext context,
  WidgetRef ref,
  ShopInput shop,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(wishRepositoryProvider);
  final now = ref.read(clockProvider)();
  final text = await showWishDialog(context, name: shop.name);
  if (text == null) return;
  try {
    await repository.addWish(
      shop: shop,
      trigger: text.trigger,
      note: text.note,
      link: text.link,
      now: now,
    );
    messenger.showSnackBar(SnackBar(content: Text(l10n.wishAdded(shop.name))));
  } catch (e, st) {
    reportError(e, st, reason: 'Wish save failed');
    messenger.showSnackBar(SnackBar(content: Text(l10n.wishSaveFailed)));
  }
}

/// 店名から願を掛ける（願掛け帳の絵馬・ほかのアプリの共有から）。書き留めたら店名を返す。
Future<String?> addWishByName(
  BuildContext context,
  WidgetRef ref, {
  String name = '',
  String trigger = '',
  String? link,
  WishPlace? place,
  String? address,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(wishRepositoryProvider);
  final now = ref.read(clockProvider)();
  final text = await showWishDialog(
    context,
    initialName: name,
    trigger: trigger,
    link: link,
    pickPlace: true,
    place: place,
    address: address,
  );
  if (text == null) return null;
  final chosen = text.place;
  try {
    await repository.addWish(
      shop: ShopInput(
        name: text.name,
        osmId: chosen?.osmId,
        latitude: chosen?.location.latitude,
        longitude: chosen?.location.longitude,
        dataSource: chosen?.dataSource,
      ),
      trigger: text.trigger,
      note: text.note,
      link: text.link,
      now: now,
    );
  } catch (e, st) {
    reportError(e, st, reason: 'Wish save failed');
    messenger.showSnackBar(SnackBar(content: Text(l10n.wishSaveFailed)));
    return null;
  }
  messenger.showSnackBar(SnackBar(content: Text(l10n.wishAdded(text.name))));
  return text.name;
}

class _WishDialog extends ConsumerStatefulWidget {
  const _WishDialog({
    required this.name,
    required this.initialName,
    required this.trigger,
    required this.note,
    required this.link,
    required this.isEditing,
    required this.pickPlace,
    required this.place,
    required this.address,
  });

  final String? name;
  final String initialName;
  final String trigger;
  final String note;
  final String link;
  final bool isEditing;
  final bool pickPlace;
  final WishPlace? place;
  final String? address;

  @override
  ConsumerState<_WishDialog> createState() => _WishDialogState();
}

enum _PlaceFrom { link, address, search, map }

class _WishDialogState extends ConsumerState<_WishDialog> {
  late final _name = TextEditingController(
    text: widget.name ?? widget.initialName,
  );
  late final _trigger = TextEditingController(text: widget.trigger);
  late final _note = TextEditingController(text: widget.note);
  late final _link = TextEditingController(text: widget.link);
  late WishPlace? _place = widget.place;
  late _PlaceFrom? _placeFrom = widget.place == null ? null : _PlaceFrom.link;
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (widget.pickPlace && _place == null && address != null) {
      _geocode(address);
    }
  }

  Future<void> _geocode(String address) async {
    setState(() => _geocoding = true);
    final point = await ref.read(addressGeocoderProvider)(address);
    if (!mounted) return;
    setState(() {
      _geocoding = false;
      // 調べている間に店名や地図で決めていれば、そちらを優先する。
      if (point != null && _place == null) {
        _place = WishPlace(location: point);
        _placeFrom = _PlaceFrom.address;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _trigger.dispose();
    _note.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _searchByName() async {
    final found = await showShopNameSearch(
      context,
      initialName: _name.text.trim(),
      near: _place?.location,
    );
    if (found == null || !mounted) return;
    setState(() {
      _name.text = found.name;
      _place = WishPlace(
        location: found.location,
        osmId: found.osmId,
        dataSource: found.dataSource,
      );
      _placeFrom = _PlaceFrom.search;
    });
  }

  Future<void> _pickOnMap() async {
    final picked = await showLocationPicker(
      context,
      shopName: _name.text.trim(),
      initial: _place?.location,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _place = WishPlace(location: picked);
      _placeFrom = _PlaceFrom.map;
    });
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final link = _link.text.trim();
    Navigator.of(context).pop(
      WishText(
        name: name,
        trigger: _trigger.text.trim(),
        note: _note.text.trim(),
        link: link.isEmpty ? null : link,
        place: widget.pickPlace ? _place : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fixedName = widget.name;
    return AlertDialog(
      title: Text(widget.isEditing ? l10n.wishEditTitle : l10n.wishAddTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fixedName != null)
              Text(fixedName, style: Theme.of(context).textTheme.titleMedium)
            else
              TextField(
                controller: _name,
                autofocus: _name.text.isEmpty,
                decoration: InputDecoration(labelText: l10n.wishShopName),
                onChanged: (_) => setState(() {}),
              ),
            if (widget.pickPlace) ...[
              const SizedBox(height: 8),
              Text(switch ((_geocoding, _placeFrom)) {
                (true, null) => l10n.wishPlaceLooking,
                (_, null) => l10n.wishPlaceNone,
                (_, _PlaceFrom.link) => l10n.wishPlaceFromLink,
                (_, _PlaceFrom.address) => l10n.wishPlaceFromAddress,
                (_, _PlaceFrom.search) => l10n.wishPlaceFromSearch,
                (_, _PlaceFrom.map) => l10n.locationPicked,
              }, style: Theme.of(context).textTheme.bodySmall),
              Wrap(
                children: [
                  FudeLink(
                    icon: const Icon(Icons.travel_explore),
                    onPressed: _searchByName,
                    child: Text(l10n.nameSearchOpen),
                  ),
                  FudeLink(
                    icon: const Icon(Icons.push_pin_outlined),
                    onPressed: _pickOnMap,
                    child: Text(l10n.locationPickOpen),
                  ),
                  if (_place != null)
                    FudeLink(
                      onPressed: () => setState(() {
                        _place = null;
                        _placeFrom = null;
                      }),
                      child: Text(l10n.locationPickClear),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _trigger,
              decoration: InputDecoration(
                labelText: l10n.wishTrigger,
                hintText: l10n.wishTriggerHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.wishNote,
                hintText: l10n.wishNoteHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.wishLink,
                hintText: l10n.wishLinkHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        AiFuda(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: Text(widget.isEditing ? l10n.editSave : l10n.wishAddButton),
        ),
      ],
    );
  }
}
