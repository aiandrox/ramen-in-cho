#!/usr/bin/env bash
# サーバーの API に App Check のトークンなしで問い合わせ、site/wrangler.toml の APP_CHECK_ENFORCE に応じた答えが返るか確かめる。
# 失敗した内容は標準出力に1行ずつ書き、1つでも失敗すれば 1 で終わる。
set -uo pipefail

base="${SITE_URL:-https://ramen-in-cho.aiandrox.com}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
enforce="$(sed -nE 's/^APP_CHECK_ENFORCE *= *"([^"]*)".*/\1/p' "$root/site/wrangler.toml")"
body="$(mktemp)"
failed=0

# check <パス> <期待するステータス> <jq の条件>。一時的な不調で issue を立てないよう、3回まで試す。
check() {
  local path="$1" want="$2" filter="$3" status="" type="" i
  for i in 1 2 3; do
    read -r status type < <(curl -sS -o "$body" -w '%{http_code} %{content_type}\n' --max-time 30 "$base$path" 2>/dev/null || echo "000 -")
    if [[ "$status" == "$want" && "$type" == application/json* ]] && jq -e "$filter" "$body" >/dev/null 2>&1; then
      echo "ok: ${path} → ${status}"
      return
    fi
    [[ $i -lt 3 ]] && sleep "${RETRY_WAIT:-30}"
  done
  echo "NG: ${path} → ${status}（期待 ${want}）$(head -c 200 "$body" | tr '\n' ' ')"
  failed=1
}

near="lat=35.6909&lon=139.7003"
echo "APP_CHECK_ENFORCE=$enforce"
if [[ "$enforce" == "true" ]]; then
  # 断るのは関数の入口（_middleware.ts）なので、401 の JSON が返れば関数は動いている。D1 と検索サービスは見られない。
  for path in /api/v1/curated-shops "/api/v1/shops/nearby?$near&radius=300" "/api/v1/shops/search?q=%E3%83%A9%E3%83%BC%E3%83%A1%E3%83%B3&$near"; do
    check "$path" 401 '.error | type == "string"'
  done
else
  check /api/v1/curated-shops 200 '.shops | length > 0'
  # 502 は、先の検索サービス（Overpass・OpenPOI・Yahoo!）がすべて失敗したとき。
  check "/api/v1/shops/nearby?$near&radius=300" 200 '.shops | type == "array"'
  check "/api/v1/shops/search?q=%E3%83%A9%E3%83%BC%E3%83%A1%E3%83%B3&$near" 200 '.shops | type == "array"'
fi
rm -f "$body"
exit $failed
