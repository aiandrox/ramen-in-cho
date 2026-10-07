import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../analytics/analytics.dart';
import '../analytics/analytics_events.dart';

final photoPickerProvider = Provider<PhotoPicker>((ref) {
  final analytics = ref.watch(analyticsProvider);
  return ImagePickerPhotoPicker(
    ImagePicker(),
    onCameraDenied: () =>
        unawaited(analytics.log(AnalyticsEvents.permissionDenied('camera'))),
  );
});

abstract class PhotoPicker {
  /// 撮った写真の一時ファイルのパス。キャンセル・カメラが使えないときはnull。
  Future<String?> takePhoto();

  Future<String?> pickFromGallery();

  /// ギャラリーで何枚も選ぶ（選んだ順）。キャンセルしたときは空。
  Future<List<String>> pickManyFromGallery();

  /// Androidでカメラの起動中にアプリが終了させられたとき、撮った写真を取り戻す。
  Future<String?> retrieveLostPhoto();
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker(this._picker, {this.onCameraDenied});

  /// カメラの許可が無くて撮れなかったときに呼ぶ。
  final void Function()? onCameraDenied;

  static const _maxSize = 2000.0;
  static const _quality = 85;
  static const _maxPhotos = 30;

  final ImagePicker _picker;

  @override
  Future<String?> takePhoto() => _pick(ImageSource.camera);

  @override
  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  @override
  Future<List<String>> pickManyFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: _maxSize,
        maxHeight: _maxSize,
        imageQuality: _quality,
        limit: _maxPhotos,
      );
      return [for (final file in files) file.path];
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: _maxSize,
        maxHeight: _maxSize,
        imageQuality: _quality,
      );
      return file?.path;
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') onCameraDenied?.call();
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> retrieveLostPhoto() async {
    try {
      final response = await _picker.retrieveLostData();
      return response.file?.path;
    } catch (_) {
      return null;
    }
  }
}
