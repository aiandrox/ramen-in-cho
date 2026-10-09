# 秘伝の一覧

アプリに出てくる秘伝（1回きりのクエスト）の印と内容の一覧。管理用。

- 定義は `lib/features/quests/quests.dart`。期間限定の秘伝も、期間が過ぎたら消さずに残す
- 秘伝を足したり変えたりしたら `flutter test --dart-define=UPDATE_HIDEN_CATALOG=true test/tool/hiden_catalog_test.dart` でこの一覧と印の画像を作り直す
- 印の日付は見本（2026/10/3）

| 印 | 名前 | 会得の条件 | 字 | 形 | 期間 | ID |
|---|---|---|---|---|---|---|
| <img src="first_bowl.png" width="72"> | はじめての着丼 | 最初の一杯を記録する | 初 | 二重丸 | いつでも | `first_bowl` |
| <img src="queue_60.png" width="72"> | 六十分の試練 | 六十分以上並んで食べる | 忍 | 角 | いつでも | `queue_60` |
| <img src="queue_90.png" width="72"> | 九十分の死闘 | 九十分以上並んで食べる | 闘 | 八角形 | いつでも | `queue_90` |
| <img src="double_bowl.png" width="72"> | 一日二杯 | 同じ日に二杯食べる | 双 | 菱形 | いつでも | `double_bowl` |
| <img src="third_time.png" width="72"> | 三度目の正直 | 同じ店で二度撤退したあと、その店で食べる | 三 | 六角形 | いつでも | `third_time` |
| <img src="styles.png" width="72"> | 系統の探究 | 「その他」を除く八系統をすべて食べる | 全 | 8つの丸の輪 | いつでも | `styles` |
| <img src="famous_shop.png" width="72"> | 名店の暖簾 | 名店の印をつけた店で食べる | 名 | 花 | いつでも | `famous_shop` |
| <img src="home_base.png" width="72"> | 拠点を構える | 自分の拠点にする駅や街を決める | 城 | 城壁 | いつでも | `home_base` |
| <img src="long_wish.png" width="72"> | 百日越しの願 | 願を掛けてから百日以上たって、その店で食べる | 願 | 点の輪 | いつでも | `long_wish` |
| <img src="dawn.png" width="72"> | 朝ラーの心得 | 朝五時〜十時に食べる | 朝 | 光の筋 | いつでも | `dawn` |
| <img src="midnight.png" width="72"> | 丑三つの背徳 | 夜中の零時〜四時に食べる | 丑三 | 三日月 | いつでも | `midnight` |
| <img src="swift.png" width="72"> | 疾風の着丼 | 並んでから五分以内に着丼する | 速 | 三角 | いつでも | `swift` |
| <img src="style_ladder.png" width="72"> | 系統はしご | 同じ日に違う系統を二杯食べる | 二味 | 縦長の角丸 | いつでも | `style_ladder` |
| <img src="devoted.png" width="72"> | 一途 | 同じ店で十杯食べる | 一途 | 太い輪 | いつでも | `devoted` |
| <img src="pilgrimage.png" width="72"> | 月の巡礼 | ひと月に十軒の違う店で食べる | 巡 | 切れ目の輪 | いつでも | `pilgrimage` |
| <img src="limited_month.png" width="72"> | 限定狩りの月 | ひと月に限定を三杯食べる | 狩 | 五角形 | いつでも | `limited_month` |
| <img src="perfect.png" width="72"> | 満点の舌 | ★5を十杯つける | 満 | 星 | いつでも | `perfect` |
| <img src="jiro.png" width="72"> | 二郎の洗礼 | 二郎系を食べる | 二郎 | にんにく | いつでも | `jiro` |
| <img src="far_journey.png" width="72"> | 遥かなる遠征 | いちばん通っている店から100km以上離れた店で食べる | 旅 | 方位 | いつでも | `far_journey` |
| <img src="new_year_eve.png" width="72"> | 年越しの一杯 | 十二月三十一日に食べる | 年越 | 四隅の点 | いつでも | `new_year_eve` |
| <img src="summer_cold.png" width="72"> | 夏の涼麺 | 七〜八月につけ麺か汁なしを食べる | 涼 | 波 | いつでも | `summer_cold` |
| <img src="all_prefectures.png" width="72"> | 全国行脚 | 四十七都道府県すべてで食べる | 行脚 | 47の点の輪 | いつでも | `all_prefectures` |
| <img src="overseas.png" width="72"> | 麺の道は海を越えて | 海外の店で食べる | 渡 | 地球儀 | いつでも | `overseas` |
