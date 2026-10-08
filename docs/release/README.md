# ストアへのリリース

`scripts/release.sh` 1本で「ビルド番号を上げる → ストア用にビルドする → アップロードする → タグ・PR・GitHub Release を作る」までを行う（face-seal の `scripts/release.sh` を麺印帳向けに直したもの）。

```sh
scripts/release.sh ios                  # ビルド番号+1 → ipa → App Store Connect（TestFlight）
scripts/release.sh android              # ビルド番号+1 → aab → Google Play（PLAY_TRACK、既定は内部テスト）
scripts/release.sh all                  # iOS と Android を続けて（同じ番号）
scripts/release.sh ios -v 1.1.0         # 表示用バージョンも上げる
scripts/release.sh android --no-bump    # 番号はそのまま、もう一方の OS にだけ上げる
scripts/release.sh all --no-upload      # ビルドだけ（タグ・ブランチは作らない）
scripts/release.sh all --notes notes.md # リリースノートを渡す
```

## ビルド番号とタグ

- ビルド番号は `max(pubspec の N, リモートの v*+N タグの最大) + 1`。リモートのタグを「使った番号」の記録として扱い、iOS と Android で同じ番号を別の中身で使わないようにする
- `origin/main` の最新と同じコミットで、追跡ファイルに変更が無いときだけ動く
- 番号を上げるときは `release/<X.Y.Z>+<N>` ブランチで `pubspec.yaml` を書き換えてコミットし、アップロードに成功したら `v<X.Y.Z>+<N>` タグを打ってブランチとタグを push し、PR「ビルド番号を N にする」を作る。PR は普通にマージする
- 失敗したとき・`--no-upload` のときはタグもブランチも残さない
- 判定は `scripts/release-lib.sh` にあり、`scripts/test-release-lib.sh` で確かめる（CI でも走る）

## リリースノート

アプリは日本語だけなので、日本語の1節だけ書く。`--notes` には `## ja` の節を持つ Markdown を渡す。

```md
## ja

・店名の検索で、近い店から並ぶようにしました
・記録画面の動きを軽くしました
```

省略するとコミット件名から下書きを作る。どちらの場合もタグと同じ名前の GitHub Release に「Google Play に貼る文」と「App Store Connect に貼る文」を載せるので、そこから貼る（ストアへの入力は手で行う）。Google Play は500文字、App Store は4000文字まで。TestFlight だけのときは「テスト内容」に貼る。

## 事前準備

鍵と設定は、リポジトリの外の `~/.config/ramen-in-cho/` か、git の対象外の `env/` に置く（`env/` が先）。公開リポジトリに誤ってコミットしないよう、また worktree を作るたびに置き直さなくて済むよう、外に置くのがおすすめ。

```sh
# ~/.config/ramen-in-cho/release.env
ASC_KEY_ID=XXXXXXXXXX
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
PLAY_SERVICE_ACCOUNT_JSON=$HOME/.config/ramen-in-cho/play-service-account.json
PLAY_TRACK=internal
```

- **iOS**: App Store Connect → ユーザとアクセス → 統合 → App Store Connect API → チームキーで、役割「App Manager」の鍵を麺印帳のアップロード用に作る。`.p8` は1回しかダウンロードできない。`~/.appstoreconnect/private_keys/AuthKey_<キーID>.p8` に置く。署名は Xcode の自動管理（Team `CJ99DCYQKL`）なので、この Mac の Xcode にログインしていること
- **Android**: アップロード鍵 `~/.config/ramen-in-cho/upload-keystore.jks` とパスワードの `key.properties` を `android/key.properties` に写す。**鍵を失うと Play のアプリを更新できない。** パスワードの管理アプリにも控える。アップロードには Play Console のサービスアカウントの JSON 鍵と `fastlane`（`gem install fastlane`）が要る
- Play Console の**最初の1回**は API で上げられないので、画面から aab を上げる。そのあとで `--no-bump` 無しの通常の手順に戻る

## ストアのプライバシーの回答

送る内容（`site/public/privacy.html`）を変えたら、App Store Connect の「App のプライバシー」、Play Console の「データ セーフティ」、`ios/Runner/PrivacyInfo.xcprivacy` も直す（ストアの画面は aiandrox が入力する）。掲載文・年齢区分・審査メモは [store-listing.md](store-listing.md)。

### 申告の根拠（アプリが外に送るもの）

| 送り先 | 送るもの | コード |
|---|---|---|
| 麺印帳のサーバー（Cloudflare）→ Overpass・OpenPOI・Yahoo! | 近くの店: 検索の中心（現在地・写真の撮影場所・地図の中心）と半径。店名: 打った言葉と、近い順の基準の位置（わかるときだけ） | `lib/features/shop_search/ramen_in_cho_api.dart` |
| 端末から直接 Overpass・OpenPOI（サーバーに届かないとき） | 上と同じ | `overpass_client.dart`・`openpoi_client.dart` |
| 麺印帳のサーバー → Yahoo! ジオコーダ | ほかのアプリから共有された店の住所 | `addressGeocoderProvider` |
| OpenPOI（端末から直接） | 店のページを開いたとき、市区町村がまだわからない店の座標（利用者の現在地ではない） | `lib/features/journal/shop_area.dart` |
| OpenStreetMap のタイル | 表示している地図の範囲 | `lib/features/map/washi_map.dart` |
| Firebase App Check | App Attest / Play Integrity のトークン | `ramen_in_cho_api.dart` |
| Firebase Crashlytics | スタックトレース・エラーの種類・端末の機種・OS・アプリのバージョン・識別番号（`setUserIdentifier`） | `lib/features/error_reporting/` |
| Firebase Analytics | 機能の種類・幅にまとめた数・1/0・開いたタブ（`setUserId` はしない）。広告 ID・IDFV・SSAID は集めない | `lib/features/analytics/` |
| 不具合のメール | 利用者が自分で送るときだけ。識別番号・アプリのバージョン・OS・機種・直近のエラーの種類 | `lib/features/support/` |

**外に出さないもの**: 記録・写真（写真の撮影日時と撮影場所そのもの）・メモ・店の覚え書き・願・拠点・現在地の履歴。現在地は検索の中心として送るだけで、サーバーは区画（約300m）・言葉と約10kmの範囲ごとに結果をためるが、誰が探したかは残さない。

「ユーザーにリンク」は、Crashlytics の情報だけ「する」にしている。識別番号が不具合のメール（メールアドレス）と照らし合わせられるため。Analytics は `setUserId` をしないので「しない」。

### App Store Connect「App のプライバシー」

最初の設問「このAppからデータを収集しますか？」→ **はい**。下の表に無い種類は「収集しない」。

| カテゴリ | データの種類 | 用途 | ユーザーにリンク | トラッキング |
|---|---|---|---|---|
| 位置情報 | 正確な位置情報 | アプリの機能 | しない | しない |
| 位置情報 | おおよその位置情報 | アプリの機能、アナリティクス | しない | しない |
| 検索履歴 | 検索履歴 | アプリの機能 | しない | しない |
| 識別子 | ユーザ ID | アプリの機能 | **する** | しない |
| 識別子 | デバイス ID | アプリの機能、アナリティクス | しない | しない |
| 使用状況データ | 製品の操作 | アナリティクス | しない | しない |
| 使用状況データ | その他の使用状況データ | アナリティクス | しない | しない |
| 診断 | クラッシュデータ | アプリの機能 | **する** | しない |
| 診断 | その他の診断データ | アプリの機能 | **する** | しない |

- 正確な位置情報: 店の検索の中心（現在地・写真の撮影場所）。おおよその位置情報: Analytics が IP から推し量る地域
- 検索履歴: 店名の検索の言葉
- ユーザ ID: Crashlytics と不具合のメールに載せる識別番号。デバイス ID: Firebase のインストールごとの識別子・App Check
- その他の使用状況データ: 開いたタブ・起動など Analytics が自動で記録するもの
- **「ユーザーコンテンツ（写真・その他）」「連絡先情報」「連絡先」「閲覧履歴」「購入」「健康とフィットネス」「財務情報」「機密情報」は収集しない。** 写真・メモは端末の外に出ない
- 連絡先情報（メールアドレス）: 不具合のメールは利用者がメールアプリから任意で送るもので、アプリが集めるものではないので申告しない（Apple の「任意の申告」の条件に当たる）
- トラッキング: すべて「しない」。ATT の許可は求めない
- 住所（共有された店の住所）は店の位置にするためだけに送る店の情報で、利用者の住所ではないので申告しない

### Play Console「データ セーフティ」

共通の設問:

- 必須のユーザーデータを収集・共有するか → **はい**
- 収集したデータはすべて転送時に暗号化されるか → **はい**（すべて HTTPS）
- データの削除をリクエストする方法を提供しているか → **いいえ**。アカウントが無く、運営者が利用者ごとに持つデータが無いため（アプリを消せば端末のデータは消える。統計・エラー情報は保存期間で消える）。「はい」を選ぶ場合は窓口を ramen-in-cho@aiandrox.com にする
- アカウントの作成 → **アカウントの作成なし**

| カテゴリ | データの種類 | 収集 | 共有 | 一時的な処理 | 必須／任意 | 目的 |
|---|---|---|---|---|---|---|
| 位置情報 | おおよその位置情報 | する | する | はい | 任意 | アプリの機能 |
| 位置情報 | 正確な位置情報 | する | する | はい | 任意 | アプリの機能 |
| アプリのアクティビティ | アプリの操作 | する | しない | いいえ | 必須 | 分析 |
| アプリのアクティビティ | アプリ内検索履歴 | する | する | はい | 任意 | アプリの機能 |
| アプリの情報とパフォーマンス | クラッシュログ | する | しない | いいえ | 必須 | アプリの機能、分析 |
| アプリの情報とパフォーマンス | 診断 | する | しない | いいえ | 必須 | アプリの機能、分析 |
| デバイスまたはその他の ID | デバイスまたはその他の ID | する | しない | いいえ | 必須 | アプリの機能、分析、不正行為の防止・セキュリティ・コンプライアンス |

- 位置情報・検索履歴の「共有する」: サーバーが Overpass・OpenPOI・Yahoo! に問い合わせる（サーバーに届かないときは端末から Overpass・OpenPOI に直接）。face-seal でも中継先への送信は「共有」にしているのにそろえた。位置情報の許可を断っても使えるので「任意」
- Firebase（Google）は運営者の代わりに処理するサービス提供者なので「共有」には当たらない
- 「個人情報」「金融情報」「健康とフィットネス」「メッセージ」「写真と動画」「音声」「ファイルとドキュメント」「カレンダー」「連絡先」「ウェブ閲覧履歴」は収集しない
- **広告 ID**（「アプリのコンテンツ」→「広告 ID」）: **使用しない**。Android は `AD_ID` の権限を外し、Analytics の広告 ID・SSAID の収集を止めてある（`AndroidManifest.xml`）
- **広告**（「アプリのコンテンツ」→「広告」）: **広告を含まない**
