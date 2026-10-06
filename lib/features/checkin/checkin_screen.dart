import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../shop_search/shop_candidate.dart';
import '../shop_search/shop_search_service.dart';
import '../shop_search/shop_tile.dart';
import 'checkin_controller.dart';
import 'checkin_rules.dart';
import '../../theme/washi_buttons.dart';

/// チェックインできたら、店名を返して閉じる。
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(checkinControllerProvider.notifier).search();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish(Future<bool> checkin, String shopName) async {
    final done = await checkin;
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop(shopName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).checkinFailed)),
      );
    }
  }

  void _checkIn(ShopCandidate shop) {
    final controller = ref.read(checkinControllerProvider.notifier);
    _finish(controller.checkIn(shop), shop.name);
  }

  void _checkInManually() {
    final name = _nameController.text.trim();
    final controller = ref.read(checkinControllerProvider.notifier);
    _finish(controller.checkInManually(name), name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(checkinControllerProvider);
    final result = state.result;
    final textTheme = Theme.of(context).textTheme;
    final message = _message(l10n, result);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkinTitle)),
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
            ),
          if (result != null) ...[
            for (final shop in result.candidates)
              ShopTile(
                shop: shop,
                selected: false,
                note: canCheckIn(shop.distanceMeters)
                    ? null
                    : l10n.checkinTooFar,
                onTap: canCheckIn(shop.distanceMeters) && !state.isSaving
                    ? () => _checkIn(shop)
                    : null,
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(message, style: textTheme.bodyMedium),
              ),
            if (result.here == null)
              Align(
                alignment: Alignment.centerLeft,
                child: SumiFuda(
                  onPressed: ref
                      .read(checkinControllerProvider.notifier)
                      .search,
                  icon: const Icon(Icons.refresh),
                  child: Text(l10n.checkinRetry),
                ),
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  [
                    l10n.shopSearchAttribution,
                    l10n.yahooAttribution,
                  ].join('\n'),
                  style: textTheme.labelSmall,
                ),
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
              const SizedBox(height: 8),
              SumiFuda(
                onPressed:
                    state.canCheckInManually &&
                        _nameController.text.trim().isNotEmpty
                    ? _checkInManually
                    : null,
                child: Text(l10n.checkinManualButton),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String? _message(AppLocalizations l10n, ShopSearchResult? result) {
    if (result == null) return null;
    return switch (result.failure) {
      ShopSearchFailure.noLocation => l10n.checkinNoLocation,
      ShopSearchFailure.searchFailed when result.candidates.isEmpty =>
        l10n.checkinSearchFailed,
      ShopSearchFailure.searchFailed => l10n.shopSearchPartial,
      null when result.candidates.isEmpty => l10n.checkinNoCandidates,
      _ => null,
    };
  }
}
