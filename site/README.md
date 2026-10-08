# ramen-in-cho（麺印帳の紹介ページと API）

Cloudflare Pages の1つのプロジェクトに、紹介ページ（`public/`）と API（`functions/`、Pages Functions）を置く。
公開先は https://ramen-in-cho.aiandrox.com 。設計と進み具合は issue #172。記録・写真・位置の履歴は受け取らない。

## API

| 道 | 中身 |
|---|---|
| `GET /api/v1/curated-shops` | アプリに持たせる店の一覧（閉店も含む）。`ETag` 付きで、`If-None-Match` が同じなら 304 |
| `GET /api/v1/shops/nearby?lat=&lon=&radius=` | 近くの店（半径 1000m まで）。手で持つ店・Overpass・OpenPOI・Yahoo! をまとめて返す |
| `GET /api/v1/shops/search?q=&lat=&lon=` | 店名で全国から探す。空白があれば詰めた言葉でも探してまとめる |
| `GET /api/v1/geocode?q=` | 住所を位置にする（Yahoo! ジオコーダ）。`{ result: { latitude, longitude, address, level, attribution } }`、見つからなければ `{ result: null }`。ためない（毎回 Yahoo! に問い合わせる） |

Overpass・OpenPOI の検索結果は Cache API に **1週間** ためる（どれかの検索が失敗したときは1日）。近くの店は緯度経度 0.003 度（約300m）のマスごと、
店名は言葉と 0.1 度（約10km）の場所ごと。誰が探したかは残さない。手で持つ店はため置かず、毎回 D1 から読む。

Yahoo!（ローカルサーチ・ジオコーダ）の結果は、YOLP の利用条件（保存・キャッシュの禁止）のため **ためない**。問い合わせのたびに Yahoo! に聞き、
ためた Overpass・OpenPOI の結果と混ぜる（同じ店は OSM → Yahoo! → OpenPOI の順に残す）。Yahoo! に問い合わせた回数は D1 の `yahoo_daily_usage`
（日本時間の日付と回数だけ）で数え、4万5千回（上限5万回の手前）を越えた日は Yahoo! を使わずに探す（#373）。

## 店のデータを直す

1. `../data/curated_shops.json` を直して PR を出す（閉店は消さずに `"status": "closed"`）
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

`/api/v1/...` は `functions/api/_middleware.ts` で Firebase App Check（プロジェクト `ramen-in-cho`）のトークンを確かめる。`wrangler.toml` の `APP_CHECK_ENFORCE` が `"false"` のうちは、トークンが無い・正しくない問い合わせも通し、ログ（`app check: missing` / `invalid`）に残すだけ。2026-10-06 に iPhone・Android（Mac から直接入れたもの）とも `ok` になったのを確かめ、`"true"`（断る）にした。断られてもアプリは端末から直接探す。

- iOS: Firebase コンソール → App Check で App Attest を登録（チームIDが要る）。`ios/Runner/Runner.entitlements` に `com.apple.developer.devicecheck.appattest-environment` = `production` を入れ、Release・Profile にだけ付ける
- Android: Firebase コンソール → App Check で Play Integrity を登録。Firebase の Android アプリに、Play のアプリ署名鍵・アップロード鍵・この Mac の開発用の鍵の SHA-256 を登録してある。Play 以外から入れたアプリ（`adb install`）も通すため、Play Integrity の設定で `appIntegrity.allowUnrecognizedVersion` を true にしてある（登録した鍵で署名したものだけ通る）
- トークンの有効期限（Token time to live）は iOS・Android とも1日。店の中は電波が弱く、取り直しで待たせないため（返すのは店の公開情報だけなので、長めでも困らない）
- デバッグビルド: `--dart-define=APP_CHECK_DEBUG_TOKEN=<UUID>` で渡したトークンを、Firebase コンソール → App Check → アプリ → デバッグトークンの管理 に登録する

## 回数制限

App Check のあと、同じ `_middleware.ts` で1台あたりの回数を数える（`src/rate-limit.ts`）。**1分に60回・1日（UTC の0時区切り）に600回**まで。越えると 429 と `Retry-After`（秒）を返し、アプリは端末から直接探す。

- 数える単位は「App Check のアプリ ID（iOS・Android の別）＋接続元の IP（IPv6 は /64）」。IP が分からなければ数えない
- 回数は Cache API（`caches.default`）に区切りごとにためる。データセンターごとのおおよその数で、同時の問い合わせは数え漏れうる
- 鍵は SHA-256 にしてためるので、IP そのものは残さない。ログにも IP は出さない（`rate limited` とだけ出す）

## 使用量を見張る

無料プランでは、Pages Functions（`/api/...`）の呼び出しは Workers と合わせて **1日10万回まで**（UTC の0時、日本時間の9時に戻る）。紹介ページ（`public/`）は数えない。
無料プランでは使用量の通知（Notifications の Billable Usage）を作れない（Pro 以上か従量課金のアカウントだけ）ので、ダッシュボードで見る（2026-10-08 に確かめた）。

- **1日の回数を見る**: ダッシュボード → Workers & Pages → ramen-in-cho → **Functions Metrics**。リクエスト数（成功・エラー）が日ごとに出る。月に1回と、ストアに出した直後は毎日見る。**1日5万回**（無料の半分。Yahoo! の1日の上限とも同じ）を越える日が出たら #29 の回避策の表を見て手を打つ
- **上限を越えた日の動き**: ダッシュボード → Workers & Pages → ramen-in-cho → Settings → Runtime → **Fail open / closed** を **Fail open** にしておく。越えた日は API が動かず（`/api/...` が 404 になる）、アプリは端末から直接探す。紹介ページはそのまま出る
- サーバーが止まったことは、毎日の Site Health（`.github/workflows/`）が知らせる
- 出典: [Pages Functions の料金](https://developers.cloudflare.com/pages/functions/pricing/)・[Workers の上限](https://developers.cloudflare.com/workers/platform/limits/)・[Fail open / closed](https://developers.cloudflare.com/pages/functions/routing/)・[Functions Metrics](https://developers.cloudflare.com/pages/functions/metrics/)・[使用量の通知の対象](https://developers.cloudflare.com/billing/understand/usage-based-billing/)

## 手元で

```bash
npm ci
npm test          # テスト
npm run typecheck # 型の確認
npm run seed      # 正本から D1 に入れる SQL（seed.sql）を作る

# 手元で動かす（D1 は手元の .wrangler/ に作る。本番の D1 には触らない）
npx wrangler d1 migrations apply ramen-in-cho --local
npx wrangler d1 execute ramen-in-cho --local --file seed.sql
npx wrangler pages dev                                     # http://localhost:8788
npx wrangler pages dev --binding APP_CHECK_ENFORCE=false   # App Check のトークン無しで API を試す

# 本番のログを見る（Functions の console.log）
npx wrangler pages deployment tail --project-name ramen-in-cho --format pretty
```

wrangler は v4 で、Node 22 以上が要る。`npx wrangler` で `node_modules` の版が使われる（グローバルに入れた古い版は使わない）。

## 紹介ページの書体と絵

書体（`public/fonts/*.woff2`）はページで使う字だけに間引いてある。**ページに字を足したら作り直す**（作り直さないと、その字だけ別の書体で出る。Site CI の `lp_fonts.py check` が失敗して知らせる。lp.js が後から付ける class で筆の書体になる要素の字は数えられないので、その字は HTML のどこかで筆の書体の要素に入れておく）。
絵（`public/img/`）は docs の見本とアプリのアイコンから切り出している。印や秘伝・タブの絵を描き直したら、見本を作り直してから切り出す（Site CI の `lp_images.py check` が、元と合わなくなったら知らせる）。

```bash
python3 -m venv /tmp/lp-venv && /tmp/lp-venv/bin/pip install -r scripts/requirements.txt   # 一度だけ
/tmp/lp-venv/bin/python scripts/lp_fonts.py         # 書体を作り直す
/tmp/lp-venv/bin/python scripts/lp_fonts.py check   # ページの字が、すべて書体にあるか
/tmp/lp-venv/bin/python scripts/lp_images.py        # 絵を切り出す
/tmp/lp-venv/bin/python scripts/lp_images.py check  # 絵が、元の見本から作ったものと同じか
```

- 書体の元はアプリと同じ `../assets/fonts/`。本文（Shippori Mincho）はページのすべての字、筆（Yuji Syuku）は `lp.css` で `var(--brush)` を使う要素の字だけを入れる（どちらにも ASCII は入れる）
- 絵の元: 印と「まだ」の印は `docs/seals/catalog.png`、秘伝は `docs/hiden/*.png`（「まだ見ぬ秘伝」はぼかして灰色にする）、判子・絵馬・系統の椀は `docs/buttons/catalog.png`、タブは `docs/buttons/tab_seals.png` の4倍の段、丼の朱印と `og-icon.png`・`apple-touch-icon.png` はアプリのアイコン。どこを切り出すかは `scripts/lp_images.py` に書いてある
- 見本の並びや大きさが変わったら、`lp_images.py` の切り出す位置も直す
