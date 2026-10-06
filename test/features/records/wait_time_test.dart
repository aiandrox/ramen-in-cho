import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/records/models.dart';
import 'package:ramen_in_cho/features/records/wait_time.dart';

import '../../support/builders.dart';

void main() {
  test('待ち時間は、食べた時刻 − チェックイン時刻（分）', () {
    expect(waitMinutes(buildVisit(waitMinutes: 0)), 0);
    expect(waitMinutes(buildVisit(waitMinutes: 35)), 35);
    expect(waitMinutes(buildVisit(waitMinutes: 125)), 125);
  });

  test('秒の端数は切り捨てる（9分59秒は9分）', () {
    final eatenAt = DateTime(2026, 9, 30, 12);
    final visit = Visit(
      id: 'v',
      shopId: 'shop',
      result: VisitResult.eaten,
      checkedInAt: eatenAt.subtract(const Duration(minutes: 9, seconds: 59)),
      eatenAt: eatenAt,
      isLimited: false,
      memo: '',
      createdAt: eatenAt,
    );

    expect(waitMinutes(visit), 9);
  });

  test('チェックインしていない記録に待ち時間は無い', () {
    expect(waitMinutes(buildVisit()), isNull);
  });

  test('食べた時刻がチェックインより前なら0分にする', () {
    expect(waitMinutes(buildVisit(waitMinutes: -5)), 0);
  });

  test('撤退の記録に待ち時間は無い', () {
    expect(
      waitMinutes(buildVisit(result: VisitResult.retreated, waitMinutes: 30)),
      isNull,
    );
  });

  group('recordTimes（記録画面で保存するときの時刻）', () {
    final checkedInAt = DateTime(2026, 10, 5, 11);
    final arrivedAt = DateTime(2026, 10, 5, 11, 50);
    final now = DateTime(2026, 10, 5, 12, 30);

    test('「着」を押していれば、写真をあとで撮ってもその時刻で待ち時間が決まる', () {
      final times = recordTimes(
        now: now,
        photoTakenAt: DateTime(2026, 10, 5, 12, 10),
        arrivedAt: arrivedAt,
        checkedInAt: checkedInAt,
      );
      expect(times.eatenAt, arrivedAt);
      expect(times.checkedInAt, checkedInAt);
      expect(times.eatenAt.difference(times.checkedInAt!).inMinutes, 50);
    });

    test('「着」を押して写真を撮らなくても、その時刻で記録する', () {
      final times = recordTimes(
        now: now,
        arrivedAt: arrivedAt,
        checkedInAt: checkedInAt,
      );
      expect(times.eatenAt, arrivedAt);
      expect(times.checkedInAt, checkedInAt);
    });

    test('「着」が無ければ、これまでどおり写真の時刻か今の時刻', () {
      final photo = DateTime(2026, 10, 5, 11, 40);
      expect(
        recordTimes(
          now: now,
          photoTakenAt: photo,
          checkedInAt: checkedInAt,
        ).eatenAt,
        photo,
      );
      expect(recordTimes(now: now, checkedInAt: checkedInAt).eatenAt, now);
    });

    test('並ぶ前に撮った写真なら待ち時間をつけない', () {
      final times = recordTimes(
        now: now,
        photoTakenAt: DateTime(2026, 10, 4, 12),
        checkedInAt: checkedInAt,
      );
      expect(times.checkedInAt, isNull);
    });

    test('並んだ店を選んでいなければ（並んだ時刻を渡さなければ）待ち時間は無い', () {
      expect(recordTimes(now: now).checkedInAt, isNull);
    });
  });
}
