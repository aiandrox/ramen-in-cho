import { describe, expect, it } from 'vitest';

import { d1YahooQuota, jstDay } from '../src/yahoo-quota.ts';

/** D1 の代わり。日ごとの回数を足し、足したあとの回数を返す。 */
function fakeDb(fail = false) {
  const rows = new Map<string, number>();
  const statements: string[] = [];
  const db = {
    prepare: (sql: string) => ({
      bind: (day: string, count: number) => ({
        first: async () => {
          statements.push(sql);
          if (fail) throw new Error('D1 unavailable');
          rows.set(day, (rows.get(day) ?? 0) + count);
          return { count: rows.get(day) };
        },
      }),
    }),
  } as unknown as D1Database;
  return { db, rows, statements };
}

describe('Yahoo! の1日の回数', () => {
  it('日本時間で日を区切る', () => {
    expect(jstDay(Date.parse('2026-10-08T14:59:59Z'))).toBe('2026-10-08');
    expect(jstDay(Date.parse('2026-10-08T15:00:00Z'))).toBe('2026-10-09');
  });

  it('上限までは使い、越えたらその日は使わない。日が変われば数え直す', async () => {
    let now = Date.parse('2026-10-08T03:00:00Z');
    const { db, rows } = fakeDb();
    const quota = d1YahooQuota(db, 3, () => now);
    expect(await quota.take(2)).toBe(true);
    expect(await quota.take(1)).toBe(true);
    expect(await quota.take(1)).toBe(false);
    expect(await quota.take(1)).toBe(false);
    now = Date.parse('2026-10-08T15:00:00Z');
    expect(await quota.take(1)).toBe(true);
    expect([...rows.keys()]).toEqual(['2026-10-08', '2026-10-09']);
  });

  it('既定の上限は 4万5千回（5万回の手前）', async () => {
    const { db, rows } = fakeDb();
    const now = () => Date.parse('2026-10-08T03:00:00Z');
    rows.set('2026-10-08', 44_999);
    const quota = d1YahooQuota(db, undefined, now);
    expect(await quota.take(1)).toBe(true);
    expect(await quota.take(1)).toBe(false);
  });

  it('数えられないときは Yahoo! を使わない', async () => {
    const { db } = fakeDb(true);
    expect(await d1YahooQuota(db).take(1)).toBe(false);
  });

  it('残すのは日付と回数だけ', async () => {
    const { db, statements } = fakeDb();
    await d1YahooQuota(db).take(1);
    expect(statements[0]).toMatch(/INSERT INTO yahoo_daily_usage \(day, count\)/);
  });
});
