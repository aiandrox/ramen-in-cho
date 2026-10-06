#!/usr/bin/env bash
# 都道府県の境界（assets/prefectures.json）を作り直す。開発時だけ使う（アプリからは通信しない）。
#
# 元のデータ: 国土数値情報（行政区域データ）N03（国土交通省、CC BY 4.0）
#   https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2024.html
# 使い方: tool/prefectures/build.sh <作業用のフォルダ>
#   作業用のフォルダに N03-20240101_GML.zip を落とし、都道府県ごとの境界を簡略化して書き出す。
set -euo pipefail

work="${1:?作業用のフォルダを指定してください}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
zip="$work/N03-20240101_GML.zip"

mkdir -p "$work"
if [[ ! -f "$zip" ]]; then
  curl -fL -o "$zip" https://nlftp.mlit.go.jp/ksj/gml/data/N03/N03-2024/N03-20240101_GML.zip
fi
unzip -o -q "$zip" 'N03-20240101_prefecture.shp' 'N03-20240101_prefecture.shx' \
  'N03-20240101_prefecture.dbf' 'N03-20240101_prefecture.prj' \
  'N03-20240101_prefecture.cpg' -d "$work"

# 0.5km² より小さい島は除き（店があっても、いちばん近い県で補う）、点の数を 1% まで減らす。
npx -y mapshaper@0.6 \
  -i "$work/N03-20240101_prefecture.shp" encoding=utf8 \
  -dissolve N03_001 \
  -filter-islands min-area=0.5km2 remove-empty \
  -simplify 1% keep-shapes \
  -o "$work/prefectures.geojson" format=geojson precision=0.001

node "$root/tool/prefectures/convert.mjs" "$work/prefectures.geojson" \
  "$root/assets/prefectures.json"
