import { type Env, json, loadCuratedShops } from '../../../../src/http.ts';
import { searchNearby } from '../../../../src/search/service.ts';
import { d1YahooQuota } from '../../../../src/yahoo-quota.ts';

const maxRadius = 1000;

export const onRequestGet: PagesFunction<Env> = async ({ request, env }) => {
  const url = new URL(request.url);
  const latitude = Number(url.searchParams.get('lat'));
  const longitude = Number(url.searchParams.get('lon'));
  const radius = Math.round(Number(url.searchParams.get('radius') ?? 300));
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || !(radius > 0 && radius <= maxRadius)) {
    return json({ error: 'lat・lon と 1〜1000 の radius を渡してください' }, { status: 400 });
  }
  try {
    const shops = await searchNearby(
      {
        fetch: (input, init) => fetch(input, init),
        cache: caches.default,
        yahooAppId: env.YAHOO_APP_ID,
        yahooQuota: d1YahooQuota(env.DB),
      },
      await loadCuratedShops(env.DB),
      { latitude, longitude },
      radius,
    );
    return json({ shops });
  } catch (e) {
    console.log(`nearby failed: ${e}`);
    return json({ error: '店の検索に失敗しました' }, { status: 502 });
  }
};
