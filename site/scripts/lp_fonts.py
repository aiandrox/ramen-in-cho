"""紹介ページ（site/public/）の書体を、ページで使う字だけに間引いた WOFF2 にする。

  python3 scripts/lp_fonts.py         # public/fonts/*.woff2 を作り直す
  python3 scripts/lp_fonts.py check   # ページに、書体に無い字が入っていないか確かめる（CI）

筆の書体（Yuji Syuku）は lp.css で var(--brush) を使う要素の字だけ、本文の書体（Shippori Mincho）はページのすべての字。
どちらにも ASCII の字は入れておく。元の書体は ../assets/fonts/（アプリと同じもの）。
要るもの: scripts/requirements.txt（fonttools・brotli・beautifulsoup4）
"""

import re
import sys
from pathlib import Path

from bs4 import BeautifulSoup, Comment
from fontTools import subset
from fontTools.ttLib import TTFont

SITE = Path(__file__).resolve().parents[1]
PUBLIC = SITE / 'public'
SOURCES = SITE.parent / 'assets/fonts'
ASCII = {chr(c) for c in range(0x20, 0x7F)}
FONTS = {
    'brush': (SOURCES / 'YujiSyuku-Regular.ttf', PUBLIC / 'fonts/yuji-syuku.woff2'),
    'body': (SOURCES / 'ShipporiMincho-Regular.ttf', PUBLIC / 'fonts/shippori-mincho.woff2'),
}
BRUSH = re.compile(r'var\(--brush\)|Yuji Syuku')
BRUSH_RULE = re.compile(r'font(-family)?\s*:[^;}]*(var\(--brush\)|Yuji Syuku)')
PSEUDO = re.compile(r'::?[\w-]+(\([^)]*\))?')
NOT_ELEMENT = re.compile(r'^(@|from$|to$|\d+(\.\d+)?%$)')


def text_of(node):
    if node.name in ('script', 'style', 'title', 'head'):
        return ''
    return ''.join(
        str(s) for s in node.find_all(string=True)
        if not isinstance(s, Comment) and s.parent.name not in ('script', 'style', 'title')
    ) if node.name else str(node)


def brush_selectors(css):
    css = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
    for selectors, body in re.findall(r'([^{}]+)\{([^{}]*)\}', css):
        if BRUSH_RULE.search(body):
            for selector in selectors.split(','):
                selector = selector.strip()
                if selector and not NOT_ELEMENT.match(selector):
                    yield PSEUDO.sub('', selector).strip() or '*'


def css_content(css):
    found = re.findall(r'content:\s*(?:"([^"]*)"|\'([^\']*)\')', css)
    text = ''.join(a + b for a, b in found)
    return re.sub(r'\\([0-9a-fA-F]{1,6})\s?', lambda m: chr(int(m.group(1), 16)), text)


def needed():
    css = (PUBLIC / 'lp.css').read_text(encoding='utf-8')
    selectors = list(brush_selectors(css))
    extra = css_content(css)
    brush, body = set(extra), set(extra)
    unused = set(selectors)
    for page in sorted(PUBLIC.glob('*.html')):
        soup = BeautifulSoup(page.read_text(encoding='utf-8'), 'html.parser')
        root = soup.body or soup
        body |= set(text_of(root))
        for selector in selectors:
            nodes = root.select(selector)
            if nodes:
                unused.discard(selector)
            for node in nodes:
                brush |= set(text_of(node))
        for node in root.find_all(True):
            if BRUSH_RULE.search(node.get('style', '')) or BRUSH.search(node.get('font-family', '')):
                brush |= set(text_of(node))
    for selector in sorted(u for u in unused if '.' in u):
        # lp.js が後から付ける class で決まる要素は、ここでは見えない
        print(f'注意: 筆の書体の「{selector}」に当たる要素がページに無い', file=sys.stderr)
    return {'brush': brush, 'body': body}


def available(font):
    return {chr(c) for c in TTFont(font).getBestCmap()}


def build():
    chars = needed()
    for key, (source, out) in FONTS.items():
        text = ''.join(sorted((chars[key] | ASCII) & available(source)))
        options = subset.Options()
        options.flavor = 'woff2'
        options.layout_features = ['*']
        options.name_IDs = ['*']
        options.notdef_outline = True
        font = subset.load_font(str(source), options)
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=text)
        subsetter.subset(font)
        subset.save_font(font, str(out), options)
        print(f'{out.relative_to(SITE)}: {len(text)}字 {out.stat().st_size // 1024}KB')


def check():
    chars = needed()
    ok = True
    for key, (source, out) in FONTS.items():
        missing = sorted((chars[key] & available(source)) - available(out))
        if missing:
            ok = False
            print(f'{out.relative_to(SITE)} に無い字: {"".join(missing)}')
    if not ok:
        print('python3 scripts/lp_fonts.py で書体を作り直してください（site/README.md）')
        sys.exit(1)
    print('ページの字は、すべて書体に入っている')


if __name__ == '__main__':
    if sys.argv[1:] == ['check']:
        check()
    elif not sys.argv[1:]:
        build()
    else:
        sys.exit('使い方: python3 scripts/lp_fonts.py [check]')
