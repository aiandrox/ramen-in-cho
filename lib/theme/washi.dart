import 'package:flutter/material.dart';

import 'washi_buttons.dart';

/// 和紙と墨と藍と朱の色、筆文字と明朝の書体。
///
/// 画面の部品（ボタン・選んだ印・進み具合など）は藍、朱は印だけに使う。
abstract final class Washi {
  static const paper = Color(0xFFF3ECDF);
  static const desk = Color(0xFFE9E1D2);
  static const page = Color(0xFFFBF8F1);
  static const ink = Color(0xFF1D1A17);
  static const inkSoft = Color(0xFF5C554D);
  static const line = Color(0xFFCFC3AD);
  static const faded = Color(0xFF8A8175);

  /// アプリのアイコン（印帳の表紙）の藍。
  static const ai = Color(0xFF26344A);
  static const aiDeep = Color(0xFF1A2536);

  /// 墨色の背景（着丼直後の画面・並び中の帯）の上で使う藍。
  static const aiLight = Color(0xFF9DB0D0);
  static const shu = Color(0xFFB3261E);
  static const shuLight = Color(0xFFE46A5F);
  static const nightSoft = Color(0xFFC9BFAE);

  static const brush = 'YujiSyuku';
  static const mincho = 'ShipporiMincho';
}

/// 台紙に貼った写真のように、白い縁と薄い影をつけて少し傾ける。
class PastedPhoto extends StatelessWidget {
  const PastedPhoto({
    super.key,
    required this.child,
    this.angle = 0,
    this.border = 4,
  });

  final Widget child;
  final double angle;
  final double border;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(padding: EdgeInsets.all(border), child: child),
      ),
    );
  }
}

/// 縦書きの文字列。1文字ずつ縦に積み、筆文字の縦書き用の字形を使う。
/// 1行に収まらないときは、右から左へ2行目に折り返す。
class VerticalText extends StatelessWidget {
  const VerticalText(
    this.text, {
    super.key,
    required this.style,
    this.maxChars,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle style;

  /// 1行の最大の文字数。nullなら折り返さない。
  final int? maxChars;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final lines = verticalLines(text, maxChars: maxChars, maxLines: maxLines);
    // 縦書き用の字形（縦向きの長音・右上に寄った小さい「っ」など）に切り替える。
    final charStyle = style.copyWith(
      height: 1.15,
      fontFeatures: const [FontFeature.enable('vert')],
    );
    // 文字ごとに幅が違っても列がそろうよう、1文字ずつ同じ大きさの枠の中央に置く。
    final cell = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14);
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 縦書きは右の行から読むので、1行目を右に置く。
              for (final line in lines.reversed)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final char in line)
                      if (char == verticalSpace)
                        SizedBox(height: cell * 0.5)
                      else
                        SizedBox(
                          width: cell * 1.1,
                          height: cell * 1.15,
                          child: Center(
                            child: Text(
                              char,
                              style: charStyle,
                              textAlign: TextAlign.center,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 縦書きの行に分ける。1行に収まらなければ、きりのいいところで2行にする。
/// 区切りの空白がいちばんよく、次に文字の種類の変わり目（漢字とかな、カナと漢字など）。
/// 小さい「ゃ」や「ー」「ん」で行が始まる分け方は避ける。きりのいいところなら、
/// 1文字だけ長くてもよい（少し縮めて表示する）。[maxLines]行に収まらないときは、
/// 最後の文字を「…」（縦書きでは縦向き）にする。
/// [verticalLines]の結果で、半文字分のすき間を表す。
const verticalSpace = ' ';

List<List<String>> verticalLines(
  String text, {
  int? maxChars,
  int maxLines = 2,
}) {
  final chars = <String>[];
  final spaceBefore = <int>{};
  for (final rune in text.trim().runes) {
    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) {
      spaceBefore.add(chars.length);
    } else {
      chars.add(char);
    }
  }
  if (maxChars == null || chars.length <= maxChars) {
    // 1行に収まるときは、区切りの空白を半文字分のすき間として残す。
    return [
      [
        for (var i = 0; i < chars.length; i++) ...[
          if (spaceBefore.contains(i)) verticalSpace,
          chars[i],
        ],
      ],
    ];
  }
  if (maxLines >= 2) {
    final at = _bestBreak(chars, spaceBefore, maxChars);
    if (at != null) return [chars.sublist(0, at), chars.sublist(at)];
  }

  final lines = <List<String>>[
    for (var i = 0; i < chars.length && i ~/ maxChars < maxLines; i += maxChars)
      chars.sublist(i, (i + maxChars).clamp(0, chars.length)),
  ];
  if (chars.length > maxChars * maxLines) {
    lines.last = [...lines.last.take(maxChars - 1), '…'];
  }
  return lines;
}

const _noLineStart = {
  'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ', 'っ', 'ゃ', 'ゅ', 'ょ', 'ゎ', 'ん', //
  'ァ', 'ィ', 'ゥ', 'ェ', 'ォ', 'ッ', 'ャ', 'ュ', 'ョ', 'ヮ', 'ン', //
  'ー', '々', '、', '。', '」', '）', ')', '・', '…',
};
const _noLineEnd = {'「', '（', '('};

enum _Script { kanji, hiragana, katakana, latin, other }

_Script _scriptOf(String char) {
  final code = char.runes.first;
  if ((code >= 0x4E00 && code <= 0x9FFF) || code == 0x3005) {
    return _Script.kanji;
  }
  if (code >= 0x3041 && code <= 0x309F) return _Script.hiragana;
  if (code >= 0x30A1 && code <= 0x30FF) return _Script.katakana;
  if (RegExp(r'[A-Za-z0-9Ａ-Ｚａ-ｚ０-９]').hasMatch(char)) return _Script.latin;
  return _Script.other;
}

/// 2行に分ける位置（1行目の文字数）。きりのいい位置が無ければnull。
int? _bestBreak(List<String> chars, Set<int> spaceBefore, int maxChars) {
  int? best;
  var bestScore = double.negativeInfinity;
  for (var at = 1; at < chars.length; at++) {
    final first = at;
    final second = chars.length - at;
    final isSpace = spaceBefore.contains(at);
    // 「ー」は前の文字と同じ種類として扱う（「ラーメン」の途中で分けないため）。
    final isScriptChange =
        chars[at] != 'ー' && _scriptOf(chars[at - 1]) != _scriptOf(chars[at]);
    final isGood = isSpace || isScriptChange;
    final limit = maxChars + (isGood ? 1 : 0);
    if (first > limit || second > limit) continue;
    var score = 0.0;
    if (isSpace) score += 10;
    if (isScriptChange) score += 4;
    if (_noLineStart.contains(chars[at])) score -= 20;
    if (_noLineEnd.contains(chars[at - 1])) score -= 20;
    if (first > maxChars || second > maxChars) score -= 1;
    score -= (first - second).abs() * 0.5;
    // 同じ点なら、1行目を長くする（縦書きは右の行から読むため）。
    score += first * 0.01;
    if (score > bestScore) {
      bestScore = score;
      best = at;
    }
  }
  return best;
}

/// 筆文字の見出し。下に細い墨の線を引く。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.ruled = true});

  final String text;
  final Widget? trailing;

  /// false なら下の罫線を引かない（入力欄の多い画面で、欄の枠と見分けやすくするため）。
  final bool ruled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ruled
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Washi.line)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: Washi.brush,
                fontSize: 20,
                color: Washi.ink,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 画面の右下の「＋」ボタン。どの画面でも同じ形（朱の丸印）にする。
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SealFab(
      tooltip: tooltip,
      onPressed: onPressed,
      brush: true,
      child: const Icon(Icons.add),
    );
  }
}
