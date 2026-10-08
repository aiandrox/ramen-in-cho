import { yahooAttribution } from './search/yahoo.ts';
import { type YahooQuota, yahooAppIdFor } from './yahoo-quota.ts';

/** 住所を位置にした結果。`level` は Yahoo! の住所の一致の細かさ（1 都道府県〜6 号）。 */
export interface GeocodeResult {
  latitude: number;
  longitude: number;
  address: string;
  level: number;
  attribution: string;
}

export interface GeocodeDeps {
  fetch: typeof fetch;
  yahooAppId?: string;
  /** Yahoo! への1日の回数。無ければ数えない（テスト用）。 */
  yahooQuota?: YahooQuota;
}

const base = 'https://map.yahooapis.jp/geocode/V1/geoCoder';
const upstreamTimeoutMs = 10_000;

export function buildGeocodeUrl(address: string, appId: string): string {
  const params = new URLSearchParams({ appid: appId, query: address.trim(), results: '1', output: 'json' });
  return `${base}?${params}`;
}

/** いちばん合う1件。読めなければ null。 */
export function parseGeocode(body: any): GeocodeResult | null {
  const features = body?.Feature;
  if (!Array.isArray(features)) return null;
  for (const f of features) {
    const coordinates = f?.Geometry?.Coordinates;
    if (typeof coordinates !== 'string') continue;
    const [longitude, latitude] = coordinates.split(',').map(Number);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) continue;
    const address =
      typeof f.Property?.Address === 'string' ? f.Property.Address : typeof f.Name === 'string' ? f.Name : '';
    const level = Number(f.Property?.AddressMatchingLevel ?? 0);
    return { latitude, longitude, address, level: Number.isFinite(level) ? level : 0, attribution: yahooAttribution };
  }
  return null;
}

/** 空白をそろえる。 */
export const normalizeAddress = (address: string) => address.replaceAll('　', ' ').replace(/\s+/g, ' ').trim();

/**
 * 住所を位置にする。Client ID が無いとき・今日の上限を越えたとき・見つからないときは null。誰が探したかは残さない。
 * Yahoo! の結果は利用条件（保存・キャッシュの禁止）のため ためず、毎回問い合わせる（#373）。
 */
export async function geocode(deps: GeocodeDeps, address: string): Promise<GeocodeResult | null> {
  const query = normalizeAddress(address);
  if (!query) return null;
  const appId = await yahooAppIdFor(deps, 1);
  if (!appId) return null;
  try {
    const response = await deps.fetch(buildGeocodeUrl(query, appId), {
      signal: AbortSignal.timeout(upstreamTimeoutMs),
    });
    if (!response.ok) throw new Error(`geocode: HTTP ${response.status}`);
    return parseGeocode(await response.json());
  } catch (e) {
    console.log(`geocode failed: ${e}`);
    return null;
  }
}
