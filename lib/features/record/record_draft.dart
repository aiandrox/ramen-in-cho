import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../records/models.dart';
import '../records/photo_storage.dart';
import '../shop_search/found_shop.dart';
import '../shop_search/geo.dart';
import '../shop_search/shop_candidate.dart';
import 'record_state.dart';

final recordDraftStoreProvider = Provider<RecordDraftStore>(
  (ref) => FileRecordDraftStore(ref.watch(documentsDirectoryProvider)),
);

/// 保存せずに閉じた記録画面の入力。次に記録画面を開いたときに、ここから再開する。
class RecordDraft {
  const RecordDraft({
    this.photoPath,
    this.photoTakenAt,
    this.photoFromCamera = false,
    this.photoDateFromPhoto = false,
    this.photoLocation,
    this.selectedShop,
    this.manualName = '',
    this.rating,
    this.style,
    this.isLimited = false,
    this.chosenHoursConditions,
    this.memo = '',
    this.manualWaitMinutes,
    this.arrivedAt,
    this.arrivedCheckin,
  });

  /// 並んでいる店は下書きに入れない（開いたときの並びの状態から選び直す）。
  /// ただし「着」を押したあとは、その並び（並んだ時刻と店）を一緒に残す。
  /// 保存する前にアプリが終わっても、チェックインが期限切れで消えても、待ち時間を失わないため。
  factory RecordDraft.fromState(RecordState state) {
    final selected = state.selectedShop;
    final arrivedAt = state.checkin == null ? null : state.arrivedAt;
    return RecordDraft(
      photoPath: state.photoPath,
      photoTakenAt: state.photoPath == null ? null : state.photoTakenAt,
      photoFromCamera: state.photoFromCamera,
      photoDateFromPhoto: state.photoDateFromPhoto,
      photoLocation: state.photoLocation,
      selectedShop: identical(selected, state.checkinShop) ? null : selected,
      manualName: state.manualName,
      rating: state.rating,
      style: state.style,
      isLimited: state.isLimited,
      chosenHoursConditions: state.chosenHoursConditions,
      memo: state.memo,
      manualWaitMinutes: state.manualWaitMinutes,
      arrivedAt: arrivedAt,
      arrivedCheckin: arrivedAt == null ? null : state.checkin,
    );
  }

  /// 写真のパス。保存先のファイルでは documents からの相対パスにする。
  final String? photoPath;
  final DateTime? photoTakenAt;
  final bool photoFromCamera;
  final bool photoDateFromPhoto;
  final GeoPoint? photoLocation;
  final ShopCandidate? selectedShop;
  final String manualName;
  final int? rating;
  final RamenStyle? style;
  final bool isLimited;
  final Set<HoursCondition>? chosenHoursConditions;
  final String memo;
  final int? manualWaitMinutes;

  /// 「着」を押した時刻と、そのときの並び。
  final DateTime? arrivedAt;
  final Checkin? arrivedCheckin;

  bool get isEmpty =>
      photoPath == null &&
      selectedShop == null &&
      manualName.trim().isEmpty &&
      rating == null &&
      style == null &&
      !isLimited &&
      chosenHoursConditions == null &&
      memo.trim().isEmpty &&
      manualWaitMinutes == null &&
      arrivedAt == null;

  RecordDraft withoutArrival() => RecordDraft(
    photoPath: photoPath,
    photoTakenAt: photoTakenAt,
    photoFromCamera: photoFromCamera,
    photoDateFromPhoto: photoDateFromPhoto,
    photoLocation: photoLocation,
    selectedShop: selectedShop,
    manualName: manualName,
    rating: rating,
    style: style,
    isLimited: isLimited,
    chosenHoursConditions: chosenHoursConditions,
    memo: memo,
    manualWaitMinutes: manualWaitMinutes,
  );

  RecordDraft withPhotoPath(String? path) => RecordDraft(
    photoPath: path,
    photoTakenAt: path == null ? null : photoTakenAt,
    photoFromCamera: path != null && photoFromCamera,
    photoDateFromPhoto: path != null && photoDateFromPhoto,
    photoLocation: path == null ? null : photoLocation,
    selectedShop: selectedShop,
    manualName: manualName,
    rating: rating,
    style: style,
    isLimited: isLimited,
    chosenHoursConditions: chosenHoursConditions,
    memo: memo,
    manualWaitMinutes: manualWaitMinutes,
    arrivedAt: arrivedAt,
    arrivedCheckin: arrivedCheckin,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'photoPath': photoPath,
    'photoTakenAt': photoTakenAt?.toUtc().toIso8601String(),
    'photoFromCamera': photoFromCamera,
    'photoDateFromPhoto': photoDateFromPhoto,
    'photoLocation': _geoToJson(photoLocation),
    'selectedShop': _shopToJson(selectedShop),
    'manualName': manualName,
    'rating': rating,
    'style': style?.name,
    'isLimited': isLimited,
    'chosenHoursConditions': chosenHoursConditions == null
        ? null
        : [for (final c in chosenHoursConditions!) c.name],
    'memo': memo,
    'manualWaitMinutes': manualWaitMinutes,
    'arrivedAt': arrivedAt?.toUtc().toIso8601String(),
    'arrivedCheckin': _checkinToJson(arrivedCheckin),
  };

  /// 読めない項目は空にして、読める分だけ戻す。形が丸ごと違えばnull。
  static RecordDraft? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final rating = _int(json['rating']);
    final wait = _int(json['manualWaitMinutes']);
    final photoPath = _string(json['photoPath']);
    final arrivedAt = _dateTime(json['arrivedAt']);
    final arrivedCheckin = _checkinFromJson(json['arrivedCheckin']);
    final arrived = arrivedAt != null && arrivedCheckin != null;
    return RecordDraft(
      photoPath: photoPath,
      photoTakenAt: photoPath == null
          ? null
          : DateTime.tryParse(_string(json['photoTakenAt']) ?? '')?.toLocal(),
      photoFromCamera: json['photoFromCamera'] == true,
      photoDateFromPhoto: json['photoDateFromPhoto'] == true,
      photoLocation: _geoFromJson(json['photoLocation']),
      selectedShop: _shopFromJson(json['selectedShop']),
      manualName: _string(json['manualName']) ?? '',
      rating: rating != null && rating >= 1 && rating <= 5 ? rating : null,
      style: _enum(RamenStyle.values, json['style']),
      isLimited: json['isLimited'] == true,
      chosenHoursConditions: _conditions(json['chosenHoursConditions']),
      memo: _string(json['memo']) ?? '',
      manualWaitMinutes: wait != null && wait > 0 ? wait : null,
      arrivedAt: arrived ? arrivedAt : null,
      arrivedCheckin: arrived ? arrivedCheckin : null,
    );
  }
}

DateTime? _dateTime(Object? value) =>
    DateTime.tryParse(_string(value) ?? '')?.toLocal();

Map<String, Object?>? _sourceToJson(ShopSource? source) => source == null
    ? null
    : {'licenses': source.licenses, 'attributions': source.attributions};

ShopSource? _sourceFromJson(Object? json) => json is Map<String, dynamic>
    ? ShopSource(
        licenses: _strings(json['licenses']),
        attributions: _strings(json['attributions']),
      )
    : null;

Map<String, Object?>? _checkinToJson(Checkin? checkin) => checkin == null
    ? null
    : {
        'shopId': checkin.shopId,
        'osmId': checkin.osmId,
        'name': checkin.name,
        'latitude': checkin.latitude,
        'longitude': checkin.longitude,
        'dataSource': _sourceToJson(checkin.dataSource),
        'checkedInAt': checkin.checkedInAt.toUtc().toIso8601String(),
      };

Checkin? _checkinFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final name = _string(json['name']);
  final checkedInAt = _dateTime(json['checkedInAt']);
  if (name == null || name.isEmpty || checkedInAt == null) return null;
  final latitude = json['latitude'];
  final longitude = json['longitude'];
  return Checkin(
    shopId: _string(json['shopId']),
    osmId: _string(json['osmId']),
    name: name,
    latitude: latitude is num ? latitude.toDouble() : null,
    longitude: longitude is num ? longitude.toDouble() : null,
    dataSource: _sourceFromJson(json['dataSource']),
    checkedInAt: checkedInAt,
  );
}

Map<String, Object?>? _geoToJson(GeoPoint? point) => point == null
    ? null
    : {'latitude': point.latitude, 'longitude': point.longitude};

GeoPoint? _geoFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final latitude = json['latitude'];
  final longitude = json['longitude'];
  if (latitude is! num || longitude is! num) return null;
  return GeoPoint(latitude.toDouble(), longitude.toDouble());
}

Map<String, Object?>? _shopToJson(ShopCandidate? shop) {
  if (shop == null) return null;
  final source = shop.dataSource;
  final conditions = shop.hoursConditions;
  return {
    'shopId': shop.shopId,
    'osmId': shop.osmId,
    'name': shop.name,
    'location': _geoToJson(shop.location),
    'hoursConditions': conditions == null
        ? null
        : [for (final c in conditions) c.name],
    'strategyMemo': shop.strategyMemo,
    'dataSource': _sourceToJson(source),
    'wishId': shop.wishId,
    'conditionsDraftSource': shop.conditionsDraftSource?.name,
  };
}

ShopCandidate? _shopFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final name = _string(json['name']);
  if (name == null || name.isEmpty) return null;
  final source = json['dataSource'];
  return ShopCandidate(
    shopId: _string(json['shopId']),
    osmId: _string(json['osmId']),
    name: name,
    location: _geoFromJson(json['location']),
    hoursConditions: _conditions(json['hoursConditions']),
    strategyMemo: _string(json['strategyMemo']) ?? '',
    dataSource: _sourceFromJson(source),
    wishId: _string(json['wishId']),
    conditionsDraftSource:
        ConditionsDraftSource.values
            .asNameMap()[json['conditionsDraftSource']] ??
        // 前の版の下書きは、地図の営業時間からの下書きかどうかだけを持っていた。
        (json['conditionsFromMap'] == true
            ? ConditionsDraftSource.openingHours
            : null),
  );
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;

List<String> _strings(Object? value) =>
    value is List ? [for (final v in value) ?_string(v)] : const [];

T? _enum<T extends Enum>(List<T> values, Object? name) =>
    values.where((v) => v.name == name).firstOrNull;

Set<HoursCondition>? _conditions(Object? value) => value is List
    ? {for (final v in value) ?_enum(HoursCondition.values, v)}
    : null;

/// 下書きの読み書き。写真は documents の下書き用のフォルダに写して持つ
/// （image_picker の一時ファイルは OS に消されることがあるため）。
abstract class RecordDraftStore {
  Future<RecordDraft?> load();

  /// 写真を下書き用のフォルダに写し、写した先のパスを返す。
  Future<String> keepPhoto(String sourcePath);

  /// 空の下書きなら、保存してある下書きを消す。
  Future<void> save(RecordDraft draft);

  /// 下書きと、下書き用のフォルダの写真を消す（[keepPhoto]だけは残す）。
  /// 記録した写真は別のフォルダにあるので消えない。
  Future<void> clear({String? keepPhoto});
}

class FileRecordDraftStore implements RecordDraftStore {
  FileRecordDraftStore(this._documents, {this._uuid = const Uuid()});

  static const fileName = 'record_draft.json';
  static const photoDirectoryName = 'record_draft';

  final Directory _documents;
  final Uuid _uuid;

  /// 読み書きの順番が入れ替わって、新しい写真を消したり古い下書きで上書きしたりしないよう、1つずつ行う。
  Future<void> _tail = Future.value();

  /// 写したばかりで、まだ下書きに書かれていないかもしれない写真。片付けで消さない。
  String? _latestKept;

  File get _file => File(p.join(_documents.path, fileName));

  Directory get _photoDirectory =>
      Directory(p.join(_documents.path, photoDirectoryName));

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  bool _isDraftPhoto(String path) =>
      p.isWithin(_photoDirectory.path, p.normalize(path));

  @override
  Future<RecordDraft?> load() => _enqueue(() async {
    try {
      final draft = RecordDraft.fromJson(
        jsonDecode(await _file.readAsString()),
      );
      if (draft == null) return null;
      final relative = draft.photoPath;
      if (relative == null) return draft;
      final photo = File(p.join(_documents.path, relative));
      final exists = _isDraftPhoto(photo.path) && await photo.exists();
      return draft.withPhotoPath(exists ? photo.path : null);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  });

  @override
  Future<String> keepPhoto(String sourcePath) => _enqueue(() async {
    if (_isDraftPhoto(sourcePath)) return sourcePath;
    final extension = p.extension(sourcePath).toLowerCase();
    final destination = File(
      p.join(
        _photoDirectory.path,
        '${_uuid.v4()}${extension.isEmpty ? '.jpg' : extension}',
      ),
    );
    await destination.parent.create(recursive: true);
    await File(sourcePath).copy(destination.path);
    _latestKept = destination.path;
    return destination.path;
  });

  @override
  Future<void> save(RecordDraft draft) => _enqueue(() async {
    if (draft.isEmpty) {
      if (await _file.exists()) await _file.delete();
    } else {
      final photo = draft.photoPath;
      // 写真が一時ファイルのままなら（写すのに失敗したとき）、下書きには残さない。
      final relative = photo != null && _isDraftPhoto(photo)
          ? p.relative(photo, from: _documents.path)
          : null;
      final temporary = File('${_file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode(draft.withPhotoPath(relative).toJson()),
      );
      await temporary.rename(_file.path);
    }
    await _removePhotosExcept({?draft.photoPath, ?_latestKept});
  });

  @override
  Future<void> clear({String? keepPhoto}) => _enqueue(() async {
    if (await _file.exists()) await _file.delete();
    _latestKept = keepPhoto;
    await _removePhotosExcept({?keepPhoto});
  });

  Future<void> _removePhotosExcept(Set<String> keep) async {
    final directory = _photoDirectory;
    if (!await directory.exists()) return;
    final kept = {for (final path in keep) p.normalize(path)};
    await for (final entry in directory.list()) {
      if (entry is! File || kept.contains(p.normalize(entry.path))) continue;
      try {
        await entry.delete();
      } on FileSystemException catch (e) {
        debugPrint('Draft photo delete failed: $e');
      }
    }
  }
}
