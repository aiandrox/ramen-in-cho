import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import { type CuratedShop, type CuratedShopEntry, etagOf, validateCuratedShops } from '../src/curated.ts';
import { curatedShops, parseHoursConditions } from '../src/http.ts';
import { buildSeedSql } from '../src/seed.ts';

const file = JSON.parse(readFileSync(new URL('../../data/curated_shops.json', import.meta.url), 'utf8'));

const shop = (overrides: Partial<CuratedShop> = {}): CuratedShop => ({
  id: 'jiro-mita',
  name: 'ラーメン二郎 三田本店',
  address: '東京都港区三田2-16-4',
  latitude: 35.648045,
  longitude: 139.741516,
  chain: 'jiro',
  status: 'open',
  hoursConditions: [],
  ...overrides,
});

describe('data/curated_shops.json', () => {
  it('正本の中身が決まりどおり', () => {
    expect(validateCuratedShops(file).length).toBeGreaterThan(0);
  });
});

describe('validateCuratedShops', () => {
  it('id の重なり・日本の外の位置・知らない status を、まとめて知らせる', () => {
    expect(() =>
      validateCuratedShops({
        shops: [shop(), shop({ latitude: 10 }), shop({ id: 'x', status: 'gone' as never })],
      }),
    ).toThrow(/id が重なっている[\s\S]*latitude が日本の外[\s\S]*status は open か closed/);
  });
});

describe('店の条件', () => {
  const source = { url: 'https://example.com/sengawa', checkedAt: '2026-10-05' };
  const sengawa = (overrides: Partial<CuratedShopEntry> = {}): CuratedShopEntry => ({
    ...shop({ id: 'jiro-sengawa', name: 'ラーメン二郎 仙川店' }),
    hoursConditions: ['nightOnly'],
    conditionsVerified: true,
    conditionsSource: source,
    ...overrides,
  });

  it('確かめた店の条件は通る', () => {
    expect(validateCuratedShops({ shops: [sengawa()] })[0]!.hoursConditions).toEqual(['nightOnly']);
  });

  it('知らない条件・昼のみと夜のみの組み合わせ・確かめていない店の条件・出どころの無い店を知らせる', () => {
    expect(() =>
      validateCuratedShops({
        shops: [
          sengawa({ id: 'a', hoursConditions: ['someday' as never] }),
          sengawa({ id: 'b', hoursConditions: ['lunchOnly', 'nightOnly'] }),
          sengawa({ id: 'c', conditionsVerified: false }),
          sengawa({ id: 'd', conditionsSource: undefined }),
          sengawa({ id: 'e', conditionsSource: { url: 'http://x', checkedAt: '10/5' } }),
        ],
      }),
    ).toThrow(
      /知らない条件 someday[\s\S]*昼のみと夜のみ[\s\S]*確かめていない店[\s\S]*conditionsSource（url・checkedAt）[\s\S]*https の URL[\s\S]*YYYY-MM-DD/,
    );
  });

  it('表の値を読む。読めない値や知らない条件は捨てる', () => {
    expect(parseHoursConditions('["nightOnly","someday"]')).toEqual(['nightOnly']);
    expect(parseHoursConditions(null)).toEqual([]);
    expect(parseHoursConditions('{')).toEqual([]);
  });

  it('API では出どころを配らない', async () => {
    const response = await curatedShops(new Request('https://api/v1/curated-shops'), [shop({ hoursConditions: ['irregular'] })]);
    const body = (await response.json()) as { shops: Record<string, unknown>[] };
    expect(body.shops[0]!.hoursConditions).toEqual(['irregular']);
    expect(body.shops[0]).not.toHaveProperty('conditionsSource');
  });
});

describe('buildSeedSql', () => {
  it('表を空にしてから入れ直す。名前の引用符は逃がす', () => {
    const sql = buildSeedSql({ shops: [shop({ name: "麺's" })] });
    expect(sql.split('\n')[0]).toBe('DELETE FROM curated_shops;');
    expect(sql).toContain("'麺''s'");
    expect(sql).toContain(`'jiro', 'open', '[]');`);
    const verified = {
      ...shop({ hoursConditions: ['irregular'] }),
      conditionsVerified: true,
      conditionsSource: { url: 'https://example.com/mita', checkedAt: '2026-10-05' },
    };
    expect(buildSeedSql({ shops: [verified] })).toContain(`'["irregular"]');`);
  });
});

describe('GET /v1/curated-shops', () => {
  it('一覧と ETag を返し、同じ ETag で聞かれたら 304 を返す', async () => {
    const shops = [shop()];
    const first = await curatedShops(new Request('https://api/v1/curated-shops'), shops);
    expect(first.status).toBe(200);
    expect(await first.json()).toEqual({ shops });
    const etag = first.headers.get('etag')!;
    expect(etag).toBe(await etagOf(shops));

    const again = await curatedShops(
      new Request('https://api/v1/curated-shops', { headers: { 'if-none-match': etag } }),
      shops,
    );
    expect(again.status).toBe(304);
  });

  it('中身が変われば ETag も変わる', async () => {
    expect(await etagOf([shop()])).not.toBe(await etagOf([shop({ status: 'closed' })]));
  });
});
