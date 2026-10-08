import { type Env, json, loadCuratedShops } from '../../../../src/http.ts';
import { searchByName } from '../../../../src/search/service.ts';
import { d1YahooQuota } from '../../../../src/yahoo-quota.ts';

export const onRequestGet: PagesFunction<Env> = async ({ request, env }) => {
  const url = new URL(request.url);
  const query = (url.searchParams.get('q') ?? '').trim();
  if (!query || query.length > 50) return json({ error: '1〜50文字の q を渡してください' }, { status: 400 });
  const lat = url.searchParams.get('lat');
  const lon = url.searchParams.get('lon');
  const near =
    lat !== null && lon !== null && Number.isFinite(Number(lat)) && Number.isFinite(Number(lon))
      ? { latitude: Number(lat), longitude: Number(lon) }
      : undefined;
  try {
    const shops = await searchByName(
      {
        fetch: (input, init) => fetch(input, init),
        cache: caches.default,
        yahooAppId: env.YAHOO_APP_ID,
        yahooQuota: d1YahooQuota(env.DB),
      },
      await loadCuratedShops(env.DB),
      query,
      near,
    );
    return json({ shops });
  } catch (e) {
    console.log(`search failed: ${e}`);
    return json({ error: '店名の検索に失敗しました' }, { status: 502 });
  }
};
