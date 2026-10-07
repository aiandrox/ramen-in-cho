import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error_reporting/error_reporting.dart';
import '../records/clock.dart';
import '../records/models.dart';
import '../records/record_repository.dart';
import '../shop_search/shop_candidate.dart';
import '../shop_search/shop_search_service.dart';
import 'checkin_rules.dart';
import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';

/// 並んでいる最中のチェックイン。3時間を超えていたら取り消してnullにする。
final activeCheckinProvider = StreamProvider<Checkin?>((ref) {
  final repository = ref.watch(recordRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return repository.watchActiveCheckin().asyncMap((checkin) async {
    if (checkin == null || !isCheckinExpired(checkin, clock())) return checkin;
    await repository.cancelCheckin();
    unawaited(
      ref.read(analyticsProvider).log(AnalyticsEvents.checkinAutoCanceled),
    );
    return null;
  });
});

final checkinControllerProvider =
    NotifierProvider.autoDispose<CheckinController, CheckinState>(
      CheckinController.new,
    );

class CheckinState {
  const CheckinState({
    this.isSearching = false,
    this.result,
    this.isSaving = false,
  });

  final bool isSearching;

  /// 検索の結果。まだ終わっていなければnull。
  final ShopSearchResult? result;
  final bool isSaving;

  /// 現在地がわかっていれば、手入力の店名でもチェックインできる（店の位置＝現在地）。
  bool get canCheckInManually => result?.here != null && !isSaving;
}

class CheckinController extends Notifier<CheckinState> {
  @override
  CheckinState build() => const CheckinState();

  Future<void> search() async {
    if (state.isSearching) return;
    state = const CheckinState(isSearching: true);
    final result = await ref
        .read(shopSearchServiceProvider)
        .search(requestPermission: true);
    if (!ref.mounted) return;
    unawaited(
      ref
          .read(analyticsProvider)
          .log(AnalyticsEvents.shopSearch(purpose: 'checkin', result: result)),
    );
    state = CheckinState(result: result);
  }

  /// チェックインできたらtrue。店から離れているときは何もしない。
  Future<bool> checkIn(ShopCandidate shop) {
    if (!canCheckIn(shop.distanceMeters)) return Future.value(false);
    return _checkIn(
      shopSourceOf(shop),
      ShopInput(
        shopId: shop.shopId,
        osmId: shop.osmId,
        name: shop.name,
        latitude: shop.location?.latitude,
        longitude: shop.location?.longitude,
        dataSource: shop.dataSource,
      ),
    );
  }

  Future<bool> checkInManually(String name) {
    final here = state.result?.here;
    if (here == null || name.trim().isEmpty) return Future.value(false);
    return _checkIn(
      ShopSourceKind.manual,
      ShopInput(name: name, latitude: here.latitude, longitude: here.longitude),
    );
  }

  Future<bool> _checkIn(ShopSourceKind source, ShopInput shop) async {
    if (state.isSaving) return false;
    state = CheckinState(result: state.result, isSaving: true);
    try {
      await ref
          .read(recordRepositoryProvider)
          .checkIn(shop: shop, at: ref.read(clockProvider)());
      unawaited(
        ref
            .read(analyticsProvider)
            .log(
              AnalyticsEvents.checkinStarted(via: 'screen', shopSource: source),
            ),
      );
      return true;
    } catch (e, st) {
      reportError(e, st, reason: 'Checkin failed');
      if (ref.mounted) state = CheckinState(result: state.result);
      return false;
    }
  }
}
