import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import type { CuratedShop } from '../src/curated.ts';
import { parseOpenPoiResponse } from '../src/search/openpoi.ts';
import { parseOverpassResponse } from '../src/search/overpass.ts';
import { cacheSeconds, curatedNamed, partialCacheSeconds, searchByName, searchNearby } from '../src/search/service.ts';
import { mergeFoundShops, nameQueryVariants, normalizeShopName } from '../src/search/shop.ts';
import { parseYahooLocal } from '../src/search/yahoo.ts';

const fixture = (name: string) =>
  JSON.parse(readFileSync(new URL(`../../test/fixtures/${name}`, import.meta.url), 'utf8'));

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
