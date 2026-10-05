import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'geo.dart';

/// 現在地を求められたのに、アプリからは直せない理由で取れなかったこと。
enum LocationBlock { serviceOff, deniedForever }

/// [LocationBlock]が起きたことを画面に知らせ、スマホの設定を開くよう案内してもらう。
final locationBlocks = StreamController<LocationBlock>.broadcast();

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

abstract class LocationService {
  /// 許可ダイアログを出さずに現在地を取れる状態か。
  Future<bool> isReady();

  /// 現在地。取れないとき（許可なし・位置情報オフ・時間切れ）はnull。
  /// [requestPermission]がtrueなら、未許可のとき許可ダイアログを出す。
  Future<GeoPoint?> currentPosition({required bool requestPermission});
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static const _timeout = Duration(seconds: 8);

  @override
  Future<bool> isReady() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      return _isGranted(await Geolocator.checkPermission());
    } catch (_) {
      return false;
    }
  }

  @override
  Future<GeoPoint?> currentPosition({required bool requestPermission}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (requestPermission) locationBlocks.add(LocationBlock.serviceOff);
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      // 何度か断ると、アプリからは許可を聞き直せなくなる（スマホの設定でしか直せない）。
      if (permission == LocationPermission.deniedForever && requestPermission) {
        locationBlocks.add(LocationBlock.deniedForever);
      }
      if (!_isGranted(permission)) return null;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: _timeout,
          ),
        );
        return GeoPoint(position.latitude, position.longitude);
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null || !isUsableLastKnownPosition(last, DateTime.now())) {
          return null;
        }
        return GeoPoint(last.latitude, last.longitude);
      }
    } catch (_) {
      return null;
    }
  }

  /// 古い・粗い位置だと別の場所の店が候補に出てしまうため、直近の正確なものだけ使う。
  static bool isUsableLastKnownPosition(Position position, DateTime now) =>
      now.difference(position.timestamp).abs() <= const Duration(minutes: 2) &&
      position.accuracy <= 100;

  bool _isGranted(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;
}
