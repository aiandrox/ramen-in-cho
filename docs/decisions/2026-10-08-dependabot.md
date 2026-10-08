# 依存の更新は Dependabot が週1回まとめて PR を出す

- 日付: 2026-10-08
- 決定: `.github/dependabot.yml` で、pub（ルート）・npm（`site/`）・GitHub Actions の更新を毎週月曜に確かめ、種類ごとにマイナー・パッチの更新を1つの PR にまとめる（GitHub Actions はメジャーも含めて1つ）。pub と npm のメジャーの更新は1件ずつ別の PR になる。自動ではマージしない。CI（Flutter CI・iOS のビルド確認・Site CI）が通ったものを見て入れる。drift・image_picker・geolocator・firebase 系・flutter_map など、記録や写真・権限・通信に関わるものは、マイナーでも中身を確かめてから入れる
- 理由: `flutter pub get` で新しい版のあるパッケージが25件たまり、`site/` の npm と GitHub Actions も手で上げるしかなかったため（aiandrox の起票）。保存済みの記録が読めなくなるおそれのある更新を気づかずに入れないよう、マージは人が判断する
- 関連: #287
