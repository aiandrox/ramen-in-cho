import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';

/// 麺印帳が位置情報を使えるかどうか。
enum LocationAccess { granted, notGranted, deniedForever, serviceOff }

final locationAccessServiceProvider = Provider<LocationAccessService>(
  (ref) => const GeolocatorLocationAccessService(),
);

abstract class LocationAccessService {
  Future<LocationAccess> check();

  /// 今の状態に合わせて、許可を尋ねるか、スマホの設定を開く。
  Future<void> fix(LocationAccess access);
}

class GeolocatorLocationAccessService implements LocationAccessService {
  const GeolocatorLocationAccessService();

  @override
  Future<LocationAccess> check() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceOff;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.whileInUse ||
        LocationPermission.always => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        _ => LocationAccess.notGranted,
      };
    } catch (_) {
      return LocationAccess.notGranted;
    }
  }

  @override
  Future<void> fix(LocationAccess access) async {
    try {
      switch (access) {
        case LocationAccess.notGranted:
          final result = await Geolocator.requestPermission();
          // 前に断っていると、聞き直せずにすぐ「許可しない」が返るので、設定を開く。
          if (result == LocationPermission.deniedForever) {
            await Geolocator.openAppSettings();
          }
        case LocationAccess.serviceOff:
          await Geolocator.openLocationSettings();
        case LocationAccess.granted || LocationAccess.deniedForever:
          await Geolocator.openAppSettings();
      }
    } catch (e) {
      debugPrint('Location access fix failed: $e');
    }
  }
}

/// 設定の「位置情報」の行。今の状態を出し、タップで許可を尋ねるかスマホの設定を開く。
class LocationAccessTile extends ConsumerStatefulWidget {
  const LocationAccessTile({super.key});

  @override
  ConsumerState<LocationAccessTile> createState() => _LocationAccessTileState();
}

class _LocationAccessTileState extends ConsumerState<LocationAccessTile> {
  // スマホの設定から戻ってきたら、変わった状態を出し直す。
  late final _lifecycle = AppLifecycleListener(onResume: _refresh);
  LocationAccess? _access;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final access = await ref.read(locationAccessServiceProvider).check();
    if (mounted) setState(() => _access = access);
  }

  Future<void> _fix() async {
    final access = _access;
    if (access == null) return;
    await ref.read(locationAccessServiceProvider).fix(access);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final access = _access;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.locationSettings),
      subtitle: Text(switch (access) {
        null => '',
        LocationAccess.granted => l10n.locationAccessGranted,
        LocationAccess.notGranted => l10n.locationAccessNotGranted,
        LocationAccess.deniedForever => l10n.locationAccessDeniedForever,
        LocationAccess.serviceOff => l10n.locationAccessServiceOff,
      }),
      trailing: const Icon(Icons.chevron_right),
      onTap: access == null ? null : _fix,
    );
  }
}
