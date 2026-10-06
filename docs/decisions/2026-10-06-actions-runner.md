# GitHub Actions は Node 24 対応の版を使い、Linux のランナーは ubuntu-24.04 に固定する

- 日付: 2026-10-06
- 決定: `actions/checkout@v7`・`actions/setup-node@v7`・`actions/cache@v6` を使う。Linux のジョブは `ubuntu-latest` ではなく `ubuntu-24.04` で動かす。macOS（iOS のビルド確認、手動実行のみ）は `macos-latest` のまま
- 理由: Node 20 向けの版が非推奨になったため。`ubuntu-latest` が 2026-10-19 から Ubuntu 26 に変わり、何も変えていないのに CI やデプロイが急に壊れるのを避けるため。Ubuntu 26 へは別の PR で上げて確かめる。macOS は手動でしか走らないので、新しい Xcode で壊れてもその場で気づける
- 関連: #285、#294
