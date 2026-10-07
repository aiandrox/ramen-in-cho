# iOS のビルド確認を、iOS に関わる変更の PR で自動で走らせる

- 日付: 2026-10-07
- 決定: Native Build Check の iOS（`flutter build ios --debug --no-codesign`）を、`ios/**`・`pubspec.yaml`・`pubspec.lock`（とこのワークフロー・Flutter の準備）が変わる PR で走らせる。手動実行もそのまま。Android は今までどおり main へのマージ時と手動実行時
- 理由: aiandrox の提案（#291）。共有の拡張機能や App Attest など iOS 側の変更が増え、iOS だけで壊れるものに実機へ入れるまで気づけなかったため。公開リポジトリでは macOS を含む標準ランナーは無料で（GitHub のドキュメント「The use of standard GitHub-hosted runners is free: In public repositories」）、1回およそ5〜8分なので、対象の PR に絞れば待ち時間も問題にならない
- 関連: #291
