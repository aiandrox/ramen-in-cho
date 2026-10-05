# ramen-in-cho（着丼クエストの紹介ページと API）

Cloudflare Pages の1つのプロジェクトに、紹介ページ（`public/`）と API（`functions/`、Pages Functions）を置く。
公開先は https://ramen-in-cho.aiandrox.com 。設計と進み具合は issue #172。記録・写真・位置の履歴は受け取らない。

## API

| 道 | 中身 |
|---|---|
| `GET /api/v1/curated-shops` | アプリに持たせる店の一覧（閉店も含む）。店ごとに `hoursConditions`（店の条件。初めて記録するときの下書き）。`ETag` 付きで、`If-None-Match` が同じなら 304 |
| `GET /api/v1/shops/nearby?lat=&lon=&radius=` | 近くの店（半径 1000m まで）。手で持つ店・Overpass・OpenPOI・Yahoo! をまとめて返す |
| `GET /api/v1/shops/search?q=&lat=&lon=` | 店名で全国から探す。空白があれば詰めた言葉でも探してまとめる |

検索結果は Cache API に **1週間** ためる（どれかの検索が失敗したときは1日）。近くの店は緯度経度 0.003 度（約300m）のマスごと、
店名は言葉と 0.5 度（約50km）の場所ごと。誰が探したかは残さない。手で持つ店はため置かず、毎回 D1 から読む。

## 店のデータを直す

1. `../data/curated_shops.json` を直して PR を出す（閉店は消さずに `"status": "closed"`）
   - 店の条件（`hoursConditions`）は、店の公式 X・告知などで確かめて入れ、`conditionsSource` に調べた URL と日付を書く。営業時間そのものは書かない。確かめられなければ `"conditionsVerified": false` にして条件を空にする
2. マージすると GitHub Actions（Site Deploy）が D1 を正本どおりに入れ替えてデプロイする

アプリに同梱している一覧（`lib/features/shop_search/builtin_shops.dart`）も同じ中身にする（テストで確かめる）。

## はじめの設定（一度だけ）

1. Cloudflare にログイン: `npx wrangler login`
2. D1 を作る: `npx wrangler d1 create ramen-in-cho` → 出てきた `database_id` を `wrangler.toml` に書く
3. Pages のプロジェクトを作る: `npx wrangler pages project create ramen-in-cho --production-branch main`
4. 独自ドメイン: ダッシュボード → Workers & Pages → ramen-in-cho → Custom domains に `ramen-in-cho.aiandrox.com` を足し、aiandrox.com の DNS に案内どおりの CNAME を足す
5. Yahoo! の Client ID をサーバーに入れる: `npx wrangler pages secret put YAHOO_APP_ID --project-name ramen-in-cho`
6. GitHub の Settings → Secrets に `CLOUDFLARE_API_TOKEN`（Pages と D1 を編集できるトークン）と `CLOUDFLARE_ACCOUNT_ID` を入れる
7. Actions の Site Deploy を手で動かす（workflow_dispatch）

D1 のつなぎ（`DB`）は `wrangler.toml` に書いてあるので、デプロイのときに Pages に反映される。

## App Check

`/api/v1/...` は `functions/api/_middleware.ts` で Firebase App Check（プロジェクト `ramen-in-cho`）のトークンを確かめる。`wrangler.toml` の `APP_CHECK_ENFORCE` が `"false"` のうちは、トークンが無い・正しくない問い合わせも通し、ログ（`app check: missing` / `invalid`）に残すだけ。アプリからの問い合わせがほぼ `ok` になったのを確かめてから `"true"` にする。

- iOS: Firebase コンソール → App Check で App Attest を登録（チームIDが要る）。`ios/Runner/Runner.entitlements` に `com.apple.developer.devicecheck.appattest-environment` = `production` を入れ、Release・Profile にだけ付ける
- Android: Firebase コンソール → App Check で Play Integrity を登録（署名の SHA-256 が要る）。Google Play から入れたアプリでないと通らないので、`adb install` で入れたアプリはデバッグ用トークンを使う
- トークンの有効期限（Token time to live）は iOS・Android とも1日。店の中は電波が弱く、取り直しで待たせないため（返すのは店の公開情報だけなので、長めでも困らない）
- デバッグビルド: `--dart-define=APP_CHECK_DEBUG_TOKEN=<UUID>` で渡したトークンを、Firebase コンソール → App Check → アプリ → デバッグトークンの管理 に登録する

## 手元で

```bash
npm ci
npm test          # テスト
npm run typecheck # 型の確認
npm run seed      # 正本から D1 に入れる SQL（seed.sql）を作る
npx wrangler pages dev  # 手元で動かす（--local の D1 を使う）
```
