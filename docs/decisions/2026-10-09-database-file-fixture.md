# drift・sqlite3 を上げる前に、古い版で作ったデータベースのファイルが読めるかをテストで確かめる

- 日付: 2026-10-09
- 決定: 上げる前の版（drift 2.35.0・sqlite3 3.5.2）で作ったスキーマのバージョン13のファイル `test/fixtures/database/ramen_in_cho_v13.sqlite` を保存しておく。`test/features/database/database_file_test.dart` で今の版で開き、すべての表の値・表の定義・バックアップの中身が、同じ中身を今の版で入れ直したものと同じかを比べる。drift・sqlite3 を上げるときは、上げる前のコミットで `UPDATE_DB_FIXTURE=true flutter test test/features/database/database_file_test.dart` を実行してファイルを作り直し、上げたあとにこのテストが通ることを確かめる。スキーマのバージョンが上がっても、このファイルは消さずに残す
- 理由: 保存済みの記録が読めなくなることを、パッケージを上げる前にテストで見つけるため。マイグレーションのテストは古いスキーマを今の版で作るので、古いパッケージで書いたファイルそのものは確かめられない
- 関連: #375
