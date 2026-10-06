import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/safe_bottom.dart';
import '../../theme/washi.dart';
import '../../l10n/app_localizations.dart';
import '../record/photo_picker.dart';
import '../record/star_rating.dart';
import '../records/clock.dart';
import '../records/date_format.dart';
import '../records/models.dart';
import '../records/photo_storage.dart';
import '../records/record_repository.dart';
import '../records/visit_details_form.dart';
import '../records/visit_photo.dart';
import '../records/wait_time.dart';
import '../../theme/washi_buttons.dart';
import '../shop_search/shop_candidate.dart';
import 'photo_edit.dart';
import 'shop_repick_sheet.dart';

class VisitEditScreen extends ConsumerStatefulWidget {
  const VisitEditScreen({super.key, required this.entry});

  final VisitWithShop entry;

  @override
  ConsumerState<VisitEditScreen> createState() => _VisitEditScreenState();
}

class _VisitEditScreenState extends ConsumerState<VisitEditScreen> {
  late final _nameController = TextEditingController(
    text: widget.entry.shop.name,
  );
  late final _memoController = TextEditingController(
    text: widget.entry.visit.memo,
  );
  late final _shopMemoController = TextEditingController(
    text: widget.entry.shop.strategyMemo,
  );

  /// 店の覚え書きの欄に入れた、もとの覚え書き。書き換えたときだけ店に保存する。
  late String _shopMemoOriginal = widget.entry.shop.strategyMemo;
  late final _waitController = TextEditingController(
    text: waitMinutes(widget.entry.visit)?.toString() ?? '',
  );
  late DateTime _eatenAt = widget.entry.visit.eatenAt;
  late int? _rating = widget.entry.visit.rating;
  late RamenStyle? _style = widget.entry.visit.style;
  late bool _isLimited = widget.entry.visit.isLimited;
  late final _photo = PhotoEdit(
    ref.read(photoStorageProvider),
    original: widget.entry.visit.photoPath,
  );
  bool _isSaving = false;
  bool _isPickingPhoto = false;

  /// 候補や店名検索で選び直した店。店名を書き換えたら外す。
  ShopCandidate? _pickedShop;

  @override
  void dispose() {
    unawaited(_discardPhoto());
    _nameController.dispose();
    _memoController.dispose();
    _shopMemoController.dispose();
    _waitController.dispose();
    super.dispose();
  }

  Future<void> _discardPhoto() async {
    try {
      await _photo.discard();
    } catch (e) {
      debugPrint('Photo discard failed: $e');
    }
  }

  Future<void> _changePhoto(Future<String?> Function(PhotoPicker) pick) async {
    setState(() => _isPickingPhoto = true);
    try {
      final path = await pick(ref.read(photoPickerProvider));
      if (path != null) await _photo.replace(path);
      // 写真を選んでいる間に画面を閉じたら、コピーした写真を残さない。
      if (!mounted) await _discardPhoto();
    } catch (e) {
      debugPrint('Photo change failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).editPhotoFailed)),
        );
      }
    }
    if (mounted) setState(() => _isPickingPhoto = false);
  }

  Future<void> _removePhoto() async {
    await _photo.remove();
    if (mounted) setState(() {});
  }

  Future<void> _repickShop() async {
    final picked = await showShopRepick(
      context,
      shop: widget.entry.shop,
      photoPath: _photo.current ?? widget.entry.visit.photoPath,
      name: _nameController.text.trim(),
    );
    if (picked == null || !mounted) return;
    final isCurrentShop = picked.shopId == widget.entry.shop.id;
    // 店を選び直したら、店の覚え書きはその店のものに入れ替える。
    final memo = isCurrentShop
        ? widget.entry.shop.strategyMemo
        : await _shopMemoOf(picked);
    if (!mounted) return;
    setState(() {
      _pickedShop = isCurrentShop ? null : picked;
      _nameController.text = picked.name;
      _shopMemoController.text = memo;
      _shopMemoOriginal = memo;
    });
  }

  /// 店名を打ち直して別の店になりそうなときは、どの店の覚え書きかわからないので欄を押せなくする
  /// （選び直した店か、もとの店のときだけ書ける）。
  bool get _shopMemoShown =>
      _pickedShop != null ||
      _nameController.text.trim() == widget.entry.shop.name;

  /// 検索の候補は覚え書きを持たないので、記録済みの店なら店から引く。
  Future<String> _shopMemoOf(ShopCandidate shop) async {
    final shopId = shop.shopId;
    if (shop.strategyMemo.isNotEmpty || shopId == null) {
      return shop.strategyMemo;
    }
    try {
      final shops = await ref.read(recordRepositoryProvider).allShops();
      return shops.where((s) => s.id == shopId).firstOrNull?.strategyMemo ?? '';
    } catch (e) {
      debugPrint('Shop memo load failed: $e');
      return '';
    }
  }

  void _onNameChanged(String name) {
    setState(() {
      if (_pickedShop?.name != name.trim()) _pickedShop = null;
    });
  }

  ShopInput? _pickedShopInput() {
    final picked = _pickedShop;
    if (picked == null) return null;
    return ShopInput(
      shopId: picked.shopId,
      osmId: picked.osmId,
      name: picked.name,
      latitude: picked.location?.latitude,
      longitude: picked.location?.longitude,
      dataSource: picked.dataSource,
      wishId: picked.wishId,
      locationPinned: picked.locationPinned,
    );
  }

  Future<void> _pickEatenAt() async {
    final now = ref.read(clockProvider)();
    final date = await showDatePicker(
      context: context,
      initialDate: _eatenAt,
      firstDate: DateTime(2000),
      lastDate: now.isAfter(_eatenAt) ? now : _eatenAt,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eatenAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _eatenAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  /// 待ち時間に触っていなければ、並んだ時刻を食べた日時と一緒にずらすだけにする
  /// （秒や0分の待ち時間を保つため）。撤退の記録は待ち時間を入れないので変えない。
  DateTime? _checkedInAt() {
    final original = widget.entry.visit;
    final checkedInAt = original.checkedInAt;
    final initialText = waitMinutes(original)?.toString() ?? '';
    if (original.result != VisitResult.eaten ||
        _waitController.text == initialText) {
      return checkedInAt?.add(_eatenAt.difference(original.eatenAt));
    }
    final minutes = parseWaitMinutes(_waitController.text);
    return minutes == null
        ? null
        : _eatenAt.subtract(Duration(minutes: minutes));
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final unusedPhoto = await ref
          .read(recordRepositoryProvider)
          .updateVisit(
            visitId: widget.entry.visit.id,
            shopName: _nameController.text,
            pickedShop: _pickedShopInput(),
            eatenAt: _eatenAt,
            checkedInAt: _checkedInAt(),
            rating: _rating,
            style: _style,
            isLimited: _isLimited,
            hasTicket: widget.entry.visit.hasTicket,
            memo: _memoController.text.trim(),
            shopMemo:
                !_shopMemoShown ||
                    _shopMemoController.text.trim() == _shopMemoOriginal.trim()
                ? null
                : _shopMemoController.text.trim(),
            changesPhoto: _photo.isChanged,
            photoPath: _photo.current,
            now: ref.read(clockProvider)(),
          );
      try {
        await _photo.commit(unusedPhoto);
      } catch (e) {
        debugPrint('Old photo delete failed: $e');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Visit update failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).editSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEaten = widget.entry.visit.result == VisitResult.eaten;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _PhotoSection(
            photoPath: _photo.current,
            enabled: !_isPickingPhoto && !_isSaving,
            onTakePhoto: () => _changePhoto((picker) => picker.takePhoto()),
            onPickFromGallery: () =>
                _changePhoto((picker) => picker.pickFromGallery()),
            onRemove: _removePhoto,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l10n.editShopName),
            onChanged: _onNameChanged,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FudeLink(
              icon: const Icon(Icons.storefront),
              onPressed: _isSaving ? null : _repickShop,
              child: Text(l10n.editShopRepick),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(l10n.editEatenAt),
            subtitle: Text(formatDateTime(_eatenAt)),
            onTap: _pickEatenAt,
          ),
          if (isEaten) ...[
            const SizedBox(height: 16),
            SectionTitle(l10n.ratingSection, ruled: false),
            Center(
              child: StarRating(
                rating: _rating,
                onChanged: (rating) => setState(() => _rating = rating),
              ),
            ),
          ],
          const SizedBox(height: 24),
          VisitDetailsForm(
            style: _style,
            isLimited: _isLimited,
            memoController: _memoController,
            onStyleChanged: (style) => setState(() => _style = style),
            onLimitedChanged: (value) => setState(() => _isLimited = value),
            onMemoChanged: (_) {},
            waitController: isEaten ? _waitController : null,
            shopMemoController: _shopMemoShown ? _shopMemoController : null,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeBottomBar(
          child: AiFuda(
            expand: true,
            height: 56,
            onPressed:
                _isSaving ||
                    _isPickingPhoto ||
                    _nameController.text.trim().isEmpty
                ? null
                : _save,
            child: Text(l10n.editSave),
          ),
        ),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photoPath,
    required this.enabled,
    required this.onTakePhoto,
    required this.onPickFromGallery,
    required this.onRemove,
  });

  final String? photoPath;
  final bool enabled;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPhoto = photoPath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPhoto)
          Stack(
            clipBehavior: Clip.none,
            children: [
              PastedPhoto(
                border: 6,
                child: SizedBox(
                  height: 200,
                  child: VisitPhoto(photoPath: photoPath, cacheWidth: 800),
                ),
              ),
              // 写真の角から少しはみ出させ、写真に重ならず「外す」ものだとわかるようにする。
              Positioned(
                top: -10,
                right: -10,
                child: IconButton.filled(
                  onPressed: enabled ? onRemove : null,
                  tooltip: l10n.editRemovePhoto,
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Washi.ink,
                    foregroundColor: Washi.page,
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ),
            ],
          ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            FudeLink(
              onPressed: enabled ? onTakePhoto : null,
              icon: const Icon(Icons.photo_camera),
              child: Text(hasPhoto ? l10n.retakePhoto : l10n.takePhoto),
            ),
            FudeLink(
              onPressed: enabled ? onPickFromGallery : null,
              icon: const Icon(Icons.photo_library),
              child: Text(l10n.pickFromGallery),
            ),
          ],
        ),
      ],
    );
  }
}
