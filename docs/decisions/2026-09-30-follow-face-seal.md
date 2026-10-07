# 基盤と運用は face-seal に準じる（Firebase は App Check・Crashlytics・Analytics だけ）

- 日付: 2026-09-30
- 決定: 状態管理（flutter_riverpod）・フォルダ構成・文言ファイル・lint・CI・PR 運用は既存アプリ face-seal と同じにする。Firebase の Remote Config、広告、課金、`google_fonts` は持ち込まない。Firebase のうち App Check（2026-10-03-app-check）と Crashlytics（2026-10-06-crash-reporting）・Analytics（2026-10-07-analytics）だけは使う
- 理由: 既存アプリと同じ作りにして迷いを減らすため。外部への通信を店の検索と地図の画像に絞る方針と合わないものは入れない
