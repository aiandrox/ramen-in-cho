import type { FoundShop, GeoPoint } from './shop.ts';

const nameKeywords = 'ラーメン|らーめん|拉麺|中華そば|麺|つけ麺';

export function buildOverpassQuery(center: GeoPoint, radiusMeters: number, timeoutSeconds = 10): string {
  const around = `(around:${radiusMeters},${center.latitude},${center.longitude})`;
  return (
    `[out:json][timeout:${timeoutSeconds}];(` +
    `nwr["cuisine"~"ramen"]${around};` +
    `nwr["amenity"~"^(restaurant|fast_food)$"]["name"~"${nameKeywords}"]${around};` +
    ');out center tags;'
  );
}

const nonEmpty = (value: unknown) => (typeof value === 'string' && value.trim() ? value.trim() : undefined);

/** 名前か位置の無い要素は捨てる。サーバー側の時間切れ（remark に error）は失敗にする。 */
export function parseOverpassResponse(body: any): FoundShop[] {
  if (typeof body?.remark === 'string' && body.remark.includes('error')) {
    throw new Error(`Overpass の検索が失敗しました: ${body.remark}`);
  }
  if (!Array.isArray(body?.elements)) throw new Error('Overpass の応答に elements がありません');
  const seen = new Set<string>();
  const shops: FoundShop[] = [];
  for (const element of body.elements) {
    const tags = element?.tags;
    const name = nonEmpty(tags?.name) ?? nonEmpty(tags?.['name:ja']);
    const position = element?.center ?? element;
    if (!name || typeof position?.lat !== 'number' || typeof position?.lon !== 'number') continue;
    const osmId = `${element.type}/${element.id}`;
    if (seen.has(osmId)) continue;
    seen.add(osmId);
    shops.push({
      osmId,
      name,
      latitude: position.lat,
      longitude: position.lon,
    });
  }
  return shops;
}
