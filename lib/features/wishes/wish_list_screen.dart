import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/ink_wear.dart';
import '../../theme/washi.dart';
import '../error_reporting/error_reporting.dart';
import '../home/app_tab.dart';
import '../records/clock.dart';
import '../records/date_format.dart';
import '../records/models.dart';
import '../settings/settings_action.dart';
import '../visit_detail/visit_detail_screen.dart';
import 'wish_dialog.dart';
import 'wish_link.dart';
import 'wish_providers.dart';
import 'wish_repository.dart';
import 'wishes.dart';
import '../../theme/washi_buttons.dart';
import '../analytics/analytics_events.dart';

/// 消した願。データベースから消えて一覧が更新されるまでの間も、すぐ隠すため。
final _removedWishIdsProvider = NotifierProvider<_RemovedWishIds, Set<String>>(
  _RemovedWishIds.new,
);

class _RemovedWishIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String id) => state = {...state, id};

  void remove(String id) => state = {...state}..remove(id);
}

/// 願掛け帳。行きたい店（まだの願）と、食べに行けた店（叶った願）を分けて見せる。
class WishListScreen extends ConsumerWidget {
  const WishListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statuses = ref.watch(wishStatusesProvider);
    final removed = ref.watch(_removedWishIdsProvider);
    final pending = [
      for (final status in statuses)
        if (!status.isFulfilled && !removed.contains(status.wish.id)) status,
    ];
    final fulfilled =
        [
          for (final status in statuses)
            if (status.isFulfilled) status,
        ]..sort(
          (a, b) => b.fulfilledBy!.visit.eatenAt.compareTo(
            a.fulfilledBy!.visit.eatenAt,
          ),
        );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        // 願を掛ける窓でキーボードが出ても、後ろの画面（右下の絵馬）を持ち上げない。
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(l10n.wishTitle),
          actions: const [SettingsAction()],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.wishPendingTab(pending.length)),
              Tab(text: l10n.wishFulfilledTab(fulfilled.length)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            pending.isEmpty
                ? _Empty(message: l10n.wishPendingEmpty)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      for (final status in pending)
                        _PendingWishCard(status: status),
                    ],
                  ),
            fulfilled.isEmpty
                ? _Empty(message: l10n.wishFulfilledEmpty)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      for (final status in fulfilled)
                        _FulfilledWishCard(status: status),
                    ],
                  ),
          ],
        ),
        // 真ん中の判子（記録）と取り違えないよう、丸ではなく絵馬の形にする。
        // 判子が下のタブから上へはみ出す分を少しだけ避け、右端に余白をとる。
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(
            right: 4,
            bottom: RecordSealButton.overhang * 0.4,
          ),
          child: EmaFab(
            tooltip: l10n.wishAddTitle,
            onPressed: () =>
                addWishByName(context, ref, source: WishSource.wishBook),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _PendingWishCard extends ConsumerWidget {
  const _PendingWishCard({required this.status});

  final WishStatus status;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final wish = status.wish;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).wishSaveFailed;
    final repository = ref.read(wishRepositoryProvider);
    final text = await showWishDialog(
      context,
      name: wish.name,
      trigger: wish.trigger,
      note: wish.note,
      link: wish.link,
      isEditing: true,
    );
    if (text == null) return;
    try {
      await repository.updateWish(
        wish.id,
        trigger: text.trigger,
        note: text.note,
        link: text.link,
      );
    } catch (e, st) {
      reportError(e, st, reason: 'Wish update failed');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  /// 消してよいか確かめる。消してよければtrue。
  Future<bool> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.wishDeleteConfirm(status.wish.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          KeshiFuda(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// 確かめたあとで消す。窓を開いている間に行が消えても消せるよう、先に取り出しておいたものを使う。
  Future<void> _delete(
    _RemovedWishIds removed,
    WishRepository repository,
    ScaffoldMessengerState messenger,
    String failed,
  ) async {
    final id = status.wish.id;
    removed.add(id);
    try {
      await repository.deleteWish(id);
    } catch (e, st) {
      reportError(e, st, reason: 'Wish delete failed');
      removed.remove(id);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _deleteFromMenu(BuildContext context, WidgetRef ref) async {
    final removed = ref.read(_removedWishIdsProvider.notifier);
    final repository = ref.read(wishRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).wishDeleteFailed;
    if (await _confirmDelete(context)) {
      await _delete(removed, repository, messenger, failed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final wish = status.wish;
    // 店名ときっかけだけ。メモはタップして開く編集で見る。消すときは横にすべらせるか、右の「…」から。
    return Dismissible(
      key: ValueKey(wish.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _delete(
        ref.read(_removedWishIdsProvider.notifier),
        ref.read(wishRepositoryProvider),
        ScaffoldMessenger.of(context),
        l10n.wishDeleteFailed,
      ),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Washi.desk,
        child: Text(l10n.delete, style: textTheme.bodyMedium),
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          leading: _SwingOnce(
            wishId: wish.id,
            enabled:
                ref.watch(appTabProvider) == AppTab.wishes &&
                ref.read(clockProvider)().difference(wish.createdAt) <
                    _freshWish,
            child: _WishSeal(fulfilled: false, wishId: wish.id),
          ),
          title: Text(wish.name, style: textTheme.titleMedium),
          subtitle: wish.trigger.isEmpty && wish.link == null
              ? null
              : _WishSubtitle(
                  wish: wish,
                  lines: [
                    if (wish.trigger.isNotEmpty)
                      Text(l10n.wishTriggerLine(wish.trigger)),
                  ],
                ),
          trailing: PopupMenuButton<_WishAction>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _WishAction.edit => _edit(context, ref),
              _WishAction.delete => _deleteFromMenu(context, ref),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: _WishAction.edit, child: Text(l10n.edit)),
              PopupMenuItem(
                value: _WishAction.delete,
                child: Text(l10n.wishDeleteAction),
              ),
            ],
          ),
          onTap: () => _edit(context, ref),
        ),
      ),
    );
  }
}

enum _WishAction { edit, delete }

class _FulfilledWishCard extends StatelessWidget {
  const _FulfilledWishCard({required this.status});

  final WishStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final wish = status.wish;
    final visit = status.fulfilledBy!.visit;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        leading: _WishSeal(fulfilled: true, wishId: wish.id),
        title: Text(wish.name, style: textTheme.titleMedium),
        subtitle: _WishSubtitle(
          wish: wish,
          lines: [
            Text(
              l10n.wishFulfilledLine(
                formatDate(visit.eatenAt),
                daysToFulfill(wish, visit.eatenAt),
              ),
            ),
            if (wish.trigger.isNotEmpty)
              Text(l10n.wishTriggerLine(wish.trigger)),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VisitDetailScreen(visitId: visit.id),
          ),
        ),
      ),
    );
  }
}

/// 願の札の2行目より下（叶った日・きっかけ・リンク）。
class _WishSubtitle extends StatelessWidget {
  const _WishSubtitle({required this.wish, required this.lines});

  final Wish wish;
  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
    final link = wish.link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lines,
        if (link != null)
          Align(
            alignment: Alignment.centerLeft,
            child: WishLinkButton(link: link),
          ),
      ],
    );
  }
}

/// 掛けたばかりとみなす間。地図や店のページで掛けてから、願掛け帳を開くまでの分。
const _freshWish = Duration(minutes: 10);

/// この起動の間に揺らした願。同じ願は二度揺らさない。
final _swungWishIds = <String>{};

/// 掛けたばかりの願のしおりを、吊られたように一度だけ揺らして落ち着かせる。
/// 願掛け帳が見えているときだけ揺らし、動きを減らす設定のときは揺らさない。
class _SwingOnce extends StatefulWidget {
  const _SwingOnce({
    required this.wishId,
    required this.enabled,
    required this.child,
  });

  final String wishId;
  final bool enabled;
  final Widget child;

  @override
  State<_SwingOnce> createState() => _SwingOnceState();
}

class _SwingOnceState extends State<_SwingOnce>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeSwing();
  }

  @override
  void didUpdateWidget(_SwingOnce oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeSwing();
  }

  void _maybeSwing() {
    if (!widget.enabled || !_swungWishIds.add(widget.wishId)) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      if (!_controller.isAnimating) return child!;
      final t = _controller.value;
      final settle = (1 - t) * (1 - t);
      final drop = Curves.easeOutCubic.transform((t / 0.35).clamp(0.0, 1.0));
      return Opacity(
        opacity: drop,
        child: Transform.translate(
          offset: Offset(0, -10 * (1 - drop)),
          child: Transform.rotate(
            alignment: Alignment.topCenter,
            angle: 0.35 * math.cos(t * 3 * math.pi) * settle,
            child: child,
          ),
        ),
      );
    },
  );
}

/// 「願」の丸印。叶った願は朱、まだの願は灰色の輪郭だけ。
class _WishSeal extends StatelessWidget {
  const _WishSeal({required this.fulfilled, required this.wishId});

  final bool fulfilled;

  /// かすれ方を願ごとに決めるため。
  final String wishId;

  @override
  Widget build(BuildContext context) {
    final color = fulfilled ? Washi.shu : Washi.faded;
    return InkWear(
      seed: inkSeed('wish:$wishId'),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fulfilled ? Washi.shu : null,
          border: Border.all(color: color, width: 2),
        ),
        child: Text(
          AppLocalizations.of(context).wishSealChar,
          style: TextStyle(
            fontFamily: Washi.brush,
            fontSize: 20,
            height: 1,
            color: fulfilled ? Washi.page : color,
          ),
        ),
      ),
    );
  }
}
