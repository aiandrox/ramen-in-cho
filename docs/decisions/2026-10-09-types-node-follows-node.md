# @types/node は動かしている Node の版にそろえる

- 日付: 2026-10-09
- 決定: `site/` の `@types/node` は、Site CI と Site Deploy で動かしている Node の版（今は24）のメジャーにそろえる。Dependabot は `@types/node` のメジャーの更新を出さない（`.github/dependabot.yml` の `ignore`）。Node の版を上げるときに、ワークフローの `node-version` と一緒に `@types/node` のメジャーを手で上げる
- 理由: 型だけ新しい版にすると、24 に無い機能を使っても型の確認を通ってしまい、本番で初めて動かないことに気づくため（aiandrox の判断）
- 関連: #383・#367
