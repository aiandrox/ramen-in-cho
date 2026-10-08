"""紹介ページ（site/public/img/）の絵を、docs の見本とアプリのアイコンから切り出す。

使い方（site/ で）:
  python3 scripts/lp_images.py         # public/img を作り直す
  python3 scripts/lp_images.py check   # public/img が元の絵から作ったものと同じか確かめる（CI）
要るもの: scripts/requirements.txt（Pillow）
"""

import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'site/public/img'
ICON = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'
# 切り出す位置は、この大きさの見本に合わせてある。見本の並びが変わったら位置も直す。
SOURCE_SIZES = {
    'docs/seals/catalog.png': (1800, 2918),
    'docs/buttons/catalog.png': (1520, 2864),
    'docs/buttons/tab_seals.png': (2480, 584),
}
PAPER = np.array([243, 236, 223], float)  # Washi.paper。見本の地の色
FADED = (138, 129, 117)  # Washi.faded
AI = np.array([38, 52, 74], float)  # アイコンの表紙の藍
SHU = np.array([179, 38, 30], float)  # アイコンの朱印
REGIONS = ['hokkaido', 'tohoku', 'kanto', 'tokyo', 'koshinetsu', 'hokuriku',
           'tokai', 'kinki', 'chugoku', 'shikoku', 'kyushu', 'okinawa']
TABS = ['inchou', 'negai', 'shugyo', 'chizu']

# docs/seals/catalog.png: 1マス 216px（108pt×2）。良・秀・妙・極・撤退・まだ の6列、地方ごとの行。
SEALS = ['hokkaido-0', 'tohoku-2', 'kanto-0', 'kanto-1', 'kanto-2', 'kanto-3', 'kanto-4',
         'tokyo-1', 'tokyo-3', 'koshinetsu-1', 'hokuriku-0', 'tokai-2', 'kinki-1',
         'chugoku-3', 'shikoku-0', 'kyushu-3']
BLANKS = ['tohoku', 'hokuriku', 'kinki', 'chugoku', 'okinawa']
HIDEN = ['dawn', 'double_bowl', 'far_journey', 'first_bowl', 'jiro', 'long_wish',
         'queue_60', 'third_time']
# 「まだ見ぬ秘伝」は、名前を出さない秘伝の印をぼかして灰色にする。
HIDEN_UNKNOWN = ['queue_90', 'perfect', 'pilgrimage', 'summer_cold']
# docs/buttons/catalog.png の（左, 上, 幅, 高さ）
BUTTONS = {
    'stamp-men': (32, 1460, 144, 150),
    'stamp-chaku': (192, 1460, 144, 150),
    'ema': (349, 1483, 126, 115),
    'styles': (31, 1956, 697, 284),
}


def to_alpha(im):
    """見本の地の色を透明にする（GIMP の「色を透明度に」と同じ考え方）。"""
    a = np.array(im.convert('RGB')).astype(float)
    d = a - PAPER
    alpha = np.clip((np.abs(d) / np.where(d > 0, 255 - PAPER, PAPER)).max(-1), 0, 1)
    return unmix(a, PAPER, alpha)


def cut_from_ai(im):
    """アイコンの藍の地を透明にし、朱印だけを残す。"""
    a = np.array(im.convert('RGB')).astype(float)
    alpha = np.clip(np.linalg.norm(a - AI, axis=-1) / np.linalg.norm(SHU - AI), 0, 1)
    return unmix(a, AI, alpha)


def unmix(a, bg, alpha):
    with np.errstate(invalid='ignore', divide='ignore'):
        rgb = np.where(alpha[..., None] > 0, (a - bg * (1 - alpha[..., None])) / alpha[..., None], 0)
    return Image.fromarray(
        np.dstack([np.clip(rgb, 0, 255), alpha * 255]).round().astype(np.uint8), 'RGBA')


def trim(im, threshold=8):
    ys, xs = np.where(np.array(im)[..., 3] > threshold)
    if xs.size == 0:
        raise ValueError('切り出した所に絵が無い（見本の並びが変わった？）')
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def fit(im, longest):
    s = longest / max(im.size)
    return im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)


def source(path):
    im = Image.open(ROOT / path)
    if im.size != SOURCE_SIZES[path]:
        sys.exit(f'{path} の大きさが {im.size} に変わった。scripts/lp_images.py の切り出す位置を直す')
    return im


def build(icon):
    seals = source('docs/seals/catalog.png')
    buttons = source('docs/buttons/catalog.png')
    tabs = source('docs/buttons/tab_seals.png')

    def cell(row, col):
        x, y = 360 + 216 * col, 78 + 216 * row
        return (x, y, x + 216, y + 216)

    for name in SEALS:
        region, col = name.rsplit('-', 1)
        yield f'seal-{name}', to_alpha(seals.crop(cell(REGIONS.index(region), int(col)))).resize((168, 168), Image.LANCZOS)
    for region in BLANKS:
        yield f'blank-{region}', to_alpha(seals.crop(cell(REGIONS.index(region), 5))).resize((120, 120), Image.LANCZOS)
    for name in HIDEN:
        yield f'hiden-{name.replace("_", "-")}', Image.open(ROOT / f'docs/hiden/{name}.png').convert('RGBA').resize((168, 168), Image.LANCZOS)
    for i, name in enumerate(HIDEN_UNKNOWN):
        alpha = (Image.open(ROOT / f'docs/hiden/{name}.png').convert('RGBA').getchannel('A')
                 .resize((120, 120), Image.LANCZOS).filter(ImageFilter.GaussianBlur(4))
                 .point(lambda v: round(v * 0.53)))
        im = Image.new('RGBA', (120, 120), FADED)
        im.putalpha(alpha)
        yield f'hiden-unknown-{i}', im
    for name, (x, y, w, h) in BUTTONS.items():
        yield name, to_alpha(buttons.crop((x, y, x + w, y + h)))
    # docs/buttons/tab_seals.png の「4倍」の段（128pt×2）。左が選んだとき、右が選んでいないとき。
    for i, name in enumerate(TABS):
        for selected in (True, False):
            x = 40 + 608 * i + (0 if selected else 320)
            im = fit(trim(to_alpha(tabs.crop((x - 8, 248, x + 264, 520)))), 72)
            yield f'tab-{name}{"-on" if selected else ""}', im
    yield 'bowl-seal', cut_from_ai(icon.crop((256, 490, 625, 859))).resize((360, 360), Image.LANCZOS)


def write(out):
    icon = Image.open(ICON).convert('RGBA')
    for name, im in build(icon):
        im.save(out / f'{name}.webp', 'WEBP', quality=85, method=6, exact=True)
    icon.resize((512, 512), Image.LANCZOS).save(out / 'og-icon.png', optimize=True)
    icon.resize((180, 180), Image.LANCZOS).save(out / 'apple-touch-icon.png', optimize=True)


def check():
    with tempfile.TemporaryDirectory() as tmp:
        write(Path(tmp))
        made = {p.name: p.read_bytes() for p in Path(tmp).iterdir()}
    stale = sorted(n for n, b in made.items() if not (OUT / n).exists() or (OUT / n).read_bytes() != b)
    if stale:
        sys.exit(f'元の絵と合わない: {", ".join(stale)}\npython3 scripts/lp_images.py で作り直してください（site/README.md）')
    print(f'{len(made)}枚とも、元の絵から作ったものと同じ')


if __name__ == '__main__':
    if sys.argv[1:] == ['check']:
        check()
    elif not sys.argv[1:]:
        write(OUT)
    else:
        sys.exit('使い方: python3 scripts/lp_images.py [check]')
