# 紹介ページの書体の間引きと絵の切り出しを、作り直せる手順としてリポジトリに置く

- 日付: 2026-10-07
- 決定: `site/scripts/lp_fonts.py`（書体をページで使う字だけの WOFF2 にする。`check` でページに書体に無い字が無いか確かめ、Site CI で動かす）と `site/scripts/lp_images.py`（docs の見本とアプリのアイコンから絵を切り出して WebP にする）を足す。道具は Python の `fonttools`（MIT）・`brotli`（MIT）・`beautifulsoup4`／`soupsieve`（MIT）・`Pillow`（MIT-CMU）・`numpy`（BSD-3-Clause）で、どれも広く使われ保守されている。版は `site/scripts/requirements.txt` で固定し、アプリとサーバーの動きには入らない。素材は今のスクリプトで作り直したもの（見た目は前と同じ。書体は、試作のあとに規約などで足した字が入った）
- 理由: 試作（#282）のときの手順が一時フォルダにしか無く、字を足すとその字だけ別の書体で出ていたため。CI で気づけるようにする
- 関連: #289, #282
