import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.aiandrox.ramen_in_cho/system_settings');

/// スマホの設定のうち、麺印帳の通知の画面を開く。
Future<void> openNotificationSettings() async {
  try {
    await _channel.invokeMethod<void>('openNotificationSettings');
  } on PlatformException catch (e) {
    debugPrint('Open notification settings failed: $e');
  } on MissingPluginException {
    // テストなど、受け口の無い環境では何もしない。
  }
}
