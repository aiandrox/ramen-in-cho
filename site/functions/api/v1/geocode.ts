import { geocode } from '../../../src/geocode.ts';
import { type Env, json } from '../../../src/http.ts';
import { d1YahooQuota } from '../../../src/yahoo-quota.ts';

/** 住所を位置にする（Yahoo! ジオコーダ）。見つからなければ { result: null }。 */
export const onRequestGet: PagesFunction<Env> = async ({ request, env }) => {
  const query = (new URL(request.url).searchParams.get('q') ?? '').trim();
  if (!query || query.length > 100) return json({ error: '1〜100文字の q を渡してください' }, { status: 400 });
  const result = await geocode(
    { fetch: (input, init) => fetch(input, init), yahooAppId: env.YAHOO_APP_ID, yahooQuota: d1YahooQuota(env.DB) },
    query,
  );
  return json({ result });
};
