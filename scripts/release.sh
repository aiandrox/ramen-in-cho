#!/usr/bin/env bash
# ビルド番号を上げ、ストアへ提出するビルドを作ってアップロードする。
# 使い方・前提は docs/release/README.md 参照。
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: release.sh <ios|android|all> [options]
  -v, --version X.Y.Z  表示用バージョンを変える（省略時は据え置き）
  -b, --build N        ビルド番号を指定（省略時はpubspecとリモートのタグの大きい方+1）
      --no-bump        バージョンを変えずに、いまの値のままビルドする
                       （その番号のタグが無いか、タグとHEADの中身が同じときだけ）
      --no-upload      ビルドまで行い、アップロードはしない
      --notes FILE     GitHub Releaseに載せるリリースノート（## ja の節を持つMarkdown）
                       （省略時はコミット件名から下書きを作る）
  -y, --yes            確認プロンプトを出さない
env: env/release.env か ~/.config/ramen-in-cho/release.env があれば読み込む
  ASC_KEY_ID / ASC_ISSUER_ID  App Store Connect APIキー（iOSのアップロードに必要）
  PLAY_SERVICE_ACCOUNT_JSON   Google Playのサービスアカウント鍵（Androidのアップロードに必要）
  PLAY_TRACK                  Playのトラック（既定: internal）
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

need_value() {
  [[ -n "${2:-}" ]] || {
    echo "error: $1 には値が必要です" >&2
    usage
    exit 1
  }
}

platform="${1:-}"
case "$platform" in
  ios | android | all) shift ;;
  *)
    usage
    exit 1
    ;;
esac

new_version=""
forced_build=""
do_bump=1
do_upload=1
assume_yes=0
notes_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v | --version)
      need_value "$1" "${2:-}"
      new_version="$2"
      shift 2
      ;;
    -b | --build)
      need_value "$1" "${2:-}"
      forced_build="$2"
      shift 2
      ;;
    --no-bump)
      do_bump=0
      shift
      ;;
    --no-upload)
      do_upload=0
      shift
      ;;
    --notes)
      need_value "$1" "${2:-}"
      notes_file="$2"
      shift 2
      ;;
    -y | --yes)
      assume_yes=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

[[ $do_bump -eq 1 || -z "$forced_build" ]] || die "--no-bumpと--buildは同時に指定できません"
[[ $do_bump -eq 1 || -z "$new_version" ]] || die "--no-bumpと--versionは同時に指定できません"
if [[ -n "$notes_file" ]]; then
  [[ -f "$notes_file" ]] || die "--notesのファイルが見つかりません: ${notes_file}"
  notes_file="$(cd "$(dirname "$notes_file")" && pwd)/$(basename "$notes_file")"
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck source=scripts/release-lib.sh
source scripts/release-lib.sh

notes_ja=""
if [[ -n "$notes_file" ]]; then
  notes_ja="$(notes_section ja <"$notes_file")"
  [[ -n "$notes_ja" ]] || die "--notesのファイルに「## ja」の節が必要です: ${notes_file}"
  store_limit_warnings "$notes_ja" >&2
fi

# リポジトリの中（git の対象外の env/）か外（~/.config/ramen-in-cho/）。中は worktree ごとに置き直しが要る。
first_existing() {
  local path
  for path in "$@"; do
    [[ -f "$path" ]] && { echo "$path"; return 0; }
  done
  echo "$1"
}
config="$(first_existing env/release.env "${HOME}/.config/ramen-in-cho/release.env")"
if [[ -f "$config" ]]; then
  # shellcheck disable=SC1090
  source "$config"
fi

confirm() {
  [[ $assume_yes -eq 1 ]] && return 0
  read -r -p "$1 [y/N] " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

# 長いビルドを走らせてから足りないものに気づかないよう、前提は最初に全部見る。
asc_key=""
check_ios() {
  [[ $do_upload -eq 1 ]] || return 0
  [[ -n "${ASC_KEY_ID:-}" ]] || die "ASC_KEY_IDが未設定です（${config}）"
  [[ -n "${ASC_ISSUER_ID:-}" ]] || die "ASC_ISSUER_IDが未設定です（${config}）"
  asc_key="${HOME}/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
  [[ -f "$asc_key" ]] || die "APIキーが見つかりません: ${asc_key}"
}

check_android() {
  [[ -f android/key.properties ]] ||
    die "android/key.propertiesがありません（アップロード鍵が未設定）。docs/release/README.md 参照"
  [[ $do_upload -eq 1 ]] || return 0
  [[ -n "${PLAY_SERVICE_ACCOUNT_JSON:-}" ]] || die "PLAY_SERVICE_ACCOUNT_JSONが未設定です（${config}）"
  [[ -f "$PLAY_SERVICE_ACCOUNT_JSON" ]] || die "サービスアカウント鍵が見つかりません: ${PLAY_SERVICE_ACCOUNT_JSON}"
  command -v fastlane >/dev/null || die "fastlaneが必要です（gem install fastlane）"
}

case "$platform" in
  ios) check_ios ;;
  android) check_android ;;
  all)
    check_ios
    check_android
    ;;
esac

if [[ $do_upload -eq 1 ]]; then
  command -v gh >/dev/null || die "ghが必要です（PR・GitHub Releaseの作成に使う）"
  gh auth status >/dev/null 2>&1 || die "ghが未ログインです（gh auth login）"
fi

# 番号を上げたPRが未マージのままもう一方のOSを古いmainから出すと、同じ番号を別の中身で使ってしまう。
git fetch origin main --tags -q || die "origin/mainを取得できませんでした"
head="$(git rev-parse HEAD)"
[[ "$head" == "$(git rev-parse origin/main)" ]] ||
  die "origin/mainの最新と同じコミットで実行してください（mainを最新にしてから。未マージのリリースPRがあれば先にマージする）"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] ||
  die "追跡しているファイルに未コミットの変更があります。先に整理してください"
remote_tags="$(git ls-remote --tags origin)" || die "リモートのタグを取得できませんでした"

current_line="$(grep -m1 '^version: ' pubspec.yaml)" || die "pubspec.yamlにversionが見つかりません"
current="${current_line#version: }"
current_version="${current%+*}"
current_build="${current#*+}"
[[ "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "表示用バージョンの形式が想定外です: ${current_version}"
[[ "$current_build" =~ ^[0-9]+$ ]] || die "ビルド番号の形式が想定外です: ${current_build}"

version="${new_version:-$current_version}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "--versionはX.Y.Z形式で指定してください: ${version}"

tag_max="$(max_tagged_build <<<"$remote_tags")"
if [[ $do_bump -eq 1 ]]; then
  build="$(decide_build "$current_build" "$tag_max" "$forced_build")" || exit 1
else
  build="$current_build"
fi

target="${version}+${build}"
tag="v${target}"
remote_tag_commit="$(tagged_commit "$tag" <<<"$remote_tags")"
# squash mergeのためタグのコミットはmainに載らない。中身（ツリー）が同じなら同じビルドとみなす。
same_tree_as() {
  [[ -n "$1" ]] && git diff --quiet "$1" "$head" -- 2>/dev/null
}
if [[ $do_bump -eq 0 ]]; then
  no_bump_ref="$remote_tag_commit"
  ! same_tree_as "$remote_tag_commit" || no_bump_ref="$head"
  check_no_bump "$tag" "$no_bump_ref" "$head" || exit 1
fi
local_tag_commit="$(git rev-parse -q --verify "refs/tags/${tag}^{commit}" || true)"
if [[ -n "$local_tag_commit" ]] && { ((do_bump == 1)) || ! same_tree_as "$local_tag_commit"; }; then
  die "ローカルに${tag}タグが別のコミットを指して残っています（git tag -d ${tag} で消してから再実行）"
fi

release_branch="release/${target}"
if [[ "$version" != "$current_version" ]]; then
  title="バージョンを${target}にする"
else
  title="ビルド番号を${build}にする"
fi
if [[ $do_bump -eq 1 ]]; then
  ! git show-ref --verify -q "refs/heads/${release_branch}" ||
    die "ローカルに${release_branch}ブランチが既にあります"
  [[ -z "$(git ls-remote --heads origin "$release_branch")" ]] ||
    die "リモートに${release_branch}ブランチが既にあります"
fi

echo "==> ${current} → ${target}（${platform}）"
if [[ $do_bump -eq 1 ]]; then
  confirm "${release_branch}ブランチを作り、pubspec.yamlのversionを${target}にしてコミットします。続けますか？" || exit 1
fi

orig_ref="$(git symbolic-ref -q --short HEAD || git rev-parse HEAD)"
on_release_branch=0
uploaded=0
published=0
cleanup() {
  local status=$?
  # 開始時に追跡ファイルが汚れていないことを確かめているので、flutter buildの書き換えは全部戻してよい。
  git checkout -- ios/Flutter/Debug.xcconfig ios/Flutter/Release.xcconfig \
    ios/Runner.xcodeproj/project.pbxproj 2>/dev/null || true
  local generated=(
    ios/Podfile
    ios/Podfile.lock
    ios/Pods
    ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
    ios/Runner.xcworkspace/xcshareddata/swiftpm
  )
  local path
  for path in "${generated[@]}"; do
    # 追跡されているものは消さない（将来コミットする方針に変えた場合の保険）。
    git ls-files --error-unmatch "$path" >/dev/null 2>&1 || rm -rf "$path"
  done
  ((on_release_branch == 1)) || return 0
  if ((uploaded == 1 && published == 0)); then
    local make_tag=""
    git rev-parse -q --verify "refs/tags/${tag}" >/dev/null || make_tag="git tag -a ${tag} -m ${tag} && "
    cat >&2 <<EOF
ストアへはアップロード済みですが、タグ・PRを作れていません。${release_branch}ブランチのままにしています。次を手で実行してください:
  ${make_tag}git push origin ${release_branch} refs/tags/${tag} \\
    && gh pr create --base main --head ${release_branch} --title '${title}' --fill
EOF
    return 0
  fi
  # コミット前に失敗すると、stage済みのpubspec.yamlがcheckoutでmainへ持ち越されるため先に捨てる。
  ((published == 1)) || git reset -q --hard
  git checkout -q "$orig_ref" || return 0
  if ((published == 0)); then
    git branch -D -q "$release_branch"
    ((status == 0)) || echo "${release_branch}ブランチを削除し、${orig_ref}に戻しました" >&2
  fi
}
trap cleanup EXIT

if [[ $do_bump -eq 1 ]]; then
  git switch -q -c "$release_branch"
  on_release_branch=1
  # BSD sedでもGNU sedでも動くよう、一時ファイル経由で置き換える。
  tmp="$(mktemp)"
  sed "s/^version: .*/version: ${target}/" pubspec.yaml >"$tmp"
  mv "$tmp" pubspec.yaml
  git add pubspec.yaml
  git commit -q -m "$title" || die "コミットに失敗しました（署名の設定を確認してください）"
fi
release_commit="$(git rev-parse HEAD)"

build_ios() {
  echo "==> flutter build ipa"
  # 前回のipaが残っていると、どれを上げたのか分からなくなる。
  rm -rf build/ios/ipa
  flutter build ipa --release
  local ipa
  ipa="$(find build/ios/ipa -maxdepth 1 -name '*.ipa' | head -n 1)"
  [[ -n "$ipa" ]] || die "ipaが見つかりません（build/ios/ipa）"
  echo "==> ${ipa}"
  [[ $do_upload -eq 1 ]] || return 0

  echo "==> App Store Connectへアップロード"
  # altoolはAuthKey_<KEY_ID>.p8を既定の場所から自分で探すため、パスは渡さない。
  xcrun altool --upload-app --type ios --file "$ipa" \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
}

build_android() {
  echo "==> flutter build appbundle"
  flutter build appbundle --release
  local aab="build/app/outputs/bundle/release/app-release.aab"
  [[ -f "$aab" ]] || die "aabが見つかりません: ${aab}"
  echo "==> ${aab}"
  [[ $do_upload -eq 1 ]] || return 0

  echo "==> Google Playへアップロード（${PLAY_TRACK:-internal}）"
  fastlane supply \
    --package_name com.aiandrox.ramen_in_cho \
    --aab "$aab" \
    --track "${PLAY_TRACK:-internal}" \
    --json_key "$PLAY_SERVICE_ACCOUNT_JSON" \
    --skip_upload_metadata true \
    --skip_upload_images true \
    --skip_upload_screenshots true \
    --release_status draft
}

succeeded=0
failed=0
ios_ok=0
android_ok=0
summary=""
# allで片方が失敗しても、もう片方は進める（成功した方はストアで番号を消費するため、タグ・PRが要る）。
run_platform() {
  local label="$1" store="$2" fn="$3" rc
  set +e
  (
    set -e
    "$fn"
  )
  rc=$?
  set -e
  if ((rc == 0)); then
    succeeded=$((succeeded + 1))
    case "$label" in
      iOS) ios_ok=1 ;;
      Android) android_ok=1 ;;
    esac
    ((do_upload == 0)) || uploaded=1
    summary+="- ${label}: ${store}"$'\n'
  else
    failed=$((failed + 1))
    summary+="- ${label}: 失敗（ストアには上がっていない）"$'\n'
    echo "error: ${label}のビルド・アップロードに失敗しました" >&2
  fi
}

if [[ $do_upload -eq 1 ]]; then
  ios_store="App Store Connectへ${target}をアップロード"
  android_store="Google Play（${PLAY_TRACK:-internal}）へ${target}をアップロード"
else
  ios_store="ipaを作成（アップロードなし）"
  android_store="aabを作成（アップロードなし）"
fi
case "$platform" in
  ios) run_platform iOS "$ios_store" build_ios ;;
  android) run_platform Android "$android_store" build_android ;;
  all)
    run_platform iOS "$ios_store" build_ios
    run_platform Android "$android_store" build_android
    ;;
esac

echo
printf '%s' "$summary"
((succeeded > 0)) || die "すべて失敗しました"
if [[ $do_upload -eq 0 ]]; then
  echo "==> ビルドのみ（${target}）。タグ・ブランチは作っていません"
  exit $((failed > 0 ? 1 : 0))
fi

[[ -n "$local_tag_commit" ]] || git tag -a "$tag" -m "$tag" "$release_commit"
if [[ $do_bump -eq 1 ]]; then
  git push -q origin "$release_branch" "refs/tags/${tag}"
  published=1
  body="$(printf '%sをストアへ上げた。\n\n%s\nタグ: %s（scripts/release.sh が作成）' "$target" "$summary" "$tag")"
  gh pr create --base main --head "$release_branch" --title "$title" --body "$body" || {
    echo "error: PRを作れませんでした。${release_branch}から手で作ってください" >&2
    failed=$((failed + 1))
  }
elif [[ -z "$remote_tag_commit" ]]; then
  git push -q origin "refs/tags/${tag}"
  published=1
fi

# アップロード済みは取り消せないので、失敗しても止めずに手で作るコマンドを出す。
create_github_release() {
  if gh release view "$tag" >/dev/null 2>&1; then
    echo "==> GitHub Release ${tag} は既にあるので作りません（直すなら gh release edit ${tag}）"
    return 0
  fi
  local track="${PLAY_TRACK:-internal}" prev subjects="" ja draft=0 rel_title body_file prerelease=""
  prev="$(previous_tag "$build" <<<"$remote_tags")"
  if [[ -n "$prev" ]]; then
    subjects="$(git log --first-parent --format=%s "refs/tags/${prev}^{commit}..${release_commit}")" ||
      echo "warning: ${prev}からのコミット一覧を取れませんでした" >&2
  fi
  if [[ -n "$notes_file" ]]; then
    ja="$notes_ja"
  else
    draft=1
    ja="$(draft_ja_notes <<<"$subjects")"
  fi
  rel_title="$(release_title "$version" "$build" "$ios_ok" "$android_ok" "$track")"
  ! is_prerelease "$ios_ok" "$android_ok" "$track" || prerelease="--prerelease"
  body_file="${TMPDIR:-/tmp}"
  body_file="$(mktemp "${body_file%/}/ramen-in-cho-release.XXXXXX")"
  release_body "$draft" "$summary" "$ja" "$(format_change_lines <<<"$subjects")" "$prev" >"$body_file"
  if gh release create "$tag" --verify-tag --title "$rel_title" --notes-file "$body_file" ${prerelease:+"$prerelease"}; then
    rm -f "$body_file"
    ((draft == 0)) || echo "==> リリースノートは下書きです。GitHub Releaseの本文を利用者向けの言葉に直してください"
  else
    cat >&2 <<EOF
warning: GitHub Releaseを作れませんでした（アップロード・タグはそのまま）。次を手で実行してください:
  gh release create '${tag}' --verify-tag --title '${rel_title}' --notes-file '${body_file}' ${prerelease}
EOF
  fi
}
create_github_release

echo "==> 完了（${target}、タグ ${tag}）"
((failed == 0)) || exit 1
