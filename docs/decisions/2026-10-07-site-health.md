# サーバーの API が止まっていないかを、GitHub Actions で毎日確かめる

- 日付: 2026-10-07
- 決定: `.github/workflows/site-health.yml` が毎日 9:17（日本時間）に、サーバーの API（`/api/v1/curated-shops`・`/api/v1/shops/nearby`・`/api/v1/shops/search`）へ App Check のトークンなしで問い合わせる（`.github/scripts/site-health.sh`）。`site/wrangler.toml` の `APP_CHECK_ENFORCE` が `"true"` なら 401 の JSON、そうでなければ 200 の JSON（店の一覧は1件以上）を期待する。3回試してもだめなら issue「サーバーの見張り: API が思ったとおりに答えていません」を立て、開いたままならそこに書き足す（同じ失敗で issue を増やさない）。手動でも走らせられる
- 理由: aiandrox の提案（#292）。止まってもアプリは端末から直接探すので気づきにくいため。問い合わせ先はサーバーだけにし、検索サービス（Overpass・OpenPOI・Yahoo!）は Actions から直接叩かない
- 見えないもの: App Check で断っている間は、入口（`_middleware.ts`）で 401 を返すので、D1 と検索サービスの不調はわからない。検索サービスの不調まで見るなら、サーバーに状態を返す口を足す必要がある
- 関連: #292
