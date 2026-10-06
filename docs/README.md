# 管理用の資料

アプリの中身を一覧にしたもの。どれもテストでコードの定義から作り、定義と合わなければテストが失敗する。

- [秘伝の一覧](hiden/README.md) — 秘伝の印と、会得の条件・期間
- [道中記の言い回し](journal/README.md) — 道中記に出てくる文と、出てくる条件
- [地方の印](seals/README.md) — 都道府県の地方ごとの印の外枠と、格（良・秀・妙・極）の飾りの見本帳
- [ボタンの見本帳](buttons/README.md) — 役割ごとのボタンの見た目（画像は見た目を変えたときに作り直す）

決定事項:

- [決定事項](decisions/README.md) — 「なぜ今こうなっているのか」を1件1ファイルで残す。今の決まりは [CLAUDE.md](../CLAUDE.md)

運用の手順:

- [ストアへのリリース](release/README.md) — `scripts/release.sh` の使い方、ビルド番号とタグ、リリースノート、鍵の置き場所

同梱しているデータ:

- 都道府県の境界（`assets/prefectures.json`）— 出典: 国土数値情報（行政区域データ N03-2024）（国土交通省、CC BY 4.0、https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2024.html）を加工して作成。島の小さなものを除き、点を1%に減らし、座標を1/1000度に丸めた。作り直すときは `tool/prefectures/build.sh <作業用のフォルダ>`（開発時だけ通信する。アプリからは通信しない）
