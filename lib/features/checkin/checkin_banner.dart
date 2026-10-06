import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/washi.dart';
import '../../l10n/app_localizations.dart';
import '../error_reporting/error_reporting.dart';
import '../records/clock.dart';
import '../records/models.dart';
import '../records/record_repository.dart';
import 'checkin_rules.dart';
import 'retreat_dialog.dart';
import '../words/words.dart';
import '../../theme/washi_buttons.dart';

/// 並んでいる店と経過時間。取り消しと撤退ができる。
class CheckinBanner extends ConsumerStatefulWidget {
  const CheckinBanner({super.key, required this.checkin});

  final Checkin checkin;

  @override
  ConsumerState<CheckinBanner> createState() => _CheckinBannerState();
}

class _CheckinBannerState extends ConsumerState<CheckinBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    setState(() {});
    if (!isCheckinExpired(widget.checkin, ref.read(clockProvider)())) return;
    try {
      await ref.read(recordRepositoryProvider).cancelCheckin();
    } catch (e) {
      debugPrint('Checkin auto-cancel failed: $e');
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(recordRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.checkinCancelTitle),
        content: Text(l10n.checkinCancelMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.checkinKeep),
          ),
          KeshiFuda(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.checkinCancel),
          ),
        ],
      ),
    );
    if (confirmed == true) await repository.cancelCheckin();
  }

  Future<void> _retreat() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(recordRepositoryProvider);
    final clock = ref.read(clockProvider);
    final memo = await showRetreatDialog(context);
    if (memo == null) return;
    try {
      final visit = await repository.saveRetreat(
        checkin: widget.checkin,
        memo: memo,
        wishTrigger: l10n.wishTriggerRetreat,
        now: clock(),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.retreatSaved}\n${retreatConsolation(memo, visit.id)}',
          ),
        ),
      );
    } catch (e, st) {
      reportError(e, st, reason: 'Retreat save failed');
      messenger.showSnackBar(SnackBar(content: Text(l10n.retreatFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final shopId = widget.checkin.shopId;
    final memo = shopId == null
        ? ''
        : (ref.watch(visitsProvider).value ?? const [])
                  .where((entry) => entry.shop.id == shopId)
                  .firstOrNull
                  ?.shop
                  .strategyMemo ??
              '';
    final minutes = checkinElapsedMinutes(
      widget.checkin,
      ref.watch(currentTimeProvider),
    );

    return Card(
      elevation: 0,
      color: Washi.ink,
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: Washi.paper),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.checkinBanner(widget.checkin.name),
                        style: textTheme.titleMedium?.copyWith(
                          fontFamily: Washi.brush,
                          color: Washi.paper,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n.checkinWaiting(minutes),
                        style: textTheme.bodyMedium?.copyWith(
                          color: Washi.aiLight,
                        ),
                      ),
                      Text(
                        l10n.checkinBannerHint,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Washi.paper,
                        ),
                      ),
                      if (memo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.shopMemoInline(memo),
                            style: textTheme.bodySmall?.copyWith(
                              color: Washi.nightSoft,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FudeLink(
                  night: true,
                  onPressed: _cancel,
                  child: Text(l10n.checkinCancel),
                ),
                const SizedBox(width: 8),
                KeshiFuda(
                  night: true,
                  onPressed: _retreat,
                  child: Text(l10n.retreat),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
