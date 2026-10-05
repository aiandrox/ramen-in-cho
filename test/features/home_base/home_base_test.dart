import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/home_base/home_base.dart';

import '../../support/builders.dart';

void main() {
  final yokohama = buildHomeBase(
    id: 'yokohama',
    setAt: DateTime(2026, 3, 1, 9),
  );
  final sapporo = buildHomeBase(id: 'sapporo', setAt: DateTime(2026, 6, 1, 9));
  final settings = [sapporo, yokohama];

  group('homeBaseAt', () {
    test('まだ決めていなければ拠点は無い', () {
      expect(homeBaseAt(const [], DateTime(2026, 7, 1)), isNull);
    });

    test('初めて決めるより前の記録には拠点が無い', () {
      expect(homeBaseAt(settings, DateTime(2026, 3, 1, 8, 59)), isNull);
    });

    test('決めた日時ちょうどの記録から効く', () {
      expect(homeBaseAt(settings, DateTime(2026, 3, 1, 9))?.id, 'yokohama');
    });

    test('変える前は前の拠点、変えたあとは新しい拠点', () {
      expect(homeBaseAt(settings, DateTime(2026, 6, 1, 8))?.id, 'yokohama');
      expect(homeBaseAt(settings, DateTime(2026, 6, 1, 9))?.id, 'sapporo');
      expect(homeBaseAt(settings, DateTime(2027))?.id, 'sapporo');
    });
  });

  test('今の拠点はいちばん新しく決めたもの、最初の拠点はいちばん古いもの', () {
    expect(latestHomeBase(settings)?.id, 'sapporo');
    expect(firstHomeBase(settings)?.id, 'yokohama');
    expect(latestHomeBase(const []), isNull);
    expect(firstHomeBase(const []), isNull);
  });
}
