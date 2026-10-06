import { describe, expect, it } from 'vitest';

import {
  checkRateLimit,
  clientNetwork,
  decideRateLimit,
  rateLimitKey,
  rateLimitRules,
  windowOf,
} from '../src/rate-limit.ts';

function fakeCache() {
  const store = new Map<string, Response>();
  return {
    store,
    match: async (key: RequestInfo | URL) => store.get(String(key))?.clone(),
    put: async (key: RequestInfo | URL, response: Response) => void store.set(String(key), response.clone()),
  } as unknown as Cache & { store: Map<string, Response> };
}

const minute = { name: 'minute', limit: 3, windowSeconds: 60 };
const day = { name: 'day', limit: 5, windowSeconds: 24 * 60 * 60 };
// 2026-10-06 00:00:30 UTC
const now = Date.UTC(2026, 9, 6, 0, 0, 30);

describe('回数制限の計算', () => {
  it('既定は1分に60回・1日に600回', () => {
    expect(rateLimitRules.map((r) => [r.limit, r.windowSeconds])).toEqual([
      [60, 60],
      [600, 86400],
    ]);
  });

  it('区切りの番号と、区切りが終わるまでの秒数', () => {
    expect(windowOf(minute, now)).toEqual({ index: Math.floor(now / 60000), secondsLeft: 30 });
    expect(windowOf(minute, now - 30_000).secondsLeft).toBe(60);
    expect(windowOf(minute, now + 29_999).secondsLeft).toBe(1);
    expect(windowOf(day, now).secondsLeft).toBe(86400 - 30);
  });

  it('上限の手前までは通し、上限に届いたら区切りが終わるまで待たせる', () => {
    expect(decideRateLimit([2, 4], [minute, day], now)).toEqual({ allowed: true });
    expect(decideRateLimit([3, 3], [minute, day], now)).toEqual({ allowed: false, retryAfterSeconds: 30 });
    expect(decideRateLimit([0, 5], [minute, day], now)).toEqual({ allowed: false, retryAfterSeconds: 86370 });
    expect(decideRateLimit([3, 5], [minute, day], now)).toEqual({ allowed: false, retryAfterSeconds: 86370 });
  });

  it('IPv4 はそのまま、IPv6 は /64 にまとめる', () => {
    expect(clientNetwork('203.0.113.5')).toBe('203.0.113.5');
    expect(clientNetwork('2001:db8:1:2:aaaa:bbbb:cccc:dddd')).toBe('2001:db8:1:2::/64');
    expect(clientNetwork('2001:DB8:0001:0002::1')).toBe('2001:db8:1:2::/64');
    expect(clientNetwork('2001:db8::1')).toBe('2001:db8:0:0::/64');
    expect(clientNetwork('::1')).toBe('0:0:0:0::/64');
    expect(clientNetwork('not-an-ip:x')).toBe('not-an-ip:x');
  });

  it('IP が分からなければ数えない。アプリ ID が無ければ IP だけで数える', () => {
    expect(rateLimitKey(null, '1:1:ios:a')).toBeNull();
    expect(rateLimitKey('203.0.113.5', '1:1:ios:a')).toBe('1:1:ios:a|203.0.113.5');
    expect(rateLimitKey('203.0.113.5', undefined)).toBe('-|203.0.113.5');
  });
});

describe('回数を数える', () => {
  it('上限まで通し、次は断る。区切りが変われば数え直す', async () => {
    const cache = fakeCache();
    const rules = [minute, day];
    for (let i = 0; i < 3; i++) {
      expect(await checkRateLimit({ cache }, 'k', now, rules)).toEqual({ allowed: true });
    }
    expect(await checkRateLimit({ cache }, 'k', now, rules)).toEqual({ allowed: false, retryAfterSeconds: 30 });
    // ほかの端末は別に数える。
    expect(await checkRateLimit({ cache }, 'other', now, rules)).toEqual({ allowed: true });
    // 次の1分には通るが、1日の上限（5回）に届いたら翌日まで待たせる。
    expect(await checkRateLimit({ cache }, 'k', now + 60_000, rules)).toEqual({ allowed: true });
    expect(await checkRateLimit({ cache }, 'k', now + 60_000, rules)).toEqual({ allowed: true });
    expect(await checkRateLimit({ cache }, 'k', now + 60_000, rules)).toEqual({
      allowed: false,
      retryAfterSeconds: 86400 - 90,
    });
  });

  it('ためるのは回数だけで、鍵に IP を残さない', async () => {
    const cache = fakeCache();
    await checkRateLimit({ cache }, '-|203.0.113.5', now, [minute]);
    const [[key, response]] = [...cache.store.entries()];
    expect(key).not.toContain('203.0.113.5');
    expect(await response.text()).toBe('1');
    expect(response.headers.get('cache-control')).toBe('public, max-age=30');
  });

  it('書き込みは defer に回せる', async () => {
    const cache = fakeCache();
    const deferred: Promise<unknown>[] = [];
    await checkRateLimit({ cache, defer: (p) => void deferred.push(p) }, 'k', now, [minute]);
    expect(deferred).toHaveLength(1);
    await Promise.all(deferred);
    expect(cache.store.size).toBe(1);
  });
});
