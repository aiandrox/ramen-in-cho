import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../records/models.dart';
import 'home_base.dart';

final homeBaseRepositoryProvider = Provider<HomeBaseRepository>(
  (ref) => HomeBaseRepository(ref.watch(appDatabaseProvider)),
);

/// これまでに決めた拠点（決めた順）。
final homeBaseSettingsProvider = StreamProvider<List<HomeBaseSetting>>(
  (ref) => ref.watch(homeBaseRepositoryProvider).watchSettings(),
);

/// 今の拠点（いちばん新しく決めたもの）。まだ決めていなければnull。
final currentHomeBaseProvider = Provider<HomeBaseSetting?>(
  (ref) =>
      latestHomeBase(ref.watch(homeBaseSettingsProvider).value ?? const []),
);

/// 拠点は変えるたびに1件ずつ足す（変えた日から後の記録にだけ効かせるため）。
/// これまでの拠点は、あとから日付・呼び名・場所を直したり消したりできる。
class HomeBaseRepository {
  HomeBaseRepository(this._db, {this._uuid = const Uuid()});

  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<HomeBaseSetting>> watchSettings() =>
      (_db.select(_db.homeBaseSettings)..orderBy([
            (s) => OrderingTerm.asc(s.setAt),
            (s) => OrderingTerm.asc(s.id),
          ]))
          .watch();

  Future<List<HomeBaseSetting>> allSettings() =>
      _db.select(_db.homeBaseSettings).get();

  Future<HomeBaseSetting> setHomeBase({
    required String name,
    required double latitude,
    required double longitude,
    required DateTime setAt,
  }) async {
    final setting = HomeBaseSetting(
      id: _uuid.v4(),
      name: name.trim(),
      latitude: latitude,
      longitude: longitude,
      setAt: setAt,
    );
    await _db.into(_db.homeBaseSettings).insert(setting.toCompanion());
    return setting;
  }

  /// [setting]のIDの拠点を、[setting]の中身に直す。呼び名は前後の空白を除く。
  Future<HomeBaseSetting> updateHomeBase(HomeBaseSetting setting) async {
    final updated = setting.copyWith(name: setting.name.trim());
    await _db.update(_db.homeBaseSettings).replace(updated.toCompanion());
    return updated;
  }

  Future<void> deleteHomeBase(String id) =>
      (_db.delete(_db.homeBaseSettings)..where((s) => s.id.equals(id))).go();
}

extension HomeBaseSettingCompanion on HomeBaseSetting {
  HomeBaseSettingsCompanion toCompanion() => HomeBaseSettingsCompanion.insert(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    setAt: setAt,
  );
}
