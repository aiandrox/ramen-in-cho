import type { CuratedShop } from '../curated.ts';
import { buildOpenPoiNameUrl, buildOpenPoiUrl, openPoiKeywords, parseOpenPoiNameResults, parseOpenPoiResponse } from './openpoi.ts';
import { buildOverpassQuery, parseOverpassResponse } from './overpass.ts';
import {
  type FoundShop,
  type GeoPoint,
  distanceMeters,
  mergeFoundShops,
  nameQueryVariants,
  normalizeShopName,
} from './shop.ts';
import type { YahooQuota } from '../yahoo-quota.ts';
import { buildYahooNameUrl, buildYahooNearbyUrl, parseYahooLocal } from './yahoo.ts';

export interface SearchDeps {
  fetch: typeof fetch;
  /** Yahoo! 以外の検索結果のため置き（Cache API）。テストでは Map で差し替える。 */
  cache: Pick<Cache, 'match' | 'put'>;
  yahooAppId?: string;
  /** Yahoo! への1日の回数。無ければ数えない（テスト用）。 */
  yahooQuota?: YahooQuota;
}

const userAgent = 'ramen-in-cho (https://github.com/aiandrox/ramen-in-cho)';
const upstreamTimeoutMs = 10_000;

/**
 * Yahoo! 以外（Overpass・OpenPOI）の検索結果をためておく長さ。店はそう変わらないので1週間。どれかの検索が失敗したときは1日だけ。
 * Yahoo! の結果は利用条件（保存・キャッシュの禁止）のため ためず、毎回問い合わせて混ぜる（#373）。
 */
export const cacheSeconds = 7 * 24 * 60 * 60;
export const partialCacheSeconds = 24 * 60 * 60;

/** 近くの店のため置きのマス目（緯度経度 0.003 度 ≒ 300m）。マスの中心から少し広めに探し、問い合わせの中心で絞る。 */
export const cellDegrees = 0.003;
const cellMarginMeters = 250;

async function getJson(deps: SearchDeps, url: string, init: RequestInit = {}): Promise<any> {
  const response = await deps.fetch(url, {
    ...init,
    headers: { 'user-agent': userAgent, ...init.headers },
    signal: AbortSignal.timeout(upstreamTimeoutMs),
  });
  if (!response.ok) throw new Error(`${new URL(url).host}: HTTP ${response.status}`);
  return response.json();
}

/** 各検索を同時に呼び、失敗したものは null にする。 */
async function attempt(search: () => Promise<FoundShop[]>): Promise<FoundShop[] | null> {
  try {
    return await search();
  } catch (e) {
    console.log(`search failed: ${e}`);
    return null;
  }
}

/** Yahoo! に [count] 回問い合わせてよいか（Client ID があり、今日の上限の内）。 */
async function yahooAppIdFor(deps: SearchDeps, count: number): Promise<string | null> {
  const appId = deps.yahooAppId;
  if (!appId) return null;
  if (deps.yahooQuota && !(await deps.yahooQuota.take(count))) return null;
  return appId;
}

/** ため置く Yahoo! 以外の結果。OpenStreetMap と OpenPOI は優先の順を保つため分けて持つ。 */
interface Cachable {
  osm: FoundShop[];
  poi: FoundShop[];
}

interface Loaded extends Cachable {
  /** どれか1つでも答えたか。どれも失敗したらためない。 */
  any: boolean;
  /** すべて答えたか（1週間ためる）。 */
  complete: boolean;
}

const cacheUrl = (path: string, params: Record<string, string>) =>
  `https://cache.ramen-in-cho.internal/${path}?${new URLSearchParams(params)}`;

/** ため置きにあればそれを、無ければ [load] して ため置く。どれも失敗したら null（ためない）。 */
async function cached(deps: SearchDeps, key: string, load: () => Promise<Loaded>): Promise<Cachable | null> {
  const hit = await deps.cache.match(key);
  if (hit) return (await hit.json()) as Cachable;
  const { osm, poi, any, complete } = await load();
  if (!any) return null;
  await deps.cache.put(
    key,
    new Response(JSON.stringify({ osm, poi } satisfies Cachable), {
      headers: {
        'content-type': 'application/json',
        'cache-control': `public, max-age=${complete ? cacheSeconds : partialCacheSeconds}`,
      },
    }),
  );
  return { osm, poi };
}

const curatedFound = (shop: CuratedShop): FoundShop => ({
  name: shop.name,
  latitude: shop.latitude,
  longitude: shop.longitude,
  address: shop.address,
});

/** [center] から [radiusMeters] 以内の店。手で持つ店は通信できなくても出す。 */
export async function searchNearby(
  deps: SearchDeps,
  curated: CuratedShop[],
  center: GeoPoint,
  radiusMeters: number,
): Promise<FoundShop[]> {
  const near = (shop: GeoPoint) => distanceMeters(center, shop) <= radiusMeters;
  const curatedNear = curated.filter((s) => s.status === 'open' && near(s)).map(curatedFound);
  const lat = Math.round(center.latitude / cellDegrees);
  const lon = Math.round(center.longitude / cellDegrees);
  const cell = { latitude: lat * cellDegrees, longitude: lon * cellDegrees };
  const searchRadius = radiusMeters + cellMarginMeters;
  const [stored, yahoo] = await Promise.all([
    cached(deps, cacheUrl('nearby/v2', { cell: `${lat},${lon}`, r: `${radiusMeters}` }), async () => {
      const [osm, ...poi] = await Promise.all([
        attempt(async () =>
          parseOverpassResponse(
            await getJson(deps, 'https://overpass-api.de/api/interpreter', {
              method: 'POST',
              headers: { 'content-type': 'application/x-www-form-urlencoded' },
              body: new URLSearchParams({ data: buildOverpassQuery(cell, searchRadius) }).toString(),
            }),
          ),
        ),
        ...openPoiKeywords.map((keyword) =>
          attempt(async () => parseOpenPoiResponse(await getJson(deps, buildOpenPoiUrl(cell, keyword, searchRadius)))),
        ),
      ]);
      return {
        osm: osm ?? [],
        poi: mergeFoundShops([], poi.flatMap((shops) => shops ?? [])),
        any: osm !== null || poi.some((shops) => shops !== null),
        complete: osm !== null && poi.every((shops) => shops !== null),
      };
    }),
    (async () => {
      const appId = await yahooAppIdFor(deps, 1);
      return appId
        ? attempt(async () => parseYahooLocal(await getJson(deps, buildYahooNearbyUrl(cell, searchRadius, appId))))
        : null;
    })(),
  ]);
  if (stored === null && yahoo === null) {
    if (curatedNear.length > 0) return curatedNear;
    throw new Error('店の検索がすべて失敗しました');
  }
  // OpenStreetMap の店を優先し（ID があるため）、次に Yahoo!、最後に OpenPOI。
  const found = mergeFoundShops(stored?.osm ?? [], [...(yahoo ?? []), ...(stored?.poi ?? [])]);
  const inRange = found.filter(near);
  return mergeFoundShops(
    inRange.filter((s) => s.osmId),
    [...curatedNear, ...inRange.filter((s) => !s.osmId)],
  );
}

/** 手で持つ店を名前で探す（アプリの builtinShopsNamed と同じ合わせ方）。近い順に5件まで。 */
export function curatedNamed(curated: CuratedShop[], query: string, near?: GeoPoint, limit = 5): FoundShop[] {
  const words = query.replaceAll('　', ' ').split(' ').map(normalizeShopName).filter(Boolean);
  if (words.length === 0) return [];
  const joined = words.join('');
  const appearsInOrder = (name: string) => {
    let from = 0;
    for (const ch of joined) {
      const index = name.indexOf(ch, from);
      if (index < 0) return false;
      from = index + ch.length;
    }
    return true;
  };
  const matched = curated.filter((shop) => {
    if (shop.status !== 'open') return false;
    const name = normalizeShopName(shop.name);
    return words.every((w) => name.includes(w)) || appearsInOrder(name);
  });
  if (near) matched.sort((a, b) => distanceMeters(near, a) - distanceMeters(near, b));
  return matched.slice(0, limit).map(curatedFound);
}

/** 店名で全国から探す。空白の有無で結果が変わるので、空白を詰めた言葉でも探してまとめる。 */
export async function searchByName(
  deps: SearchDeps,
  curated: CuratedShop[],
  query: string,
  near?: GeoPoint,
): Promise<FoundShop[]> {
  const variants = nameQueryVariants(query);
  if (variants.length === 0) return [];
  const fromCurated = curatedNamed(curated, query, near);
  // 先の検索には 0.1 度（約10km）に丸めた場所を渡してため置き、並びは最後に本当の場所からの近さで決める。
  const area = near ? `${Math.round(near.latitude * 10)},${Math.round(near.longitude * 10)}` : '';
  const anchor = near ? { latitude: Math.round(near.latitude * 10) / 10, longitude: Math.round(near.longitude * 10) / 10 } : undefined;
  const [stored, yahoo] = await Promise.all([
    cached(deps, cacheUrl('search/v3', { q: variants[0], area }), async () => {
      const poi = await Promise.all(
        variants.map((v) =>
          attempt(async () => parseOpenPoiNameResults(await getJson(deps, buildOpenPoiNameUrl(v, anchor)))),
        ),
      );
      return {
        osm: [],
        poi: mergeFoundShops([], poi.flatMap((r) => r ?? [])),
        any: poi.some((r) => r !== null),
        complete: poi.every((r) => r !== null),
      };
    }),
    (async () => {
      const appId = await yahooAppIdFor(deps, variants.length);
      if (!appId) return null;
      const results = await Promise.all(
        variants.map((v) => attempt(async () => parseYahooLocal(await getJson(deps, buildYahooNameUrl(v, appId, anchor))))),
      );
      return results.every((r) => r === null) ? null : results.flatMap((r) => r ?? []);
    })(),
  ]);
  if (stored === null && yahoo === null) {
    if (fromCurated.length > 0) return fromCurated;
    throw new Error('店名の検索がすべて失敗しました');
  }
  // 同じ店なら、ラーメン店の業種で絞れる Yahoo! のほうを残す。
  const found = mergeFoundShops([], [...(yahoo ?? []), ...(stored?.poi ?? [])]);
  const shops = mergeFoundShops(fromCurated, found);
  if (near) shops.sort((a, b) => distanceMeters(near, a) - distanceMeters(near, b));
  return shops;
}
