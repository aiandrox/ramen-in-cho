import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../inkan/inkan.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../records/clock.dart';
import '../records/record_repository.dart';
import '../scoring/scoring_providers.dart';
import '../visit_detail/visit_detail_screen.dart';
import '../wishes/wish_dialog.dart';
import '../wishes/wish_providers.dart';
import '../words/words.dart';
import 'memory.dart';
import '../../theme/washi_buttons.dart';

/// 一覧の上に、何年か前の今日の1杯をそっと出す。×で閉じる（アプリを開き直すとまた出る）。
class MemoryCard extends ConsumerStatefulWidget {
  const MemoryCard({super.key});

  @override
  ConsumerState<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends ConsumerState<MemoryCard> {
  String? _dismissedVisitId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final memory = memoryOfTheDay(
      ref.watch(scoredVisitsProvider),
      ref.watch(clockProvider)(),
    );
    if (memory == null || memory.scored.visit.id == _dismissedVisitId) {
      return const SizedBox.shrink();
    }
    final shop = memory.scored.shop;
    final canWish =
        memory.notVisitedSince &&
        pendingWishFor(ref.watch(wishStatusesProvider), shop) == null;

    final card = Card(
      elevation: 0,
      color: Washi.page,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Washi.line),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VisitDetailScreen(visitId: memory.scored.visit.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.memoryYearsAgo(proseNumber(memory.yearsAgo)),
                      style: const TextStyle(
                        fontFamily: Washi.brush,
                        fontSize: 16,
                        color: Washi.ai,
                      ),
                    ),
                    Text(
                      l10n.memoryLine(shop.name),
                      style: textTheme.bodyLarge,
                    ),
                    Text(
                      memoryWhisper(memory.scored.visit.id, memory.yearsAgo),
                      style: textTheme.bodyMedium?.copyWith(
                        fontFamily: Washi.brush,
                      ),
                    ),
                    if (memory.notVisitedSince)
                      Text(
                        l10n.memoryNotSince,
                        style: textTheme.bodySmall?.copyWith(
                          color: Washi.inkSoft,
                        ),
                      ),
                    if (canWish)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FudeLink(
                          icon: const Icon(Icons.bookmark_add_outlined),
                          child: Text(l10n.wishMakeButton),
                          onPressed: () => addWishFor(
                            context,
                            ref,
                            ShopInput(
                              shopId: shop.id,
                              osmId: shop.osmId,
                              name: shop.name,
                              latitude: shop.latitude,
                              longitude: shop.longitude,
                              dataSource: shop.dataSource,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 右上の角の閉じるボタンのぶん、文字を少し離す。
              const SizedBox(width: 28),
            ],
          ),
        ),
      ),
    );
    return Stack(
      children: [
        card,
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            tooltip: l10n.memoryDismiss,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.close),
            onPressed: () =>
                setState(() => _dismissedVisitId = memory.scored.visit.id),
          ),
        ),
      ],
    );
  }
}
