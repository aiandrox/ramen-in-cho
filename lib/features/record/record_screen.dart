import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../checkin/checkin_controller.dart';
import '../checkin/checkin_rules.dart';
import '../checkin/checkin_screen.dart';
import '../records/clock.dart';
import '../records/date_format.dart';
import '../records/labels.dart';
import '../records/models.dart';
import '../records/visit_details_form.dart';
import '../shop/hours_condition_chips.dart';
import '../shop_search/shop_candidate.dart';
import '../shop_search/shop_search_service.dart';
import '../shop_search/shop_name_search_sheet.dart';
import '../shop_search/shop_tile.dart';
import '../shop_search/yahoo_local.dart';
import 'record_controller.dart';
import 'record_result_screen.dart';
import 'record_state.dart';
import 'star_rating.dart';
import '../../theme/washi_buttons.dart';

/// 保存できたら、得たポイントを見せる画面に切り替わる。
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key, this.recoveredPhotoPath});

  final String? recoveredPhotoPath;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final _nameController = TextEditingController();

  /// 上の部品が出たり消えたりしても店名の欄が作り直されないよう、同じ鍵で持ち続ける
  /// （作り直されると、日本語入力の変換中の文字が1文字目で確定してしまうため）。
  final _nameFieldKey = GlobalKey();
  final _memoController = TextEditingController();
  final _waitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(recordControllerProvider.notifier)
          .start(recoveredPhotoPath: widget.recoveredPhotoPath);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    _waitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final visitId = await ref.read(recordControllerProvider.notifier).save();
    if (!mounted) return;
    if (visitId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RecordResultScreen(visitId: visitId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).recordSaveFailed)),
      );
    }
  }

  /// まだ食べていないので記録はせず、並び始めて印帳に戻る。
  Future<void> _startCheckin() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final shopName = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const CheckinScreen()),
    );
    if (shopName == null || !mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.checkinDone(shopName))));
  }

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardTitle),
        content: Text(l10n.discardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.discardCancel),
          ),
          KeshiFuda(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.discardConfirm),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _selectShop(ShopCandidate shop) {
    _nameController.clear();
    FocusScope.of(context).unfocus();
    ref.read(recordControllerProvider.notifier).selectShop(shop);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordControllerProvider);

    return PopScope(
      canPop: !state.hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: _buildScaffold(context, state),
    );
  }

  Widget _buildScaffold(BuildContext context, RecordState state) {
    final l10n = AppLocalizations.of(context);
    final showCheckinStart =
        !state.hasInput &&
        ref.watch(activeCheckinProvider) is AsyncData<Checkin?> &&
        ref.watch(activeCheckinProvider).value == null;
    final controller = ref.read(recordControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 何か入れたあとは食べた記録なので出さない（並び始めると入力が消えるため）。
          // 消えても下の部品の並びがずれないよう、場所は常に1つ取っておく。
          if (showCheckinStart)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SumiFuda(
                expand: true,
                onPressed: _startCheckin,
                icon: const Icon(Icons.groups),
                child: Text(l10n.checkinStart),
              ),
            )
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
          const SizedBox(height: 16),
          _FoldSection(
            initiallyExpanded: true,
            title: l10n.optionalSection,
            children: [
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
              ),
            ],
          ),
          // 店の条件は行く前（願掛け・店のページ）に入れる。ここでは閉じておき、入っている条件だけ見せる。
          _FoldSection(
            title: l10n.shopConditionsSection,
            subtitle: Text(
              state.hoursConditions.isEmpty
                  ? l10n.shopConditionsEmpty
                  : state.chosenHoursConditions == null &&
                        (state.selectedShop?.conditionsFromMap ?? false)
                  ? l10n.shopConditionsFromMap(
                      hoursConditionsLabel(l10n, state.hoursConditions),
                    )
                  : hoursConditionsLabel(l10n, state.hoursConditions),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: HoursConditionChips(
                  selected: state.hoursConditions,
                  onChanged: controller.setHoursConditions,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
    );
  }
}

/// 開け閉めできる欄。入力欄の枠と紛れないよう、開いても上下に線を引かない。
class _FoldSection extends StatelessWidget {
  const _FoldSection({
    required this.title,
    this.subtitle,
    this.initiallyExpanded = false,
    required this.children,
  });

  final String title;
  final Widget? subtitle;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: Washi.ai,
      collapsedIconColor: Washi.inkSoft,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: Washi.brush,
          fontSize: 20,
          color: Washi.ink,
        ),
      ),
      subtitle: subtitle,
      children: children,
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
          PastedPhoto(
            border: 6,
            child: SizedBox(
              height: 220,
              child: Image.file(File(photoPath), fit: BoxFit.cover),
            ),
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
        for (final shop in shops)
          ShopTile(
            shop: shop,
            selected: identical(shop, checkinShop)
                ? state.isCheckinShopSelected
                : identical(shop, selected),
            note: checkin != null && identical(shop, checkinShop)
                ? l10n.checkinWaiting(
                    checkinElapsedMinutes(
                      checkin,
                      state.photoTakenAt ?? ref.watch(currentTimeProvider),
                    ),
                  )
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
              child: Text(l10n.nameSearchOpen(state.manualName.trim())),
              onPressed: () async {
                final found = await showShopNameSearch(
                  context,
                  initialName: state.manualName,
                  near: controller.searchCenter,
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
              },
            ),
          ),
      ],
    );
  }

  String? _message(AppLocalizations l10n) {
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
