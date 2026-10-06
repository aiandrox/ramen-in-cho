import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sharedPhotoReceiverProvider = Provider<SharedPhotoReceiver>(
  (ref) => PlatformSharedPhotoReceiver(),
);

/// ほかのアプリの「共有」から送られてきた写真を受け取る。
/// 共有の入口が写真を預かってアプリを開くので、アプリを開くたびに受け取りに行く。
abstract class SharedPhotoReceiver {
  /// 受け取った写真の一時ファイルのパス。無ければnull。一度受け取ると消える。
  Future<String?> take();
}

class PlatformSharedPhotoReceiver implements SharedPhotoReceiver {
  static const _channel = MethodChannel(
    'com.aiandrox.ramen_in_cho/shared_photo',
  );

  @override
  Future<String?> take() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('takeSharedPhoto');
    } on PlatformException catch (e) {
      debugPrint('Shared photo failed: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final sharedTextReceiverProvider = Provider<SharedTextReceiver>(
  (ref) => PlatformSharedTextReceiver(),
);

/// 共有された文（Google マップの店・YouTube の動画のリンクなど）と件名。
class SharedText {
  const SharedText({required this.text, this.subject});

  final String text;
  final String? subject;
}

/// ほかのアプリの「共有」から送られてきた文を受け取る（願掛けに使う）。写真と同じ入口が預かる。
abstract class SharedTextReceiver {
  /// 受け取った文。無ければnull。一度受け取ると消える。
  Future<SharedText?> take();
}

class PlatformSharedTextReceiver implements SharedTextReceiver {
  @override
  Future<SharedText?> take() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    try {
      final map = await PlatformSharedPhotoReceiver._channel
          .invokeMapMethod<String, Object?>('takeSharedText');
      final text = map?['text'];
      if (text is! String || text.trim().isEmpty) return null;
      final subject = map?['subject'];
      return SharedText(
        text: text,
        subject: subject is String ? subject : null,
      );
    } on PlatformException catch (e) {
      debugPrint('Shared text failed: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
