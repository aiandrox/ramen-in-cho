import 'package:flutter_test/flutter_test.dart';

import 'package:ramen_in_cho/features/scoring/ranks.dart';
import 'package:ramen_in_cho/features/words/words.dart';

void main() {
  test('同じ鍵からはいつも同じ言葉を選び、鍵が違えばばらける', () {
    const options = ['一', '二', '三', '四'];
    expect(pickWord('visit-1', options), pickWord('visit-1', options));
    final picked = {for (var i = 0; i < 40; i++) pickWord('visit-$i', options)};
    expect(picked.length, greaterThan(1));
  });

  test('師匠のひとことは段位ごとに違う', () {
    final words = AdventurerRank.values.map(masterWords).toList();
    expect(words.every((w) => w.isNotEmpty), isTrue);
    expect(words.toSet().length, AdventurerRank.values.length);
    expect(masterWords(AdventurerRank.dan1), 'ようやく入口に立ったな。');
    expect(masterWords(AdventurerRank.grandmaster), 'もう教えることはない。');
  });

  test('撤退のメモから理由を読み取る', () {
    expect(retreatReasonOf('売り切れ'), RetreatReason.soldOut);
    expect(retreatReasonOf('スープ切れで終了'), RetreatReason.soldOut);
    expect(retreatReasonOf('完売'), RetreatReason.soldOut);
    expect(retreatReasonOf('臨時休業'), RetreatReason.closed);
    expect(retreatReasonOf('定休日だった'), RetreatReason.closed);
    expect(retreatReasonOf('時間切れ'), RetreatReason.noTime);
    expect(retreatReasonOf('電車に間に合わない'), RetreatReason.noTime);
    expect(retreatReasonOf(''), RetreatReason.other);
    expect(retreatReasonOf('行列が長すぎた'), RetreatReason.other);
  });

  test('撤退の慰めは理由に合ったものを、記録ごとに決まった1つ選ぶ', () {
    final soldOut = {
      for (var i = 0; i < 30; i++) retreatConsolation('売り切れ', 'v$i'),
    };
    expect(soldOut, contains('人気の証。次は早く来よう。'));
    expect(soldOut, isNot(contains('縁がなかっただけのこと。')));
    expect(retreatConsolation('臨時休業', 'v1'), retreatConsolation('臨時休業', 'v1'));
    final closed = {
      for (var i = 0; i < 30; i++) retreatConsolation('臨時休業', 'v$i'),
    };
    expect(closed, contains('縁がなかっただけのこと。'));
  });

  test('あの日の一杯の一文は、記録と年数で決まり、年数を正しく書く', () {
    expect(memoryWhisper('v1', 1), memoryWhisper('v1', 1));
    final lines = {
      for (var i = 0; i < 50; i++) memoryWhisper('v$i', 1),
      for (var i = 0; i < 50; i++) memoryWhisper('v$i', 3),
    };
    expect(lines, contains('あの一杯から、もう一年。'));
    expect(lines, contains('あの一杯から、もう三年。'));
  });

  test('通知の本文は週ごとに変わり、同じ日なら同じ', () {
    final sunday = DateTime(2026, 10, 4, 18);
    expect(streakReminderBody(sunday), streakReminderBody(sunday));
    final bodies = {
      for (var w = 0; w < 12; w++)
        streakReminderBody(sunday.add(Duration(days: 7 * w))),
    };
    expect(bodies.length, greaterThan(1));
  });
}
