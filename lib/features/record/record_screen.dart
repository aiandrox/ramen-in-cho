import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';
import '../credits/source_credit.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/safe_bottom.dart';
import '../../theme/washi.dart';
import '../checkin/checkin_rules.dart';
import '../map/location_picker_screen.dart';
import '../records/clock.dart';
import '../records/date_format.dart';
import '../records/models.dart';
import '../records/photo_round_button.dart';
import '../records/visit_details_form.dart';
import '../shop_search/shop_candidate.dart';
import '../shop_search/shop_search_service.dart';
import '../shop_search/shop_name_search_sheet.dart';
import '../shop_search/shop_tile.dart';
import 'record_controller.dart';
import '../wishes/shared_wish.dart';
import 'record_draft.dart';
import 'record_result_screen.dart';
import 'record_state.dart';
import 'star_rating.dart';
import '../../theme/washi_buttons.dart';

/// 保存できたら、得たポイントを見せる画面に切り替わる。
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({
    super.key,
    this.recoveredPhotoPath,
    this.sharedPhoto = false,
    this.arrivedAt,
    this.sharedPlace,
  });

  /// 開いたときに使う写真（取り戻した写真・ほかのアプリから共有された写真）。
  final String? recoveredPhotoPath;

  /// [recoveredPhotoPath]がほかのアプリから共有された写真か。
  final bool sharedPhoto;

  /// 並んでいる最中に真ん中の「着」を押した時刻。
  final DateTime? arrivedAt;

  /// 地図アプリから共有された店。その店を選んだ状態で始める。
  final SharedWish? sharedPlace;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final _nameController = TextEditingController();

  /// 上の部品が出たり消えたりしても店名の欄が作り直されないよう、同じ鍵で持ち続ける
  /// （作り直されると、日本語入力の変換中の文字が1文字目で確定してしまうため）。
  final _nameFieldKey = GlobalKey();
  final _memoController = TextEditingController();
  final _shopMemoController = TextEditingController();
  final _waitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  /// 写真を渡されて開いたときに下書きが残っていれば、どちらで記録するか先に確かめる。
  Future<void> _start() async {
    final controller = ref.read(recordControllerProvider.notifier);
    final photo = widget.recoveredPhotoPath;
    var startOver = false;
    // カメラの最中にアプリが終わらされて取り戻した写真は、「着」を押したときの下書きの続き。
    final continuesArrival =
        photo != null &&
        !widget.sharedPhoto &&
        await controller.draftAwaitsArrivalPhoto();
    if (!mounted) return;
    final brought =
        (photo != null && !continuesArrival) || widget.sharedPlace != null;
    if (brought && await controller.hasDraft()) {
      if (!mounted) return;
      startOver = await _askStartOver();
      if (!mounted) return;
    }
    await controller.start(
      recoveredPhotoPath: photo,
      sharedPhoto: widget.sharedPhoto,
      startOver: startOver,
      arrivedAt: widget.arrivedAt,
      sharedPlace: widget.sharedPlace,
    );
  }

  /// 下書きを破棄して新しく記録するならtrue。
  Future<bool> _askStartOver() async {
    final l10n = AppLocalizations.of(context);
    final startOver = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.draftDiscardTitle),
        content: Text(l10n.draftDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.draftDiscardCancel),
          ),
          KeshiFuda(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.draftDiscardConfirm),
          ),
        ],
      ),
    );
    return startOver == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    _shopMemoController.dispose();
    _waitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = ref.read(recordControllerProvider.notifier);
    final visitId = await controller.save();
    if (!mounted) return;
    if (visitId != null) {
      final summary = controller.lastSaveSummary;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              RecordResultScreen(visitId: visitId, saveSummary: summary),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).recordSaveFailed)),
      );
    }
  }

  Future<void> _confirmDiscardDraft() async {
    if (!await _askStartOver() || !mounted) return;
    _nameController.clear();
    _memoController.clear();
    _shopMemoController.clear();
    _waitController.clear();
    FocusScope.of(context).unfocus();
    await ref.read(recordControllerProvider.notifier).discardDraft();
  }

  /// 下書きから再開したら、入力欄にも戻す。
  void _fillFromDraft(RecordState state) {
    _nameController.text = state.manualName;
    _memoController.text = state.memo;
    _waitController.text = state.manualWaitMinutes?.toString() ?? '';
  }

  void _selectShop(ShopCandidate shop) {
    _nameController.clear();
    FocusScope.of(context).unfocus();
    ref.read(recordControllerProvider.notifier).selectShop(shop);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordControllerProvider, (previous, next) {
      if (next.resumedFromDraft && !(previous?.resumedFromDraft ?? false)) {
        _fillFromDraft(next);
      }
      // 共有された店名を入れたときも、店名の欄にそろえる（打っている間は欄と同じなので何もしない）。
      if (next.manualName != previous?.manualName &&
          next.manualName != _nameController.text) {
        _nameController.text = next.manualName;
      }
      // 店を選び替えると、店の覚え書きがその店のものに入れ替わる。
      if (next.shopMemo != _shopMemoController.text) {
        _shopMemoController.text = next.shopMemo;
      }
    });
    final state = ref.watch(recordControllerProvider);
    return PopScope(
      canPop: RecordDraft.fromState(state).isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: _buildScaffold(context, state),
    );
  }

  /// 入力したまま閉じようとしたら、下書きに残すか破棄するかを選んでもらう。
  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveRecordTitle),
        content: Text(l10n.leaveRecordMessage),
        // 札の字が長く横に並ぶと窮屈なので、同じ大きさの札を縦に積む。
        actions: [
          FudaRow(
            direction: Axis.vertical,
            children: [
              AiFuda(
                onPressed: () =>
                    Navigator.of(context).pop(_LeaveChoice.keepDraft),
                child: Text(l10n.leaveRecordKeepDraft),
              ),
              KeshiFuda(
                onPressed: () =>
                    Navigator.of(context).pop(_LeaveChoice.discard),
                child: Text(l10n.leaveRecordDiscard),
              ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.leaveRecordCancel),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final navigator = Navigator.of(context);
    if (choice == _LeaveChoice.discard) {
      await ref.read(recordControllerProvider.notifier).abandonDraft();
    } else {
      unawaited(ref.read(analyticsProvider).log(AnalyticsEvents.draftKept));
    }
    // 入力は変えるたびに下書きへ書いてあるので、残すときはそのまま閉じる。
    navigator.pop();
  }

  void _showShopSection() {
    final field = _nameFieldKey.currentContext;
    if (field == null) return;
    Scrollable.ensureVisible(
      field,
      alignment: 0.6,
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildScaffold(BuildContext context, RecordState state) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(recordControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 下の部品の並びがずれないよう、消えても場所を1つ取っておく。
          if (state.resumedFromDraft)
            _DraftNotice(onDiscard: _confirmDiscardDraft)
          else
            const SizedBox.shrink(),
          _PhotoSection(state: state),
          const SizedBox(height: 24),
          SectionTitle(l10n.shopSection, ruled: false),
          _ShopSection(
            state: state,
            nameController: _nameController,
            nameFieldKey: _nameFieldKey,
            onSelect: _selectShop,
          ),
          const SizedBox(height: 24),
          SectionTitle(l10n.ratingSection, ruled: false),
          Center(
            child: StarRating(
              rating: state.rating,
              onChanged: controller.setRating,
            ),
          ),
          const SizedBox(height: 24),
          VisitDetailsForm(
            style: state.style,
            isLimited: state.isLimited,
            memoController: _memoController,
            onStyleChanged: controller.setStyle,
            onLimitedChanged: controller.setLimited,
            onMemoChanged: controller.setMemo,
            // 並んだ店を選んでいれば、待ち時間は並んだ時刻から自動で計算する。
            waitController: state.isCheckinShopSelected
                ? null
                : _waitController,
            onWaitChanged: controller.setWaitMinutes,
            shopMemoController: state.hasShop ? _shopMemoController : null,
            onShopMemoChanged: controller.setShopMemo,
            shopFamous: state.shopFamous,
            onShopFamousChanged: state.hasShop
                ? controller.setShopFamous
                : null,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeBottomBar(
          // 店が決まらず押せないときは、押すと店の欄まで戻して選び方の案内を見せる。
          child: GestureDetector(
            onTap: state.hasShop ? null : _showShopSection,
            child: AiFuda(
              expand: true,
              height: 60,
              fontSize: 26,
              onPressed: state.canSave ? _save : null,
              child: state.isSaving
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(l10n.save),
            ),
          ),
        ),
      ),
    );
  }
}

enum _LeaveChoice { keepDraft, discard }

class _DraftNotice extends StatelessWidget {
  const _DraftNotice({required this.onDiscard});

  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            l10n.draftResumed,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          FudeLink(
            onPressed: onDiscard,
            icon: const Icon(Icons.restart_alt),
            child: Text(l10n.draftDiscard),
          ),
        ],
      ),
    );
  }
}

class _PhotoSection extends ConsumerWidget {
  const _PhotoSection({required this.state});

  final RecordState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(recordControllerProvider.notifier);
    final photoPath = state.photoPath;
    final hasPhoto = photoPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPhoto) ...[
          Stack(
            children: [
              PastedPhoto(
                border: 6,
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: RotatedBox(
                    quarterTurns: state.photoQuarterTurns,
                    child: Image.file(File(photoPath), fit: BoxFit.cover),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: PhotoRoundButton.rotate(
                  context,
                  onPressed: state.isSaving ? null : controller.rotatePhoto,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: FudeLink(
                  onPressed: controller.takePhoto,
                  icon: const Icon(Icons.photo_camera),
                  child: Text(l10n.retakePhoto),
                ),
              ),
              Expanded(
                child: FudeLink(
                  onPressed: controller.pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  child: Text(l10n.pickFromGallery),
                ),
              ),
            ],
          ),
        ] else
          // 写真は任意。片手で押しやすいよう、大きなボタンを2つ並べる。
          Row(
            children: [
              Expanded(
                child: _PhotoButton(
                  icon: Icons.photo_camera,
                  label: l10n.takePhoto,
                  onPressed: controller.takePhoto,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoButton(
                  icon: Icons.photo_library,
                  label: l10n.pickFromGallery,
                  onPressed: controller.pickFromGallery,
                ),
              ),
            ],
          ),
        if (state.photoDateFromPhoto)
          if (state.photoTakenAt case final takenAt?)
            Text(
              l10n.recordPhotoDate(formatDateTime(takenAt)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
      ],
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: FudaStyle.sumi(height: 120, expand: true),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// 店名で見つからない店の場所を、地図で指す（指した場所が手入力の店の位置になる）。
Future<void> pickPinnedLocation(
  BuildContext context,
  WidgetRef ref,
  RecordState state,
) async {
  final controller = ref.read(recordControllerProvider.notifier);
  final picked = await showLocationPicker(
    context,
    shopName: state.manualName.trim(),
    initial: state.pinnedLocation ?? state.photoLocation,
  );
  if (picked != null) controller.setPinnedLocation(picked);
}

/// 地図で場所を指したあとの表示（指し直す・外す）。指すのは「店名から探す」の結果の下から。
class _PinnedLocationLine extends ConsumerWidget {
  const _PinnedLocationLine({required this.state});

  final RecordState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(recordControllerProvider.notifier);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(
          l10n.locationPicked,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        FudeLink(
          onPressed: () => pickPinnedLocation(context, ref, state),
          child: Text(l10n.locationPickRedo),
        ),
        FudeLink(
          onPressed: () => controller.setPinnedLocation(null),
          child: Text(l10n.locationPickClear),
        ),
      ],
    );
  }
}

class _ShopSection extends ConsumerWidget {
  const _ShopSection({
    required this.state,
    required this.nameController,
    required this.nameFieldKey,
    required this.onSelect,
  });

  final RecordState state;
  final TextEditingController nameController;
  final GlobalKey nameFieldKey;
  final ValueChanged<ShopCandidate> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(recordControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final selected = state.selectedShop;
    final checkinShop = state.checkinShop;
    final candidates = [
      for (final shop in state.candidates)
        if (checkinShop == null || !isSameShop(shop, checkinShop)) shop,
    ];
    final shops = [
      ?checkinShop,
      ...candidates,
      if (selected != null &&
          !state.isCheckinShopSelected &&
          !candidates.contains(selected))
        selected,
    ];
    final checkin = state.checkin;
    final message = _message(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.searchStatus == ShopSearchStatus.searching)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text(l10n.shopSearching),
          ),
        if (shops.isNotEmpty &&
            !state.hasShop &&
            state.searchStatus != ShopSearchStatus.searching)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(l10n.shopPickHint, style: textTheme.bodyMedium),
          ),
        for (final shop in shops)
          ShopTile(
            shop: shop,
            selected: identical(shop, checkinShop)
                ? state.isCheckinShopSelected
                : identical(shop, selected),
            note: checkin != null && identical(shop, checkinShop)
                ? _checkinNote(l10n, checkin, ref)
                : null,
            onTap: () => onSelect(shop),
          ),
        if (selected?.strategyMemo case final memo? when memo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(l10n.shopMemoInline(memo), style: textTheme.bodyMedium),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(message, style: textTheme.bodySmall),
          ),
        if (state.searchStatus == ShopSearchStatus.done &&
            state.searchFailure != ShopSearchFailure.noLocation)
          Align(alignment: Alignment.centerRight, child: const SourceCredit()),
        const SizedBox(height: 8),
        TextField(
          key: nameFieldKey,
          controller: nameController,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.shopNameLabel,
            hintText: l10n.shopNameHint,
          ),
          onChanged: controller.setManualName,
        ),
        for (final shop in state.nameMatches)
          ShopTile(shop: shop, selected: false, onTap: () => onSelect(shop)),
        if (state.manualName.trim().isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: FudeLink(
              icon: const Icon(Icons.travel_explore),
              child: Text(l10n.nameSearchOpen),
              onPressed: () async {
                final found = await showShopNameSearch(
                  context,
                  initialName: state.manualName,
                  near: controller.searchCenter,
                  onPickOnMap: () => pickPinnedLocation(context, ref, state),
                );
                if (found == null) return;
                onSelect(
                  ShopCandidate(
                    osmId: found.osmId,
                    name: found.name,
                    location: found.location,
                    dataSource: found.dataSource,
                  ),
                );
                controller.markPickedByNameSearch();
              },
            ),
          ),
        if (state.pinnedLocation != null && state.manualName.trim().isNotEmpty)
          _PinnedLocationLine(state: state),
      ],
    );
  }

  /// 「着」を押していれば待ち時間はもう決まっているので、その分数を出す。
  String _checkinNote(AppLocalizations l10n, Checkin checkin, WidgetRef ref) {
    final arrivedAt = state.arrivedAt;
    if (arrivedAt != null) {
      return l10n.waitTime(checkinElapsedMinutes(checkin, arrivedAt));
    }
    return l10n.checkinWaiting(
      checkinElapsedMinutes(
        checkin,
        state.photoTakenAt ?? ref.watch(currentTimeProvider),
      ),
    );
  }

  String? _message(AppLocalizations l10n) {
    if (state.searchStatus == ShopSearchStatus.idle &&
        state.photoPath == null &&
        !state.hasShop) {
      return l10n.shopSearchAfterPhoto;
    }
    // 店が決まっていれば、店名の入力を促す案内は要らない。
    if (state.searchStatus != ShopSearchStatus.done || state.hasShop) {
      return null;
    }
    return switch (state.searchFailure) {
      ShopSearchFailure.noLocation => l10n.shopNoLocation,
      ShopSearchFailure.searchFailed when state.candidates.isEmpty =>
        l10n.shopSearchFailed,
      ShopSearchFailure.searchFailed => l10n.shopSearchPartial,
      null when state.candidates.isEmpty => l10n.shopNoCandidates,
      _ => null,
    };
  }
}
