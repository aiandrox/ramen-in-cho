# ストアへのリリース

- 日付: 2026-10-04
- 決定: `scripts/release.sh` で行い、ビルド番号ごとに `v<X.Y.Z>+<N>` のタグと GitHub Release を作る。Android は AAB だけアップロード鍵で署名し、APK はデバッグ鍵のまま。鍵は `~/.config/ramen-in-cho/`。iOS は `ITSAppUsesNonExemptEncryption = false`
- 理由: 家族の端末には `flutter run --release` / `adb install -r` で入れており、APK の鍵を変えると上書きできず記録が消えるため。どのコミットをストアに上げたかをタグで追うため
- 関連: docs/release/README.md
