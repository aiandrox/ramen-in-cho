import { describe, expect, it } from 'vitest';

import { readJson } from './read_json.ts';
import { geocode, parseGeocode } from '../src/geocode.ts';
import type { YahooQuota } from '../src/yahoo-quota.ts';

const fixture = (name: string) =>
  readJson(`../../test/fixtures/${name}`);

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

  it('Yahoo! の結果はため置かず、同じ住所でも毎回問い合わせる', async () => {
    const upstream = fakeFetch(() => Response.json(fixture('yahoo_geocode_shinjuku.json')));
    const deps = { fetch: upstream.fetch, yahooAppId: 'test-id' };
    const first = await geocode(deps, '東京都新宿区西新宿2-8-1');
    const second = await geocode(deps, '東京都新宿区西新宿2-8-1');
    expect(first?.latitude).toBe(35.68956);
    expect(second).toEqual(first);
    expect(upstream.calls).toHaveLength(2);
    expect(new URL(upstream.calls[0]).searchParams.get('query')).toBe('東京都新宿区西新宿2-8-1');
  });

  it('失敗したときは空を返す', async () => {
    const upstream = fakeFetch(() => new Response('', { status: 503 }));
    expect(await geocode({ fetch: upstream.fetch, yahooAppId: 'test-id' }, '東京都新宿区')).toBeNull();
  });

  it('今日の上限を越えたら問い合わせずに空を返す', async () => {
    const upstream = fakeFetch(() => Response.json(fixture('yahoo_geocode_shinjuku.json')));
    const taken: number[] = [];
    const quota: YahooQuota = { take: async (n) => (taken.push(n), false) };
    expect(await geocode({ fetch: upstream.fetch, yahooAppId: 'test-id', yahooQuota: quota }, '東京都新宿区')).toBeNull();
    expect(taken).toEqual([1]);
    expect(upstream.calls).toHaveLength(0);
  });

  it('Client ID が無ければ問い合わせずに空を返す', async () => {
    const upstream = fakeFetch(() => Response.json(fixture('yahoo_geocode_shinjuku.json')));
    expect(await geocode({ fetch: upstream.fetch }, '東京都新宿区')).toBeNull();
    expect(upstream.calls).toHaveLength(0);
  });
});
