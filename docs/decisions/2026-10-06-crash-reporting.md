# Firebase Crashlytics を入れ、設定に「不具合を知らせる」を置く

- 日付: 2026-10-06
- 決定: face-seal と同じ作りで Firebase Crashlytics を入れる。落ちたときと、保存・バックアップなど大事な処理の失敗を送る（店の検索の失敗など、電波しだいで起きるものは送らない）。例外の文には店名・メモ・ファイルの場所が混ざりうるので、型の名前しか出ない種類以外は種類の名前だけにして送る。設定の「不具合を知らせる」は、匿名の識別番号（端末の中で乱数で作る。Crashlytics の利用者の識別子と同じ）・アプリのバージョン・OS・機種・直近のエラーの種類を本文に入れてメールアプリを開くだけで、アプリからは送らない。`firebase_crashlytics`（BSD-3-Clause、Firebase 公式）、`package_info_plus`・`device_info_plus`（BSD-3-Clause、Flutter Community）を追加。プライバシーポリシーにも書いた
- 理由: 落ちても利用者から聞かない限りわからないため、一般公開の前に把握できるようにする。通信先が増えるので aiandrox が判断し、Crashlytics とメールの両方を入れることにした（face-seal と同じにする）
- 関連: #288, #29
