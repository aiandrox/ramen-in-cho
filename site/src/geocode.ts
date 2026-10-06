import { yahooAttribution } from './search/yahoo.ts';

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
  cache: Pick<Cache, 'match' | 'put'>;
  yahooAppId?: string;
}

const base = 'https://map.yahooapis.jp/geocode/V1/geoCoder';
const upstreamTimeoutMs = 10_000;
export const geocodeCacheSeconds = 7 * 24 * 60 * 60;
export const geocodeFailureCacheSeconds = 24 * 60 * 60;

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

/** 空白をそろえ、同じ住所は同じため置きを使う。 */
export const normalizeAddress = (address: string) => address.replaceAll('　', ' ').replace(/\s+/g, ' ').trim();

/** 住所を位置にする。Client ID が無いときや見つからないときは null。誰が探したかは残さない。 */
export async function geocode(deps: GeocodeDeps, address: string): Promise<GeocodeResult | null> {
  const appId = deps.yahooAppId;
  const query = normalizeAddress(address);
  if (!appId || !query) return null;
  const key = `https://cache.ramen-in-cho.internal/geocode/v1?${new URLSearchParams({ q: query })}`;
  const hit = await deps.cache.match(key);
  if (hit) return (await hit.json()) as GeocodeResult | null;
  let result: GeocodeResult | null = null;
  let ok = false;
  try {
    const response = await deps.fetch(buildGeocodeUrl(query, appId), {
      signal: AbortSignal.timeout(upstreamTimeoutMs),
    });
    if (!response.ok) throw new Error(`geocode: HTTP ${response.status}`);
    result = parseGeocode(await response.json());
    ok = true;
  } catch (e) {
    console.log(`geocode failed: ${e}`);
  }
  await deps.cache.put(
    key,
    new Response(JSON.stringify(result), {
      headers: {
        'content-type': 'application/json',
        'cache-control': `public, max-age=${ok ? geocodeCacheSeconds : geocodeFailureCacheSeconds}`,
      },
    }),
  );
  return result;
}
