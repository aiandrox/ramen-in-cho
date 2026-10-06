import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/even_grid.dart';
import '../../theme/washi.dart';
import '../inkan/inkan_stamp.dart';
import '../records/date_format.dart';
import '../scoring/scoring_providers.dart';
import '../visit_detail/visit_detail_screen.dart';
import 'regions.dart';

final prefectureStampsProvider = Provider<Map<String, PrefectureStamp>>(
  (ref) => prefectureStamps(ref.watch(scoredVisitsProvider)),
);

/// 海外で食べた記録。まだ一度も無ければnull（隠し要素なので、それまでは印帳に場所も出さない）。
final overseasStampProvider = Provider<PrefectureStamp?>((ref) {
  final bowls = overseasBowls(ref.watch(scoredVisitsProvider));
  return bowls.isEmpty
      ? null
      : PrefectureStamp(first: bowls.first, bowls: bowls);
});

String regionLabel(AppLocalizations l10n, Region region) => switch (region) {
  Region.hokkaido => l10n.prefectureBookRegionHokkaido,
  Region.tohoku => l10n.prefectureBookRegionTohoku,
  Region.kanto => l10n.prefectureBookRegionKanto,
  Region.koshinetsu => l10n.prefectureBookRegionKoshinetsu,
  Region.hokuriku => l10n.prefectureBookRegionHokuriku,
  Region.tokai => l10n.prefectureBookRegionTokai,
  Region.kinki => l10n.prefectureBookRegionKinki,
  Region.chugoku => l10n.prefectureBookRegionChugoku,
  Region.shikoku => l10n.prefectureBookRegionShikoku,
  Region.kyushu => l10n.prefectureBookRegionKyushu,
  Region.okinawa => l10n.prefectureBookRegionOkinawa,
};

/// 都道府県の印帳の升目の、いちばん狭い幅（印と「鹿児島県」が収まる幅）。
const prefectureTileMinWidth = 84.0;

/// 修行タブの入口。集めた都道府県の数を添える。
class PrefectureBookEntry extends ConsumerWidget {
  const PrefectureBookEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final count = ref.watch(prefectureStampsProvider).length;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.prefectureBookTitle),
      subtitle: Text(l10n.prefectureBookOpen),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.prefectureBookProgress(count)),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PrefectureBookScreen()),
      ),
    );
  }
}

/// 都道府県の印帳。地方ごとに47の場所を並べ、食べた都道府県には初めての1杯の印を押す。
class PrefectureBookScreen extends ConsumerWidget {
  const PrefectureBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stamps = ref.watch(prefectureStampsProvider);
    final overseas = ref.watch(overseasStampProvider);
    return Scaffold(
      backgroundColor: Washi.desk,
      appBar: AppBar(
        backgroundColor: Washi.desk,
        title: Text(l10n.prefectureBookTitle),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(l10n.prefectureBookProgress(stamps.length)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Text(
            l10n.prefectureBookNote,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Washi.faded),
          ),
          for (final region in Region.values) ...[
            const SizedBox(height: 20),
            SectionTitle(regionLabel(l10n, region)),
            EvenGrid(
              minItemWidth: prefectureTileMinWidth,
              runSpacing: 12,
              itemCount: prefecturesIn(region).length,
              itemBuilder: (context, index, _) {
                final prefecture = prefecturesIn(region)[index];
                return _PrefectureTile(
                  prefecture: prefecture,
                  stamp: stamps[prefecture],
                );
              },
            ),
          ],
          if (overseas != null) ...[
            const SizedBox(height: 20),
            SectionTitle(l10n.prefectureBookOverseas),
            EvenGrid(
              minItemWidth: prefectureTileMinWidth,
              runSpacing: 12,
              itemCount: 1,
              itemBuilder: (context, index, _) => _PrefectureTile(
                prefecture: l10n.prefectureBookOverseas,
                stamp: overseas,
                overseas: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrefectureTile extends StatelessWidget {
  const _PrefectureTile({
    required this.prefecture,
    required this.stamp,
    this.overseas = false,
  });

  /// 升目の名前（海外の升目では「海外」）。
  final String prefecture;
  final PrefectureStamp? stamp;
  final bool overseas;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stamp = this.stamp;
    final small = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Washi.inkSoft);
    final tile = SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          SizedBox.square(
            dimension: 76,
            child: Center(
              child: stamp == null
                  ? BlankPrefectureSeal(prefecture: prefecture, size: 64)
                  : InkanStamp(scored: stamp.first, size: 72),
            ),
          ),
          const SizedBox(height: 2),
          _fit(
            Text(
              prefecture,
              maxLines: 1,
              style: TextStyle(
                fontFamily: Washi.brush,
                fontSize: 15,
                color: stamp == null ? Washi.faded : Washi.ink,
              ),
            ),
          ),
          if (stamp != null) ...[
            _fit(
              Text(
                l10n.prefectureBookFirst(formatDate(stamp.first.visit.eatenAt)),
                style: small,
              ),
            ),
            Text(l10n.prefectureBookBowls(stamp.bowls.length), style: small),
          ],
        ],
      ),
    );
    if (stamp == null) return tile;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              PrefectureBowlsScreen(prefecture: prefecture, overseas: overseas),
        ),
      ),
      child: tile,
    );
  }
}

/// 狭い升目でも1行に収める。
Widget _fit(Widget child) => FittedBox(fit: BoxFit.scaleDown, child: child);

/// その都道府県（[overseas]なら海外）で食べた1杯の一覧（古い順）。
class PrefectureBowlsScreen extends ConsumerWidget {
  const PrefectureBowlsScreen({
    super.key,
    required this.prefecture,
    this.overseas = false,
  });

  final String prefecture;
  final bool overseas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bowls = overseas
        ? ref.watch(overseasStampProvider)?.bowls ?? []
        : ref.watch(prefectureStampsProvider)[prefecture]?.bowls ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(prefecture)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          for (final scored in bowls)
            ListTile(
              leading: InkanStamp(scored: scored, size: 52),
              title: Text(
                l10n.prefectureBookEntry(
                  formatDate(scored.visit.eatenAt),
                  scored.shop.name,
                ),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VisitDetailScreen(visitId: scored.visit.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
