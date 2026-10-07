import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../records/clock.dart';
import '../records/record_repository.dart';
import 'queue_suggestion.dart';
import '../../theme/washi_buttons.dart';
import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';

/// 店の近くでアプリを開いたときの「〇〇に並んだ？」。1タップで並び始める。
class QueueSuggestionCard extends ConsumerStatefulWidget {
  const QueueSuggestionCard({super.key});

  @override
  ConsumerState<QueueSuggestionCard> createState() =>
      _QueueSuggestionCardState();
}

class _QueueSuggestionCardState extends ConsumerState<QueueSuggestionCard> {
  late final _lifecycle = AppLifecycleListener(
    // アプリに戻ってきたときにも、今いる場所で聞き直す。
    onResume: () => ref.invalidate(queueSuggestionProvider),
  );

  /// ×で閉じた店。アプリを開き直すまでは聞かない。
  final _dismissed = <String>{};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shop = ref.watch(queueSuggestionProvider).value;
    if (shop == null || _dismissed.contains(shop.name)) {
      return const SizedBox.shrink();
    }

    Future<void> checkIn() async {
      final messenger = ScaffoldMessenger.of(context);
      final repository = ref.read(recordRepositoryProvider);
      setState(() => _isSaving = true);
      try {
        await repository.checkIn(
          shop: ShopInput(
            shopId: shop.shopId,
            osmId: shop.osmId,
            name: shop.name,
            latitude: shop.location?.latitude,
            longitude: shop.location?.longitude,
            dataSource: shop.dataSource,
          ),
          at: ref.read(clockProvider)(),
        );
        final analytics = ref.read(analyticsProvider);
        unawaited(analytics.log(AnalyticsEvents.queueSuggestionAccepted));
        unawaited(
          analytics.log(
            AnalyticsEvents.checkinStarted(
              via: 'suggestion',
              shopSource: shopSourceOf(shop),
            ),
          ),
        );
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.checkinDone(shop.name))),
        );
        ref.invalidate(queueSuggestionProvider);
      } catch (e) {
        debugPrint('Queue suggestion checkin failed: $e');
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.queueSuggestionFailed)),
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }

    return Card(
      elevation: 0,
      color: Washi.page,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Washi.ai),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                shop.wishId != null
                    ? l10n.queueSuggestionWished(shop.name)
                    : l10n.queueSuggestion(shop.name),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            AiFuda(
              height: 48,
              fontSize: 18,
              onPressed: _isSaving ? null : checkIn,
              child: Text(l10n.queueSuggestionYes),
            ),
            IconButton(
              tooltip: l10n.queueSuggestionDismiss,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _dismissed.add(shop.name)),
            ),
          ],
        ),
      ),
    );
  }
}
