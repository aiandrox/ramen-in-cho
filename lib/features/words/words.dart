import '../inkan/inkan.dart';
import '../notifications/notification_calendar.dart';
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

/// ★の付け忘れを知らせる通知の本文。[visitId]で選ぶ。
String ratingReminderBody(String visitId) => pickWord('rating:$visitId', const [
  '★をつけておきましょう。',
  '味の記憶が新しいうちに、★をひとつ。',
  '★をつけて、今日の一杯を印帳に刻みましょう。',
  '師匠が、おぬしの舌の判定を待っておる。',
]);

/// 年の振り返りを勧める通知の本文。[at]の日で選ぶ。
String yearReviewReminderBody(DateTime at) =>
    pickWord('review:${at.year}-${at.month}-${at.day}', const [
      '今年の修行を、ふり返ってみませんか。',
      '一年分の印を、めくってみましょう。',
      'この一年、どれだけの暖簾をくぐったか。確かめてみましょう。',
      '師匠が、今年の総まとめを用意して待っておる。',
    ]);

/// 年始に願掛けを勧める通知の本文。[at]の日で選ぶ。
String newYearWishReminderBody(DateTime at) =>
    pickWord('wish:${at.year}-${at.month}-${at.day}', const [
      '今年行きたい店を、願掛け帳に書き留めましょう。',
      '一年の計は願掛けにあり。今年はどの暖簾をくぐりますか。',
      '新しい年の一杯目は、どこにしますか。願を掛けておきましょう。',
      '今年こそ行きたいあの店に、願を掛けませんか。',
    ]);

/// 20日になってもまだ食べていない月に送る通知の本文。[at]の月で選ぶ。
String monthlyReminderBody(DateTime at) =>
    pickWord('monthly:${at.year}-${at.month}', const [
      '今月はまだ着丼していません。そろそろ一杯いかがですか？',
      '今月の印帳が、まだ白紙です。',
      '月に一度は、暖簾をくぐりましょう。',
      '丼が恋しくなる頃ではありませんか。',
      '今月の一杯は、どの店にしますか。',
    ]);

/// 行事の日に送る通知の本文。同じ年の同じ行事には、いつも同じ言葉が出る。
String eventReminderBody(RamenEvent event, int year) =>
    pickWord('event:${event.name}:$year', switch (event) {
      RamenEvent.valentine => const [
        'バレンタインデー、それは至高の一杯をすする日。',
        '甘いものの前に、熱い一杯を。',
        '今日の贈り物は、自分への一杯で。',
      ],
      RamenEvent.whiteDay => const [
        'ホワイトデー。お返しは、白いスープの一杯で。',
        'お返しに迷ったら、まずは一杯すすってから。',
        '甘いお返しのあとは、しょっぱい一杯を。',
      ],
      RamenEvent.tanabata => const [
        '七夕の夜。短冊に書く願いは、あの店の一杯。',
        '天の川より長い麺を、すすりに行きませんか。',
        '織姫と彦星も、年に一度の一杯を楽しみにしているはず。',
      ],
      RamenEvent.ramenDay => const [
        '今日はラーメンの日。迷わず暖簾をくぐりましょう。',
        'ラーメンの日に、すすらない理由はありません。',
        '今日という日を、一杯で祝いましょう。',
      ],
      RamenEvent.halloween => const [
        'ハロウィンの夜。仮装より、湯気をまといましょう。',
        'トリック・オア・ラーメン。今夜はどの暖簾に？',
        'お菓子もいいけれど、今夜は一杯をくれなきゃ。',
      ],
      RamenEvent.christmas => const [
        'クリスマスに最高の一杯はいかが？',
        '聖なる夜に、湯気の立つ一杯を。',
        'ケーキの前に、まずは一杯。',
      ],
      RamenEvent.newYearsEve => const [
        '大晦日。年越しは、そばよりラーメンで。',
        '今年最後の一杯で、一年を締めくくりましょう。',
        '年越しの一杯は、どの店ですすりますか。',
      ],
    });
