import '../records/models.dart';

/// 道中記の言い回しの候補。{ } の中は、その1杯の数字や名前に置き換わる。
/// 数は漢数字で入る（待ち時間の分と修行点はアラビア数字。100を超える半端な数もアラビア数字）。
/// 候補の中から記録のIDで1つに決めるので、並びを変えると過去の道中記の文も変わる。空の文は「何も添えない」。
///
/// 一覧は `docs/journal/README.md`（`test/tool/journal_catalog_test.dart` で作る）。
class Phrases {
  const Phrases(this.when, this.lines);

  /// どんな1杯のときに使うか（一覧に出す説明）。
  final String when;
  final List<String> lines;

  List<String> fill([Map<String, Object> values = const {}]) => [
    for (final line in lines)
      line.replaceAllMapped(
        _placeholder,
        (m) => values.containsKey(m[1]) ? '${values[m[1]]}' : m[0]!,
      ),
  ];
}

final _placeholder = RegExp(r'\{([^{}]+)\}');

/// 一覧の見出しごとのまとまり（道中記の文の順）。
class PhraseSection {
  const PhraseSection(this.title, this.phrases, {this.note = ''});

  final String title;
  final String note;
  final List<Phrases> phrases;
}

// 書き出し

const wishOpening = Phrases('願を掛けた店で食べた（きっかけなし）', ['{日付}、願を掛けた店。']);
const wishOpeningWithTrigger = Phrases('願を掛けた店で食べた（きっかけあり）', [
  '{日付}、願を掛けた店。きっかけは「{きっかけ}」。',
]);
const firstRetreatOpening = Phrases('初めての店で、食べずに撤退', [
  '初めて挑む道場。',
  'まだ見ぬ道場へ。',
  '噂の道場に初めて挑む。',
  '初陣の道場。',
]);
const firstVisitOpening = Phrases('初めての店', [
  'まだ見ぬ{軒}軒目の道場へ。',
  '{軒}軒目の道場の暖簾をくぐる。',
  '新たな道場、{軒}軒目。',
  '{軒}軒目、未踏の道場へ。',
  '初めての暖簾、{軒}軒目。',
  '門を叩く。{軒}軒目の道場。',
  '新しい道場、{軒}軒目の扉。',
]);
const repeatOpening = Phrases('2度目以降の店', [
  '通うこと{度}度目。',
  '{度}度目の来訪。',
  'またこの暖簾をくぐる。{度}度目。',
  '勝手知ったる道場、{度}度目。',
  '再びこの道場へ。{度}度目。',
  '{度}度目の暖簾をくぐる。',
  '馴染みの道場へ、{度}度目。',
  'あの味をもう一度。{度}度目。',
]);

// 節目・間隔・特別な日

/// 通算の杯数の節目。
const milestoneBowls = {10, 30, 50, 100, 200, 300, 500, 1000};

const newYearsFirstMoment = Phrases('1月1日のその日最初の1杯', ['年明け最初の一杯。']);
const newYearsEveMoment = Phrases('12月31日', ['大晦日の一杯。']);
const firstOfYearMoment = Phrases('その年の最初の1杯（元日の最初の1杯と、初めての1杯は除く）', ['今年の初麺。']);
const milestoneMoment = Phrases('通算 10・30・50・100・200・300・500・1000 杯目', [
  '通算{杯}杯目の節目。',
]);
const sameDayMoment = Phrases('同じ日の2杯目以降', ['本日{杯}杯目。']);
const streakMoment = Phrases('3日以上続けて食べた', ['{日}日連続の麺修行。']);
const yearsApartMoment = Phrases('同じ店に1年以上ぶり', ['{年}年ぶりの再会。']);
const longGapMoment = Phrases('同じ店に90日以上ぶり', ['久しぶりの暖簾。']);
const regularMoment = Phrases('同じ店で5杯目', ['常連の域に入った。']);
const secondHomeMoment = Phrases('同じ店で10杯目', ['十度目。もはや第二の我が家。']);

// 時間帯・曜日・季節

const sceneHour6 = Phrases('6時台', [
  '明け六つ、朝一番の一杯。',
  '朝の澄んだ空気の中、朝ラーの暖簾へ。',
  '始発の頃、暖簾が上がる。',
  '朝焼けを背に、一番乗り。',
]);
const sceneHour18 = Phrases('18時台', [
  '暮れ六つの鐘とともに。',
  '一日の終わりに、夜の暖簾へ。',
  '街に灯がともる頃。',
  '夕焼けに暖簾が映える。',
]);
const sceneHour2 = Phrases('2時台', [
  '丑三つ時の一杯。',
  '真夜中の一杯は、背徳の味。',
  '草木も眠る刻の一杯。',
  '夜更けの背徳をすする。',
]);
const sceneMorning = Phrases('5〜10時台（6時台を除く）', [
  '朝の澄んだ空気の中、朝ラーの暖簾へ。',
  '一日の始まりは一杯から。',
  '朝の胃袋に、優しい一杯。',
  '眠気覚ましの一杯。',
]);
const sceneNoon = Phrases('11〜14時台', [
  '昼どきの喧騒をくぐり抜けて。',
  '腹の虫が鳴る昼下がり。',
  '正午の鐘を聞きながら。',
  '昼休みの一杯に賭ける。',
]);
const sceneAfternoon = Phrases('15〜17時台', [
  '中休み前のすき間を狙って。',
  '夕暮れ前のひと休み。',
  '昼の喧騒が過ぎた頃。',
  '遅めの昼に一杯。',
]);
const sceneEvening = Phrases('19〜22時台', [
  '一日の終わりに、夜の暖簾へ。',
  '夜風に誘われて。',
  '夜の帳が下りる頃。',
  'ネオンの灯りに誘われて。',
]);
const sceneNight = Phrases('23〜4時台（2時台を除く）', [
  '真夜中の一杯は、背徳の味。',
  '眠らない街の灯りの下で。',
  '終電を気にしながら。',
  '夜更けの一杯は格別。',
]);
const sceneWeekend = Phrases('土日', ['休日の気ままな一杯。', '休みの日こそ麺修行。']);
const sceneFridayNight = Phrases('金曜の18時以降', ['花金の一杯。', '週末の始まりを祝う一杯。']);
const sceneMonday = Phrases('月曜', ['週の始まりに気合を入れる。', '月曜の憂鬱を湯気で払う。']);
const sceneWinter = Phrases('12〜2月', ['冷えた体に湯気がしみる。', '白い息を吐きながら。']);
const sceneSummer = Phrases('6〜8月', ['汗をぬぐいながらすする。', '暑さに負けず、熱い一杯。']);
const sceneSpring = Phrases('3〜5月', ['春の陽気に誘われて。', '桜の便りを聞きながら。']);
const sceneAutumn = Phrases('9〜11月', ['秋の夜長にもう一杯。', '秋風に誘われて。']);

/// 時間帯・曜日・季節の候補に足す、何も添えない分。
const sceneSkip = Phrases('（何も添えない分）', ['', '']);

// 地名

const nearArea = Phrases('いつもの店から20km未満', [
  '{地名}の街で。',
  '{地名}の空の下で。',
  '{地名}にて。',
  '{地名}の町角で。',
  'ふらりと{地名}へ。',
  '{地名}の路地をゆく。',
  '{地名}の片隅で。',
  '{地名}の通りで。',
  '',
]);
const farArea = Phrases('いつもの店から20km以上80km未満', [
  '遠く{地名}まで足をのばして。',
  'はるばる{地名}へ。',
  '少し遠出して{地名}へ。',
  '今日は{地名}まで遠出。',
  '{地名}まで、ひと足のばして。',
  '見知らぬ{地名}の街で。',
]);
const expeditionArea = Phrases('いつもの店から80km以上（遠征）', [
  '今日は{地名}まで遠征。',
  '遠征の地、{地名}。',
  'はるばる{地名}まで遠征。',
  '旅の空の下、{地名}にて。',
  '{地名}へ、修行の旅。',
  '旅先の{地名}で一杯。',
]);

// 撤退

/// 撤退のメモが無いか長いときの、撤退の理由。
const unknownReason = '思わぬ壁';

const retreatedOnceBefore = Phrases('前回この店で撤退した', ['前回は{理由}に阻まれ、撤退した。']);
const retreatedManyBefore = Phrases('この店で続けて2回以上撤退した', ['{回}度の撤退を越えて、ここまで来た。']);
const retreatWaited = Phrases('並んでから撤退した', ['{分}分並んだが、']);
const retreatBlocked = Phrases('撤退した', ['{理由}に阻まれ、撤退。']);
const retreatClosing = Phrases('撤退した（締め）', [
  '次こそは。',
  'この借りは、必ず返す。',
  '出直しだ。',
  '必ずまた来る。',
]);

// 行列

const longWait = Phrases('60分以上並んだ', [
  '{分}分の長い行列を耐え抜き、',
  '並ぶこと{分}分。足が棒になっても、',
  '{分}分の試練を越え、',
  '{分}分、ひたすら待ち続け、',
]);
const shortWait = Phrases('1〜59分並んだ', [
  '行列に並ぶこと{分}分、',
  '{分}分の行列を越え、',
  '{分}分の待ちを経て、',
  '並んで{分}分、',
]);

// 系統

const flavors = <RamenStyle, Phrases>{
  RamenStyle.shoyu: Phrases('醤油', [
    '澄んだ醤油の香りが立つ。',
    '黄金色のスープに顔が映る。',
    '醤油の深い色に見入る。',
    '鶏油がきらりと光る。',
    '',
  ]),
  RamenStyle.miso: Phrases('味噌', [
    '濃厚な湯気に包まれる。',
    '味噌の香りが鼻をくすぐる。',
    '炒めた野菜の香ばしさ。',
    '熱々のスープで体が温まる。',
    '',
  ]),
  RamenStyle.shio: Phrases('塩', [
    '透きとおるスープをひと口。',
    '塩の一杯は、ごまかしがきかない。',
    '澄んだスープに麺が泳ぐ。',
    'あっさりの奥に旨みが潜む。',
    '',
  ]),
  RamenStyle.tonkotsu: Phrases('豚骨', [
    '白濁のスープが香り立つ。',
    '替え玉の誘惑と戦う。',
    '細麺を硬めでたのむ。',
    '紅しょうがをひとつまみ。',
    '',
  ]),
  RamenStyle.iekei: Phrases('家系', [
    '海苔をスープに浸して。',
    '「お好みは？」に「硬め濃いめ多め」。',
    'ライスにスープを染み込ませて。',
    'ほうれん草を麺に絡めて。',
    '',
  ]),
  RamenStyle.jiro: Phrases('二郎', [
    '「ニンニク入れますか？」に静かに頷く。',
    '野菜の山を崩しにかかる。',
    '天地返しで挑む。',
    '極太麺と格闘する。',
    '',
  ]),
  RamenStyle.tsukemen: Phrases('つけ麺', [
    '麺をつけ汁にくぐらせて。',
    '最後はスープ割りで締める。',
    '極太麺の喉ごしを味わう。',
    '濃厚なつけ汁に麺を泳がせて。',
    '',
  ]),
  RamenStyle.shirunashi: Phrases('汁なし', [
    '底からよく混ぜて。',
    '追い飯まで抜かりなく。',
    '卓上の酢とラー油で味変。',
    'タレが麺に絡みつく。',
    '',
  ]),
};

// 着丼

const dramaticBowl = Phrases('願の店・撤退のあと・60分以上並んだ', [
  'ついに着丼。{一杯}、修行点 {点}。',
  '待ち焦がれた着丼。{一杯}、修行点 {点}。',
  '苦難の末に着丼。{一杯}、修行点 {点}。',
]);
const bowl = Phrases('そのほか', [
  '着丼。{一杯}、修行点 {点}。',
  '丼が置かれた。{一杯}、修行点 {点}。',
  '湯気の向こうに{一杯}、修行点 {点}。',
  '待望の{一杯}、修行点 {点}。',
  '運ばれてきた{一杯}、修行点 {点}。',
  '目の前に{一杯}、修行点 {点}。',
  '着丼の瞬間。{一杯}、修行点 {点}。',
  'カウンター越しに{一杯}、修行点 {点}。',
]);

// 記録の更新（当てはまるうち最初の1つ）

const bestPointsRecord = Phrases('自己最高の修行点', ['自己最高の修行点を更新。']);
const shopRankSRecord = Phrases('この店で初めて修行点60以上（印が極に）', ['この道場の印は「極」に。']);
const longestWaitRecord = Phrases('この店でいちばん長く並んだ', ['この店で最長の待ち。']);

// ★

const verdicts = <int, Phrases>{
  5: Phrases('★5', [
    '文句なしの一杯。また必ず来る。',
    'これぞ求めていた味。',
    '箸が止まらなかった。',
    'スープまで一滴残らず。',
    '一生ものの一杯。',
    '完食、完飲。言葉はいらない。',
  ]),
  4: Phrases('★4', [
    '満足の一杯。',
    'いい道場に出会えた。',
    'また来たいと思える味。',
    '箸が進む、いい一杯。',
    '次は別のメニューも。',
  ]),
  3: Phrases('★3', ['悪くない。', '可もなく不可もなく、それもまた修行。', 'いつもの安心する味。', '腹は満ちた。']),
  2: Phrases('★2', ['今日はあと一歩。', '好みとは少し違った。', 'もう一工夫ほしい。', '次は別の一杯を試したい。']),
  1: Phrases('★1', ['これもまた修行。', '合わない味を知るのも道のうち。', '今日の味は、胸にしまう。']),
};

const memoQuote = Phrases('「この一杯について」が20文字以内で1行（共有カードでは出さない）', [
  '――「{メモ}」と書き残す。',
]);

// 締め

const wishSameDayClosing = Phrases('願を掛けたその日に食べた', ['願を掛けたその日に、願成就。']);
const wishClosing = Phrases('願を掛けた店で食べた', ['{日}日越しの願成就。']);
const retryClosing = Phrases('撤退のあと、同じ店で食べた', [
  '再挑戦、成功。',
  '雪辱を果たす。',
  'リベンジ成就。',
]);
const yearClosing = Phrases('そのほか（今年10杯目・20杯目…の節目には必ず、ほかは3杯に1杯ほど。今年1杯目は添えない）', [
  '今年 {杯}杯目。',
  '今年 {杯}杯目の修行。',
  '修行は続く。今年 {杯}杯目。',
  '麺道、今年 {杯}杯目。',
  '今年の修行、{杯}杯目。',
  '今年 {杯}杯目の着丼。',
  '歩みは止まらず。今年 {杯}杯目。',
]);

final journalCatalog = <PhraseSection>[
  PhraseSection('書き出し', [
    wishOpening,
    wishOpeningWithTrigger,
    firstRetreatOpening,
    firstVisitOpening,
    repeatOpening,
  ]),
  PhraseSection('節目・間隔・特別な日', [
    newYearsFirstMoment,
    newYearsEveMoment,
    firstOfYearMoment,
    milestoneMoment,
    sameDayMoment,
    streakMoment,
    yearsApartMoment,
    longGapMoment,
    regularMoment,
    secondHomeMoment,
  ], note: '食べた1杯だけ。当てはまるものを上から2つまで'),
  PhraseSection('時間帯・曜日・季節', [
    sceneHour6,
    sceneHour18,
    sceneHour2,
    sceneMorning,
    sceneNoon,
    sceneAfternoon,
    sceneEvening,
    sceneNight,
    sceneWeekend,
    sceneFridayNight,
    sceneMonday,
    sceneWinter,
    sceneSummer,
    sceneSpring,
    sceneAutumn,
    sceneSkip,
  ], note: '願の店でも撤退のあとでもない1杯。当てはまる時間帯・曜日・季節の候補をまとめた中から1つ（何も添えないこともある）'),
  PhraseSection('地名', [
    nearArea,
    farArea,
    expeditionArea,
  ], note: '店の市区町村がわかるとき。いつもの店＝その1杯までにいちばん多く食べた店'),
  PhraseSection('撤退', [
    retreatedOnceBefore,
    retreatedManyBefore,
    retreatWaited,
    retreatBlocked,
    retreatClosing,
  ], note: '{理由}は撤退のメモ（10文字以内）。無いか長いときは「$unknownReason」'),
  PhraseSection('行列', [longWait, shortWait]),
  PhraseSection('系統', [...flavors.values], note: '系統を選んだ1杯。何も添えないこともある'),
  PhraseSection(
    '着丼',
    [dramaticBowl, bowl],
    note:
        '{一杯}は「限定の」＋系統名＋「の一杯」（系統なしは「ラーメンの一杯」）。共有カードで修行点を外すため「、修行点 {点}」の形は崩さない',
  ),
  PhraseSection('記録の更新', [
    bestPointsRecord,
    shopRankSRecord,
    longestWaitRecord,
  ], note: '当てはまるもののうち最初の1つ'),
  PhraseSection('★', [...verdicts.values], note: '★を付けた1杯'),
  PhraseSection('この一杯について', [memoQuote]),
  PhraseSection('締め', [
    wishSameDayClosing,
    wishClosing,
    retryClosing,
    yearClosing,
  ]),
];
