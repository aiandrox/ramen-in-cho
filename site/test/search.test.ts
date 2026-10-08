import { describe, expect, it } from 'vitest';

import { readJson } from './read_json.ts';
import type { CuratedShop } from '../src/curated.ts';
import { parseOpenPoiResponse } from '../src/search/openpoi.ts';
import { parseOverpassResponse } from '../src/search/overpass.ts';
import { cacheSeconds, curatedNamed, partialCacheSeconds, searchByName, searchNearby } from '../src/search/service.ts';
import { mergeFoundShops, nameQueryVariants, normalizeShopName } from '../src/search/shop.ts';
import { parseYahooLocal } from '../src/search/yahoo.ts';
import type { YahooQuota } from '../src/yahoo-quota.ts';

const fixture = (name: string) =>
  readJson(`../../test/fixtures/${name}`);

const shinjuku = { latitude: 35.69, longitude: 139.7 };

const mita: CuratedShop = {
  id: 'jiro-mita',
  name: 'ラーメン二郎 三田本店',
  address: '東京都港区三田2-16-4',
  latitude: 35.648045,
  longitude: 139.741516,
  chain: 'jiro',
  status: 'open',
};

/** 呼ばれた URL を覚え、ホストごとに決めた答えを返す fetch。 */
function fakeFetch(answers: Record<string, () => unknown>) {
  const calls: string[] = [];
  const fetchFn = (async (input: RequestInfo | URL) => {
    const url = String(input);
    calls.push(url);
    const host = new URL(url).host;
    const answer = answers[host];
    if (!answer) return new Response('', { status: 503 });
    return Response.json(answer());
  }) as typeof fetch;
  return { fetch: fetchFn, calls };
}

/** Cache API の代わり。入れた Response の cache-control も覚える。 */
function fakeCache() {
  const store = new Map<string, Response>();
  return {
    store,
    match: async (key: RequestInfo | URL) => store.get(String(key))?.clone(),
    put: async (key: RequestInfo | URL, response: Response) => void store.set(String(key), response.clone()),
  } as unknown as Cache & { store: Map<string, Response> };
}

describe('アプリと同じ解析', () => {
  it('Overpass: 名前と位置のある店だけ（保存した応答で19件）', () => {
    const shops = parseOverpassResponse(fixture('overpass_shinjuku.json'));
    expect(shops).toHaveLength(19);
  });

  it('OpenPOI と Yahoo! の保存した応答を読める', () => {
    expect(parseOpenPoiResponse(fixture('openpoi_shinjuku.json')).length).toBeGreaterThan(0);
    const yahoo = parseYahooLocal(fixture('yahoo_local_shinjuku.json'));
    expect(yahoo[0].name).toBe('麺処 さくら 新宿店');
    expect(yahoo[0].dataSource?.attributions).toEqual(['Web Services by Yahoo! JAPAN']);
  });

  it('名前の正規化・まとめ方・空白の言い換え', () => {
    expect(normalizeShopName('ＲＡＭＥＮ　海神 ')).toBe('ramen海神');
    expect(
      mergeFoundShops(
        [{ osmId: 'relation/1', name: 'らーめん鴨to葱', latitude: 35.69, longitude: 139.7 }],
        [{ name: '鴨 to 葱', latitude: 35.6901, longitude: 139.7 }],
      ),
    ).toHaveLength(1);
    expect(nameQueryVariants('麺屋　武蔵')).toEqual(['麺屋 武蔵', '麺屋武蔵']);
  });
});

describe('searchNearby', () => {
  const answers = {
    'overpass-api.de': () => fixture('overpass_shinjuku.json'),
    'api.openpoiapi.com': () => fixture('openpoi_shinjuku.json'),
  };

  it('まとめた結果を1週間ため置き、同じマスの2回目は外に問い合わせない', async () => {
    const { fetch, calls } = fakeFetch(answers);
    const cache = fakeCache();
    const deps = { fetch, cache };
    const first = await searchNearby(deps, [], shinjuku, 300);
    const asked = calls.length;
    const second = await searchNearby(deps, [], { latitude: 35.6901, longitude: 139.7001 }, 300);

    expect(first.length).toBeGreaterThan(0);
    expect(calls).toHaveLength(asked);
    expect(second.length).toBeGreaterThan(0);
    const [entry] = cache.store.values();
    // Yahoo! の Client ID が無ければ、Yahoo! は無くても「全部そろった」とみなす。
    expect(entry.headers.get('cache-control')).toBe(`public, max-age=${cacheSeconds}`);
  });

  it('一部の検索が失敗したときは1日だけため置く', async () => {
    const { fetch } = fakeFetch({ 'overpass-api.de': answers['overpass-api.de'] });
    const cache = fakeCache();
    await searchNearby({ fetch, cache }, [], shinjuku, 300);
    const [entry] = cache.store.values();
    expect(entry.headers.get('cache-control')).toBe(`public, max-age=${partialCacheSeconds}`);
  });

  it('問い合わせの中心から半径の外の店は返さない', async () => {
    const { fetch } = fakeFetch(answers);
    const shops = await searchNearby({ fetch, cache: fakeCache() }, [], shinjuku, 100);
    const all = await searchNearby({ fetch, cache: fakeCache() }, [], shinjuku, 300);
    expect(shops.length).toBeLessThan(all.length);
  });

  it('すべての検索が失敗しても、手で持つ店が近くにあれば返す。無ければ失敗', async () => {
    const { fetch } = fakeFetch({});
    const near = { latitude: 35.6482, longitude: 139.7414 };
    expect((await searchNearby({ fetch, cache: fakeCache() }, [mita], near, 300)).map((s) => s.name)).toEqual([
      'ラーメン二郎 三田本店',
    ]);
    await expect(searchNearby({ fetch, cache: fakeCache() }, [mita], shinjuku, 300)).rejects.toThrow();
  });

  it('閉店した手で持つ店は出さない', async () => {
    const { fetch } = fakeFetch({});
    const near = { latitude: 35.6482, longitude: 139.7414 };
    await expect(
      searchNearby({ fetch, cache: fakeCache() }, [{ ...mita, status: 'closed' }], near, 300),
    ).rejects.toThrow();
  });
});

describe('searchByName', () => {
  it('空白があれば、詰めた言葉でも探してまとめ、ため置く', async () => {
    const { fetch, calls } = fakeFetch({
      'api.openpoiapi.com': () => ({
        suggestions: [{ name: '麺屋武蔵', lat: 35.69, lng: 139.7, category: 'restaurant' }],
      }),
    });
    const cache = fakeCache();
    const shops = await searchByName({ fetch, cache }, [], '麺屋　武蔵', shinjuku);
    expect(shops.map((s) => s.name)).toEqual(['麺屋武蔵']);
    expect(calls.map((u) => new URL(u).searchParams.get('q'))).toEqual(['麺屋 武蔵', '麺屋武蔵']);

    await searchByName({ fetch, cache }, [], '麺屋 武蔵', shinjuku);
    expect(calls).toHaveLength(2);
  });

  it('近くの場所を渡したときは、手で持つ店も合わせて近い順に並べる', async () => {
    const { fetch } = fakeFetch({
      'api.openpoiapi.com': () => ({
        suggestions: [
          { name: '麺屋武蔵 虎洞', lat: 35.7039, lng: 139.579, category: 'restaurant' },
          { name: '麺屋武蔵 本店', lat: 35.6936, lng: 139.6977, category: 'restaurant' },
        ],
      }),
    });
    const shops = await searchByName({ fetch, cache: fakeCache() }, [], '麺屋武蔵', shinjuku);
    expect(shops.map((s) => s.name)).toEqual(['麺屋武蔵 本店', '麺屋武蔵 虎洞']);
  });

  it('手で持つ店は「二郎 関内」「二郎関内」のどちらでも合い、先に並ぶ', () => {
    const kannai: CuratedShop = { ...mita, id: 'jiro-kannai', name: 'ラーメン二郎 横浜関内店', latitude: 35.4422, longitude: 139.6309 };
    for (const q of ['二郎 関内', '二郎関内']) {
      expect(curatedNamed([mita, kannai], q).map((s) => s.name)).toEqual(['ラーメン二郎 横浜関内店']);
    }
    expect(curatedNamed([mita, kannai], '関内二郎')).toEqual([]);
  });
});

/** 決めた回数まで通す Yahoo! の数え役。 */
function fakeQuota(limit: number) {
  let used = 0;
  const quota: YahooQuota = {
    take: async (count) => {
      used += count;
      return used <= limit;
    },
  };
  return { quota, used: () => used };
}

const yahooHost = 'map.yahooapis.jp';
const isYahoo = (url: string) => new URL(url).host === yahooHost;

/** 同じ場所に OSM・Yahoo!・OpenPOI の同じ店が重なる答え。 */
const overlapping = {
  'overpass-api.de': () => ({
    elements: [{ type: 'node', id: 1, lat: 35.69, lon: 139.7, tags: { name: 'らーめん鴨to葱' } }],
  }),
  [yahooHost]: () => ({
    Feature: [
      { Name: '鴨 to 葱', Geometry: { Coordinates: '139.7,35.6901' }, Property: { Genre: [{ Code: '0106001' }] } },
      { Name: '麺処 さくら', Geometry: { Coordinates: '139.7,35.6905' }, Property: { Genre: [{ Code: '0106001' }] } },
    ],
  }),
  'api.openpoiapi.com': () => ({
    results: [
      { name: '麺処さくら', lat: 35.6905, lng: 139.7001, attributions: ['poi'] },
      { name: '中華そば 青葉', lat: 35.6895, lng: 139.7, attributions: ['poi'] },
    ],
    suggestions: [
      { name: '麺処さくら', lat: 35.6905, lng: 139.7001, category: 'restaurant', attributions: ['poi'] },
      { name: '中華そば 青葉', lat: 35.6895, lng: 139.7, category: 'restaurant', attributions: ['poi'] },
    ],
  }),
};

const sourceOf = (shop: { osmId?: string; dataSource?: { attributions: string[] } }) =>
  shop.osmId ? 'osm' : shop.dataSource?.attributions.includes('Web Services by Yahoo! JAPAN') ? 'yahoo' : 'poi';

describe('Yahoo! の結果はため置かない（#373）', () => {
  it('近くの店: ため置くのは Yahoo! 以外だけで、2回目も Yahoo! にだけ問い合わせる', async () => {
    const { fetch, calls } = fakeFetch(overlapping);
    const cache = fakeCache();
    const deps = { fetch, cache, yahooAppId: 'test-id' };
    const first = await searchNearby(deps, [], shinjuku, 300);
    const askedOthers = calls.filter((u) => !isYahoo(u)).length;
    const second = await searchNearby(deps, [], shinjuku, 300);

    expect(calls.filter(isYahoo)).toHaveLength(2);
    expect(calls.filter((u) => !isYahoo(u))).toHaveLength(askedOthers);
    expect(second).toEqual(first);
    for (const entry of cache.store.values()) {
      const text = await entry.clone().text();
      expect(text).not.toContain('Yahoo');
      expect(text).not.toContain('麺処 さくら');
      expect(entry.headers.get('cache-control')).toBe(`public, max-age=${cacheSeconds}`);
    }
  });

  it('近くの店: ためた分と混ぜても OSM → Yahoo! → OpenPOI の順に同じ店をまとめる', async () => {
    const { fetch } = fakeFetch(overlapping);
    const deps = { fetch, cache: fakeCache(), yahooAppId: 'test-id' };
    for (let i = 0; i < 2; i++) {
      const shops = await searchNearby(deps, [], shinjuku, 300);
      expect(shops.map((s) => [s.name, sourceOf(s)])).toEqual([
        ['らーめん鴨to葱', 'osm'],
        ['麺処 さくら', 'yahoo'],
        ['中華そば 青葉', 'poi'],
      ]);
    }
  });

  it('近くの店: 今日の上限を越えたら Yahoo! を使わずに探す', async () => {
    const { fetch, calls } = fakeFetch(overlapping);
    const { quota, used } = fakeQuota(1);
    const deps = { fetch, cache: fakeCache(), yahooAppId: 'test-id', yahooQuota: quota };
    await searchNearby(deps, [], shinjuku, 300);
    const shops = await searchNearby(deps, [], shinjuku, 300);

    expect(used()).toBe(2);
    expect(calls.filter(isYahoo)).toHaveLength(1);
    expect(shops.map((s) => [s.name, sourceOf(s)])).toEqual([
      ['らーめん鴨to葱', 'osm'],
      ['麺処さくら', 'poi'],
      ['中華そば 青葉', 'poi'],
    ]);
  });

  it('近くの店: ほかが失敗しても Yahoo! が答えれば返し、そのときはため置かない', async () => {
    const { fetch } = fakeFetch({ [yahooHost]: overlapping[yahooHost] });
    const cache = fakeCache();
    const shops = await searchNearby({ fetch, cache, yahooAppId: 'test-id' }, [], shinjuku, 300);
    expect(shops.map((s) => s.name)).toEqual(['鴨 to 葱', '麺処 さくら']);
    expect(cache.store.size).toBe(0);
  });

  it('店名: Yahoo! は毎回問い合わせ、言葉の数だけ数え、Yahoo! の店を OpenPOI より優先する', async () => {
    const { fetch, calls } = fakeFetch(overlapping);
    const cache = fakeCache();
    const { quota, used } = fakeQuota(100);
    const deps = { fetch, cache, yahooAppId: 'test-id', yahooQuota: quota };
    for (let i = 0; i < 2; i++) {
      const shops = await searchByName(deps, [], '麺処 さくら', shinjuku);
      expect(shops.find((s) => normalizeShopName(s.name) === '麺処さくら')?.name).toBe('麺処 さくら');
      expect(sourceOf(shops.find((s) => s.name === '麺処 さくら')!)).toBe('yahoo');
    }
    expect(calls.filter(isYahoo)).toHaveLength(4);
    expect(calls.filter((u) => !isYahoo(u))).toHaveLength(2);
    expect(used()).toBe(4);
    for (const entry of cache.store.values()) {
      expect(await entry.clone().text()).not.toContain('Yahoo');
    }
  });

  it('店名: 今日の上限を越えたら Yahoo! を使わずに探す', async () => {
    const { fetch, calls } = fakeFetch(overlapping);
    const { quota } = fakeQuota(0);
    const shops = await searchByName({ fetch, cache: fakeCache(), yahooAppId: 'test-id', yahooQuota: quota }, [], 'さくら');
    expect(calls.filter(isYahoo)).toHaveLength(0);
    expect(shops.every((s) => sourceOf(s) === 'poi')).toBe(true);
  });
});
