import { describe, expect, it } from 'vitest';

import { readJson } from './read_json.ts';
import { geocode, geocodeCacheSeconds, geocodeFailureCacheSeconds, parseGeocode } from '../src/geocode.ts';

const fixture = (name: string) =>
  readJson(`../../test/fixtures/${name}`);

function fakeCache() {
  const store = new Map<string, Response>();
  return {
    store,
    match: async (key: RequestInfo | URL) => store.get(String(key))?.clone(),
    put: async (key: RequestInfo | URL, response: Response) => void store.set(String(key), response.clone()),
  } as unknown as Cache & { store: Map<string, Response> };
}

function fakeFetch(answer: () => Response) {
  const calls: string[] = [];
  const fetchFn = (async (input: RequestInfo | URL) => {
    calls.push(String(input));
    return answer();
  }) as typeof fetch;
  return { fetch: fetchFn, calls };
}

describe('住所を位置にする', () => {
  it('保存した応答から位置と一致の細かさを読む', () => {
    expect(parseGeocode(fixture('yahoo_geocode_shinjuku.json'))).toEqual({
      latitude: 35.68956,
      longitude: 139.69172,
      address: '東京都新宿区西新宿2丁目8-1',
      level: 6,
      attribution: 'Web Services by Yahoo! JAPAN',
    });
    expect(parseGeocode({ ResultInfo: { Count: 0 } })).toBeNull();
  });

  it('同じ住所は1週間ため置き、2回目は問い合わせない', async () => {
    const cache = fakeCache();
    const upstream = fakeFetch(() => Response.json(fixture('yahoo_geocode_shinjuku.json')));
    const deps = { fetch: upstream.fetch, cache, yahooAppId: 'test-id' };
    const first = await geocode(deps, '東京都新宿区西新宿2-8-1');
    const second = await geocode(deps, '東京都新宿区西新宿2-8-1');
    expect(first?.latitude).toBe(35.68956);
    expect(second).toEqual(first);
    expect(upstream.calls).toHaveLength(1);
    expect(new URL(upstream.calls[0]).searchParams.get('query')).toBe('東京都新宿区西新宿2-8-1');
    const [stored] = cache.store.values();
    expect(stored.headers.get('cache-control')).toBe(`public, max-age=${geocodeCacheSeconds}`);
  });

  it('失敗したときは空を1日だけため置く', async () => {
    const cache = fakeCache();
    const upstream = fakeFetch(() => new Response('', { status: 503 }));
    expect(await geocode({ fetch: upstream.fetch, cache, yahooAppId: 'test-id' }, '東京都新宿区')).toBeNull();
    const [stored] = cache.store.values();
    expect(stored.headers.get('cache-control')).toBe(`public, max-age=${geocodeFailureCacheSeconds}`);
  });

  it('Client ID が無ければ問い合わせずに空を返す', async () => {
    const upstream = fakeFetch(() => Response.json(fixture('yahoo_geocode_shinjuku.json')));
    expect(await geocode({ fetch: upstream.fetch, cache: fakeCache() }, '東京都新宿区')).toBeNull();
    expect(upstream.calls).toHaveLength(0);
  });
});
