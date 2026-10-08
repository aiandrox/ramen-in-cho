# ストアのプライバシーの申告と iOS のプライバシーマニフェストを、今の送信先にそろえる

- 日付: 2026-10-08
- 決定: App Store の「App のプライバシー」と Play の「データ セーフティ」の回答を `docs/release/README.md` に、掲載文・年齢区分・審査メモを `docs/release/store-listing.md` に置く。`ios/Runner/PrivacyInfo.xcprivacy` を足し、追跡なし・アプリ自身が集めるもの（店の検索の位置と言葉・統計・Crashlytics と識別番号）と、マニフェストを持たない `sqlite3.framework` のファイルの日時の読み取り（C617.1）を書く。Crashlytics の情報（識別番号・インストールの識別子・クラッシュ・診断）を「ユーザーにリンクする」にする（識別番号が不具合のメールと照らし合わせられるため）。店の検索の位置と言葉は、サーバーが Overpass・OpenPOI・Yahoo! に問い合わせるので Play では「共有する」にする（face-seal にそろえた）
- 理由: Crashlytics・Analytics・App Check を入れて「データの収集なし」ではなくなったため（#300・#307）。drift の SQLite が、Apple が理由の申告を求める API（stat など）を使っていて、どのマニフェストにも書かれていないため
- 関連: #358・#308
