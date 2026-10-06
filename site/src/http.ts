import { type CuratedShop, etagOf } from './curated.ts';

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

export async function loadCuratedShops(db: D1Database): Promise<CuratedShop[]> {
  const { results } = await db
    .prepare('SELECT id, name, address, latitude, longitude, chain, status FROM curated_shops ORDER BY id')
    .all<CuratedShop>();
  return results;
}
