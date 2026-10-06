/** 検索で見つかった店。アプリの FoundShop と同じ形（JSON の名前もそろえる）。 */
export interface FoundShop {
  osmId?: string;
  name: string;
  latitude: number;
  longitude: number;
  address?: string;
  dataSource?: { licenses: string[]; attributions: string[] };
}

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

/** 2点の距離（m）。アプリの distanceMeters と同じ球面の式。 */
export function distanceMeters(a: GeoPoint, b: GeoPoint): number {
  const r = 6371000;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLon = rad(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(h));
}

/** 空白を除き、全角英数を半角に、英字を小文字にそろえる（アプリの normalizeShopName と同じ）。 */
export function normalizeShopName(name: string): string {
  let out = '';
  for (const ch of name) {
    const code = ch.codePointAt(0)!;
    if (code === 0x20 || code === 0x3000) continue;
    out += String.fromCodePoint(code >= 0xff01 && code <= 0xff5e ? code - 0xfee0 : code);
  }
  return out.toLowerCase();
}

export function shopNamesLookAlike(a: string, b: string): boolean {
  const [x, y] = [normalizeShopName(a), normalizeShopName(b)];
  const [shorter, longer] = x.length <= y.length ? [x, y] : [y, x];
  return shorter.length >= 2 && longer.includes(shorter);
}

/** 表記ゆれを許して同じ店とみなす距離。 */
export const lookAlikeShopMeters = 100;

/** 先の一覧を優先し、後の一覧の店は重ならないものだけ足す（アプリの mergeFoundShops と同じ）。 */
export function mergeFoundShops(first: FoundShop[], rest: FoundShop[]): FoundShop[] {
  const merged = [...first];
  for (const shop of rest) {
    if (
      merged.some(
        (other) =>
          distanceMeters(shop, other) <= lookAlikeShopMeters && shopNamesLookAlike(shop.name, other.name),
      )
    ) {
      continue;
    }
    merged.push(shop);
  }
  return merged;
}

/** 店名で探す言葉。全角の空白を半角にそろえ、空白があれば詰めた言葉も足す（アプリの nameQueryVariants と同じ）。 */
export function nameQueryVariants(query: string): string[] {
  const spaced = query.replaceAll('　', ' ').trim().split(/\s+/).filter(Boolean).join(' ');
  if (!spaced) return [];
  const joined = spaced.replaceAll(' ', '');
  return joined === spaced ? [spaced] : [spaced, joined];
}

export const ramenName = /ラーメン|らーめん|らぁ麺|らぁ麵|拉麺|中華そば|つけ麺|まぜそば|油そば|麺|麵/;
