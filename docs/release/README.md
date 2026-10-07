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

送る内容（`site/public/privacy.html`）を変えたら、App Store Connect の「App のプライバシー」と Play Console の「データ セーフティ」の回答も直す（ストアの画面で aiandrox が行う）。今の回答の目安:

- **使用状況データ（製品の操作）**: Firebase Analytics。用途は「アナリティクス」。ユーザーに紐づけない・トラッキングに使わない
- **診断（クラッシュデータ・その他の診断データ）**: Firebase Crashlytics。用途は「アプリの機能」。ユーザーに紐づけない
- **位置情報（おおよそ・正確）**: 店の検索のために中心の座標を送るが、保存しない。ユーザーに紐づけない
- **ID（デバイス ID）**: Firebase のインストールごとの識別子（Android の「データ セーフティ」では「デバイスなどの ID」）。広告 ID は集めない（Android は `AD_ID` の権限を外してあるので、Play Console の「広告 ID」の申告は「使用しない」。iOS の IDFV も集めない）
- 送るデータは暗号化して送る（HTTPS）。アプリに保存したデータの削除はアプリの削除で行える
