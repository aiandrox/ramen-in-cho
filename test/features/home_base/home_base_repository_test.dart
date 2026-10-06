import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/database/app_database.dart';
import 'package:ramen_in_cho/features/home_base/home_base_repository.dart';
import 'package:ramen_in_cho/features/quests/quests.dart';
import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/scoring/points.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';

void main() {
  late AppDatabase database;
  late HomeBaseRepository repository;

  setUp(() {
    database = createTestDatabase();
    repository = HomeBaseRepository(database);
  });

  Future<HomeBaseSetting> add(String name, DateTime now) =>
      repository.setHomeBase(
        name: name,
        latitude: 35.6909,
        longitude: 139.7003,
        now: now,
      );

  QuestProgress homeBaseQuest(List<HomeBaseSetting> settings) => evaluateQuests(
    scoreVisits(const []),
    homeBases: settings,
  ).firstWhere((p) => p.quest.id == 'home_base');

  test('日付・呼び名・場所を直せる。ほかの拠点は変わらない', () async {
    final shinjuku = await add('新宿', DateTime(2026, 3, 1, 9));
    final sapporo = await add('札幌', DateTime(2026, 6, 1, 9));

    final updated = await repository.updateHomeBase(
      sapporo.copyWith(
        name: '  札幌駅 ',
        latitude: 43.0687,
        longitude: 141.3508,
        setAt: DateTime(2026, 5, 20),
      ),
    );

    expect(updated.name, '札幌駅');
    final saved = await repository.watchSettings().first;
    expect(saved.map((s) => s.id), [shinjuku.id, sapporo.id]);
    expect(saved.last.name, '札幌駅');
    expect(saved.last.latitude, 43.0687);
    expect(saved.last.longitude, 141.3508);
    expect(saved.last.setAt, DateTime(2026, 5, 20));
    expect(saved.first.name, '新宿');
    expect(saved.first.setAt, DateTime(2026, 3, 1, 9));
  });

  test('日付を前に動かすと、一覧の順も入れ替わる', () async {
    final shinjuku = await add('新宿', DateTime(2026, 3, 1, 9));
    final sapporo = await add('札幌', DateTime(2026, 6, 1, 9));

    await repository.updateHomeBase(
      sapporo.copyWith(setAt: DateTime(2026, 1, 10)),
    );

    final saved = await repository.watchSettings().first;
    expect(saved.map((s) => s.id), [sapporo.id, shinjuku.id]);
  });

  test('いちばん古い拠点の日付を直すと、秘伝「拠点を構える」の日も変わる', () async {
    final shinjuku = await add('新宿', DateTime(2026, 9, 5, 9));
    await add('札幌', DateTime(2026, 10, 1, 9));
    expect(homeBaseQuest(await repository.allSettings()).levelAchievedAt, [
      DateTime(2026, 9, 5, 9),
    ]);

    await repository.updateHomeBase(
      shinjuku.copyWith(setAt: DateTime(2026, 4, 1)),
    );

    final result = homeBaseQuest(await repository.allSettings());
    expect(result.levelAchievedAt, [DateTime(2026, 4, 1)]);
    expect(result.achievedHomeBase?.name, '新宿');
  });

  test('消すと、その拠点が効いていた記録はひとつ前の拠点で遠征を決め直す', () async {
    final far = buildShop(id: 'far', latitude: 43.0687, longitude: 141.3508);
    await add('新宿', DateTime(2026, 3, 1, 9));
    final sapporo = await repository.setHomeBase(
      name: '札幌',
      latitude: 43.0687,
      longitude: 141.3508,
      now: DateTime(2026, 6, 1, 9),
    );
    int bonus(List<HomeBaseSetting> settings) => scoreVisits([
      buildEntry(shop: far, eatenAt: DateTime(2026, 7, 1, 12)),
    ], homeBases: settings).single.points.expeditionBonus;

    expect(bonus(await repository.allSettings()), 0);

    await repository.deleteHomeBase(sapporo.id);

    final left = await repository.allSettings();
    expect(left.map((s) => s.name), ['新宿']);
    // 新宿から札幌は800km以上なので、いちばん上の段。
    expect(bonus(left), 30);
  });

  test('すべて消すと拠点は無くなり、秘伝「拠点を構える」も会得していないことになる', () async {
    final shinjuku = await add('新宿', DateTime(2026, 3, 1, 9));
    expect(homeBaseQuest(await repository.allSettings()).isAchieved, isTrue);

    await repository.deleteHomeBase(shinjuku.id);

    final left = await repository.allSettings();
    expect(left, isEmpty);
    expect(homeBaseQuest(left).isAchieved, isFalse);
  });
}
