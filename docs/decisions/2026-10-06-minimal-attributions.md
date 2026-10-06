# 画面の出典は、必要なところに小さな1行だけ出す

- 日付: 2026-10-06
- 決定: 地図の左下と店の検索結果の下に、小さな1行（`lib/features/credits/source_credit.dart`）で「© OpenStreetMap contributors ・ Web Services by Yahoo! JAPAN ・ 出典」を出す。Yahoo! は Yahoo! の結果を出しているときだけ（場所を選ぶ地図など、検索しない地図は OpenStreetMap だけ）。Yahoo! の部分は API の案内ページ（https://developer.yahoo.co.jp/sitemap/）へ、「出典」は「出典・ライセンス」へつなぐ。OpenPOI の URL や国土数値情報などは「出典・ライセンス」にだけ全文で出す
- 理由: 画面の出典の文が多くて邪魔だったため（利用者の要望）。OpenStreetMap は地図の上に出典が要り、Yahoo! は結果を使う画面の下部に、案内ページへつないだクレジットが要る（極端に小さくするのは不可なので 11pt）。OpenPOI（Overture・食品営業許可データ）と国土数値情報（CC BY 4.0）は、たどれる場所に出典があればよいので「出典・ライセンス」に任せる
