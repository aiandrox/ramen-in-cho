import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import { type CuratedShop, etagOf, validateCuratedShops } from '../src/curated.ts';
import { curatedShops } from '../src/http.ts';
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

describe('buildSeedSql', () => {
  it('表を空にしてから入れ直す。名前の引用符は逃がす', () => {
    const sql = buildSeedSql({ shops: [shop({ name: "麺's" })] });
    expect(sql.split('\n')[0]).toBe('DELETE FROM curated_shops;');
    expect(sql).toContain("'麺''s'");
    expect(sql).toContain("'jiro', 'open');");
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
