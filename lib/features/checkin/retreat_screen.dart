import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi_buttons.dart';
import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';
import '../credits/source_credit.dart';
import '../error_reporting/error_reporting.dart';
import '../records/clock.dart';
import '../records/models.dart';
import '../records/record_repository.dart';
import '../shop_search/found_shop.dart';
import '../shop_search/shop_candidate.dart';
import '../shop_search/shop_search_service.dart';
import '../shop_search/shop_tile.dart';
import '../wishes/wish_repository.dart';
import '../wishes/wishes.dart';
import 'retreat_dialog.dart';

/// 並ばずに撤退を残す店を選ぶ。撤退は店にいなくても残せるので、距離では絞らない。
/// 残せたら、その記録とメモを返して閉じる。
class RetreatScreen extends ConsumerStatefulWidget {
  const RetreatScreen({super.key});

  @override
  ConsumerState<RetreatScreen> createState() => _RetreatScreenState();
}

typedef RetreatSaved = ({Visit visit, String memo});

class _RetreatScreenState extends ConsumerState<RetreatScreen> {
  final _nameController = TextEditingController();
  ShopSearchResult? _result;
  List<Shop> _knownShops = const [];
  List<Wish> _wishes = const [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final search = ref.read(shopSearchServiceProvider);
    final analytics = ref.read(analyticsProvider);
    try {
      final known = await ref.read(recordRepositoryProvider).allShops();
      final pending = await ref.read(wishRepositoryProvider).pendingWishes();
      if (mounted) {
        setState(() {
          _knownShops = known;
          _wishes = pending;
        });
      }
    } catch (e) {
      debugPrint('Retreat shops load failed: $e');
    }
    final result = await search.search(requestPermission: true);
    unawaited(
      analytics.log(
        AnalyticsEvents.shopSearch(purpose: 'retreat', result: result),
      ),
    );
    if (mounted) setState(() => _result = result);
  }

  Future<void> _retreat(ShopCandidate? shop) async {
    final name = shop?.name ?? _nameController.text.trim();
    if (name.isEmpty || _isSaving) return;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(recordRepositoryProvider);
    final analytics = ref.read(analyticsProvider);
    final now = ref.read(clockProvider)();
    final memo = await showRetreatDialog(context);
    if (memo == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final visit = await repository.saveRetreatAt(
        shop: ShopInput(
          shopId: shop?.shopId,
          osmId: shop?.osmId,
          name: name,
          latitude: shop?.location?.latitude,
          longitude: shop?.location?.longitude,
          dataSource: shop?.dataSource,
          wishId: shop?.wishId,
        ),
        memo: memo,
        wishTrigger: l10n.wishTriggerRetreat,
        now: now,
      );
      unawaited(
        analytics.log(
          AnalyticsEvents.retreatRecorded(shopSource: shopSourceOf(shop)),
        ),
      );
      navigator.pop<RetreatSaved>((visit: visit, memo: memo));
    } catch (e, st) {
      reportError(e, st, reason: 'Retreat save failed');
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.retreatFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final result = _result;
    final candidates = result?.candidates ?? const <ShopCandidate>[];
    final query = normalizeShopName(_nameController.text);
    final matches = query.isEmpty
        ? const <ShopCandidate>[]
        : shopNameMatches(query, wishes: _wishes, knownShops: _knownShops);
    final message = _message(l10n, result);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.retreatPickTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (result == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text(l10n.shopSearching),
            )
          else if (candidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(l10n.retreatPickHint, style: textTheme.bodyMedium),
            ),
          for (final shop in candidates)
            ShopTile(
              shop: shop,
              selected: false,
              onTap: _isSaving ? null : () => _retreat(shop),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(message, style: textTheme.bodyMedium),
            ),
          if (result != null && result.here != null)
            Align(
              alignment: Alignment.centerRight,
              child: const SourceCredit(),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.shopNameLabel,
              hintText: l10n.shopNameHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          for (final shop in matches)
            ShopTile(
              shop: shop,
              selected: false,
              onTap: _isSaving ? null : () => _retreat(shop),
            ),
          const SizedBox(height: 8),
          SumiFuda(
            onPressed: !_isSaving && _nameController.text.trim().isNotEmpty
                ? () => _retreat(null)
                : null,
            child: Text(l10n.retreatManualButton),
          ),
        ],
      ),
    );
  }

  String? _message(AppLocalizations l10n, ShopSearchResult? result) {
    if (result == null) return null;
    return switch (result.failure) {
      ShopSearchFailure.noLocation => l10n.shopNoLocation,
      ShopSearchFailure.searchFailed when result.candidates.isEmpty =>
        l10n.shopSearchFailed,
      ShopSearchFailure.searchFailed => l10n.shopSearchPartial,
      null when result.candidates.isEmpty => l10n.shopNoCandidates,
      _ => null,
    };
  }
}
