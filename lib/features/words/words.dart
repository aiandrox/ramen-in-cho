import '../inkan/inkan.dart';
import '../scoring/ranks.dart';

/// [key]から決まった1つを選ぶ。同じ記録・同じ週には、いつも同じ言葉が出る。
String pickWord(String key, List<String> options) {
  final hash = key.codeUnits.fold<int>(
    0,
    (sum, unit) => (sum * 31 + unit) & 0x7fffffff,
  );
  return options[hash % options.length];
}

/// 段位に上がったときの、師匠のひとこと。
String masterWords(AdventurerRank rank) => switch (rank) {
  AdventurerRank.apprentice => 'よく来た。まずは一杯、すすってみよ。',
  AdventurerRank.kyu5 => '最初の一杯、しかと見届けた。',
  AdventurerRank.kyu4 => '暖簾をくぐる手が、少し慣れてきたな。',
  AdventurerRank.kyu3 => 'まずはスープをひと口。それが作法だ。',
  AdventurerRank.kyu2 => '店の前の行列に、心が躍りはじめたか。',
  AdventurerRank.kyu1 => '段の入口は、もう目の前だ。',
  AdventurerRank.dan1 => 'ようやく入口に立ったな。',
  AdventurerRank.dan2 => '箸の運びが、少しさまになってきた。',
  AdventurerRank.dan3 => '並ぶことを、苦にしなくなったか。',
  AdventurerRank.dan4 => 'スープの声が、聞こえはじめたようだ。',
  AdventurerRank.dan5 => 'ここで半ば。慢心するでないぞ。',
  AdventurerRank.dan6 => '麺の硬さを、口に入れる前に見抜くか。',
  AdventurerRank.dan7 => '幻の店すら、おぬしを待っておる。',
  AdventurerRank.dan8 => '一杯ごとに、道が深くなっておるな。',
  AdventurerRank.dan9 => 'あと一歩。己の舌を信じよ。',
  AdventurerRank.master => '今日からは、教える側でもある。',
  AdventurerRank.grandmaster => 'もう教えることはない。',
};

enum RetreatReason { soldOut, closed, noTime, other }

/// 撤退のメモから理由を読み取る。
RetreatReason retreatReasonOf(String memo) {
  if (RegExp('売り?切|品切|完売|スープ切').hasMatch(memo)) {
    return RetreatReason.soldOut;
  }
  if (RegExp('休').hasMatch(memo)) return RetreatReason.closed;
  if (RegExp('時間|間に合わ|閉店').hasMatch(memo)) return RetreatReason.noTime;
  return RetreatReason.other;
}

const _consolations = {
  RetreatReason.soldOut: [
    '人気の証。次は早く来よう。',
    '売り切れるほどの一杯。待つ価値はある。',
    'スープが尽きるまで愛される店だ。',
  ],
  RetreatReason.closed: ['縁がなかっただけのこと。', '店にも休む日はある。また来よう。', '暖簾は逃げない。日を改めよう。'],
  RetreatReason.noTime: ['退くのもまた修行。', '時が満ちるのを待とう。', '今日の空腹は、次の一杯の味方になる。'],
  RetreatReason.other: ['退くのもまた修行。', 'この借りは、次の一杯で返そう。', '道は続く。また挑めばいい。'],
};

/// 撤退したあとの慰め。[visitId]は撤退の記録のID。
String retreatConsolation(String memo, String visitId) =>
    pickWord(visitId, _consolations[retreatReasonOf(memo)]!);

/// 何年か前の今日の1杯に添える一文。
String memoryWhisper(String visitId, int yearsAgo) {
  final years = '${proseNumber(yearsAgo)}年';
  return pickWord('$visitId#$yearsAgo', [
    'あの日の味を覚えていますか。',
    'あの一杯から、もう$years。',
    '湯気の向こうに、あの日が見えます。',
    'あの丼の底に、何が残っていましたか。',
    '同じ暖簾を、もう一度くぐってみては。',
  ]);
}

/// 連続記録が途切れそうな週に送る通知の本文。[remindAt]の日で選ぶ。
String streakReminderBody(DateTime remindAt) =>
    pickWord('${remindAt.year}-${remindAt.month}-${remindAt.day}', const [
      '今週はまだ着丼していません。日曜が終わるまでに一杯いかがですか？',
      '修行は一日にしてならず。今週の一杯、まだ間に合います。',
      '丼が待っています。今週のうちに暖簾をくぐりましょう。',
      '師匠が見ています。今週の一杯で、連続を守りましょう。',
      '今週の印帳がまだ白紙です。日曜のうちに一杯どうですか？',
      '湯気の立つ一杯で、今週を締めくくりませんか。',
    ]);

/// 年の振り返りの最後に添える、師匠のひとこと。同じ年にはいつも同じ言葉が出る。
String yearClosingWords(int year) => pickWord('year:$year', const [
  'よく食べ、よく並んだ一年であった。来年も丼の前で会おう。',
  '一杯一杯が、おぬしの道をつくった。',
  'スープの底に、この一年が沈んでおる。',
  '退いた日も、並んだ日も、すべて修行よ。',
  '来年はどんな暖簾をくぐるのか。楽しみにしておるぞ。',
]);
