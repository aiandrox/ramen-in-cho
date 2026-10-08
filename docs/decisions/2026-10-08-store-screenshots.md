# ストアのスクリーンショットは架空のデータで描き、iPad の分は App Store の iPad 欄にだけ使う

- 日付: 2026-10-08
- 決定: App Store（iPhone 6.9インチ・6.5インチ・iPad 13インチ）と Google Play（スマートフォン・フィーチャー グラフィック）の画像を、使い方の絵と同じ仕組みで架空のデータから描き（`test/tool/store_shots_test.dart`）、`docs/release/screenshots/` に JPEG で置く。iPad の画像は App Store の iPad 欄にだけ使い、ほかで見せるのは iPhone の画像。iPad 対応の設定（`TARGETED_DEVICE_FAMILY`）は変えない
- 理由: 実在の人・店・場所を写さず、画面を変えたらいつでも同じ形で作り直せるようにするため。iPad でも動くアプリは iPad の画像が要るが、iPad 向けの画面は作っていないため（iPad の扱いは利用者の判断）
- 関連: #358
