import { type CuratedShop, type HoursCondition, etagOf, hoursConditionNames } from './curated.ts';

export interface Env {
  DB: D1Database;
  /** Yahoo! ローカルサーチの Client ID（`wrangler pages secret put YAHOO_APP_ID`）。無ければ Yahoo! では探さない。 */
  YAHOO_APP_ID?: string;
  /** "true" なら、Firebase App Check のトークンが無い・正しくない問い合わせを断る。 */
  APP_CHECK_ENFORCE?: string;
}

export const json = (body: unknown, init: ResponseInit = {}) =>
  new Response(JSON.stringify(body), {
    ...init,
    headers: { 'content-type': 'application/json; charset=utf-8', ...init.headers },
  });

/** アプリに持たせる店の一覧（閉店も含む。アプリは閉店した店を候補から外す）。 */
export async function curatedShops(request: Request, shops: CuratedShop[]): Promise<Response> {
  const etag = await etagOf(shops);
  const headers = {
    etag,
    // アプリは1日1回までしか取りに来ないが、端の cache にも1時間ためる。
    'cache-control': 'public, max-age=3600',
  };
  if (request.headers.get('if-none-match') === etag) {
    return new Response(null, { status: 304, headers });
  }
  return json({ shops }, { headers });
}

type CuratedShopRow = Omit<CuratedShop, 'hoursConditions'> & { hours_conditions: string | null };

export async function loadCuratedShops(db: D1Database): Promise<CuratedShop[]> {
  const { results } = await db
    .prepare(
      'SELECT id, name, address, latitude, longitude, chain, status, hours_conditions FROM curated_shops ORDER BY id',
    )
    .all<CuratedShopRow>();
  return results.map(({ hours_conditions, ...shop }) => ({
    ...shop,
    hoursConditions: parseHoursConditions(hours_conditions),
  }));
}

/** 表に入れた条件（JSON の配列）。読めない値・知らない条件は捨てる。 */
export function parseHoursConditions(text: string | null): HoursCondition[] {
  try {
    const value: unknown = JSON.parse(text ?? '[]');
    if (!Array.isArray(value)) return [];
    return value.filter((c): c is HoursCondition => hoursConditionNames.includes(c as HoursCondition));
  } catch {
    return [];
  }
}
