import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sharedPhotoReceiverProvider = Provider<SharedPhotoReceiver>(
  (ref) => PlatformSharedPhotoReceiver(),
);

/// ほかのアプリの「共有」から送られてきた写真を受け取る（今は Android だけ）。
abstract class SharedPhotoReceiver {
  /// 受け取った写真の一時ファイルのパス。無ければnull。一度受け取ると消える。
  Future<String?> take();

  /// アプリを開いている間に写真が送られてきたら呼ぶ。
  void listen(VoidCallback onArrived);
}

class PlatformSharedPhotoReceiver implements SharedPhotoReceiver {
  static const _channel = MethodChannel(
    'com.aiandrox.ramen_in_cho/shared_photo',
  );

  @override
  Future<String?> take() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<String>('takeSharedPhoto');
    } on PlatformException catch (e) {
      debugPrint('Shared photo failed: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  void listen(VoidCallback onArrived) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedPhotoArrived') onArrived();
    });
  }
}
