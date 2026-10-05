import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';
import '../quests/quest_seal.dart';
import '../quests/quests.dart';
import '../records/clock.dart';
import '../records/date_format.dart';
import '../shop_search/geo.dart';
import '../shop_search/location_service.dart';
import '../shop_search/overpass_client.dart';
import 'home_base_repository.dart';
import 'place_search.dart';

/// 拠点を決める画面。駅や市町村の名前で探すか、現在地にする。決めたら true を返して閉じる。
class HomeBasePickerScreen extends ConsumerStatefulWidget {
  const HomeBasePickerScreen({super.key});

  @override
  ConsumerState<HomeBasePickerScreen> createState() =>
      _HomeBasePickerScreenState();
}

class _HomeBasePickerScreenState extends ConsumerState<HomeBasePickerScreen> {
  final _controller = TextEditingController();
  var _searching = false;
  var _saving = false;
  List<PlaceCandidate>? _results;
  String? _message;
  GeoPoint? _here;

  @override
  void initState() {
    super.initState();
    _loadHere();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 候補を近い順に並べ、距離を添えるためだけに使う。許可をまだもらっていなければ聞かない。
  Future<void> _loadHere() async {
    final location = ref.read(locationServiceProvider);
    if (!await location.isReady()) return;
    final here = await location.currentPosition(requestPermission: false);
    if (mounted && here != null) setState(() => _here = here);
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context);
    final name = _controller.text;
    if (placeSearchStem(name).isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _message = null;
      _results = null;
    });
    try {
      final results = await ref
          .read(overpassClientProvider)
          .searchPlaces(name, near: _here);
      if (!mounted) return;
      setState(() {
        _results = results;
        _message = results.isEmpty ? l10n.homeBaseNotFound : null;
      });
    } catch (e) {
      debugPrint('Home base search failed: $e');
      if (mounted) setState(() => _message = l10n.homeBaseSearchFailed);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useHere() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final here = await ref
        .read(locationServiceProvider)
        .currentPosition(requestPermission: true);
    if (!mounted) return;
    setState(() => _saving = false);
    if (here == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.homeBaseHereFailed)));
      return;
    }
    final name = await _askName();
    if (name == null || !mounted) return;
    await _save(name, here);
  }

  Future<String?> _askName() => showDialog<String>(
    context: context,
    builder: (_) => const _HereNameDialog(),
  );

  Future<void> _save(String name, GeoPoint location) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(homeBaseRepositoryProvider);
    setState(() => _saving = true);
    try {
      final isFirst = (await repository.allSettings()).isEmpty;
      final setting = await repository.setHomeBase(
        name: name,
        latitude: location.latitude,
        longitude: location.longitude,
        now: ref.read(clockProvider)(),
      );
      if (!mounted) return;
      if (isFirst) await showHomeBaseHidenDialog(context, setting.setAt);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeBaseSaved(setting.name))),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Home base save failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.homeBaseSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  String _subtitle(AppLocalizations l10n, PlaceCandidate place) {
    final here = _here;
    return [
      switch (place.kind) {
        PlaceKind.station => l10n.homeBaseKindStation,
        PlaceKind.city => l10n.homeBaseKindCity,
        PlaceKind.town => l10n.homeBaseKindTown,
        PlaceKind.village => l10n.homeBaseKindVillage,
        PlaceKind.suburb => l10n.homeBaseKindSuburb,
      },
      ...place.operators,
      if (here != null)
        l10n.homeBaseDistance(
          (distanceMeters(here, place.location) / 1000).round(),
        ),
    ].join('・');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final history = ref.watch(homeBaseSettingsProvider).value ?? const [];
    final current = ref.watch(currentHomeBaseProvider);
    final busy = _searching || _saving;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeBaseTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.homeBaseIntro, style: textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(
            current == null
                ? l10n.homeBaseNotSet
                : l10n.homeBaseLine(current.name),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_saving,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: l10n.homeBaseSearchHint,
              helperText: l10n.homeBaseSearchNote,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                tooltip: l10n.homeBaseSearch,
                icon: const Icon(Icons.search),
                onPressed: busy ? null : _search,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SumiFuda(
            expand: true,
            icon: const Icon(Icons.my_location),
            onPressed: busy ? null : _useHere,
            child: Text(l10n.homeBaseUseHere),
          ),
          const SizedBox(height: 8),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_message case final message?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                message,
                style: textTheme.bodyMedium?.copyWith(color: Washi.inkSoft),
              ),
            ),
          for (final place in _results ?? const <PlaceCandidate>[])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(place.name),
              subtitle: Text(_subtitle(l10n, place)),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy ? null : () => _save(place.name, place.location),
            ),
          if (_results?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.mapAttribution,
                style: textTheme.bodySmall?.copyWith(color: Washi.faded),
              ),
            ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(l10n.homeBaseHistoryTitle, style: textTheme.titleSmall),
            for (final setting in history.reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(setting.name),
                subtitle: Text(
                  l10n.homeBaseHistoryFrom(formatDateTime(setting.setAt)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 初めて拠点を決めたときに、秘伝「拠点を構える」の会得を知らせる。
Future<void> showHomeBaseHidenDialog(BuildContext context, DateTime setAt) {
  final l10n = AppLocalizations.of(context);
  final quest = quests.firstWhere((q) => q.byHomeBase);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QuestSeal(quest: quest, level: 1, size: 112, achievedAt: setAt),
          const SizedBox(height: 16),
          Text(
            l10n.homeBaseHidenGained,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.homeBaseHidenOk),
        ),
      ],
    ),
  );
}

/// 現在地の拠点の呼び名を聞く。閉じる動きの間も入力欄が残るので、入力の中身は窓と一緒に片付ける。
class _HereNameDialog extends StatefulWidget {
  const _HereNameDialog();

  @override
  State<_HereNameDialog> createState() => _HereNameDialogState();
}

class _HereNameDialogState extends State<_HereNameDialog> {
  late final _controller = TextEditingController(
    text: AppLocalizations.of(context).homeBaseHereNameDefault,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.homeBaseHereNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            final name = _controller.text.trim();
            Navigator.of(context)
                .pop(name.isEmpty ? l10n.homeBaseHereNameDefault : name);
          },
          child: Text(l10n.homeBaseDecide),
        ),
      ],
    );
  }
}
