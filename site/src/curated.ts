export type ShopStatus = 'open' | 'closed';

export interface CuratedShop {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  chain: string | null;
  status: ShopStatus;
}

export interface CuratedShopsFile {
  note?: string;
  shops: CuratedShop[];
}

/** 正本の JSON を確かめる。おかしなところがあれば、どこがおかしいかを並べて投げる。 */
export function validateCuratedShops(file: CuratedShopsFile): CuratedShop[] {
  const problems: string[] = [];
  const ids = new Set<string>();
  for (const shop of file.shops) {
    const where = shop.id || shop.name || '(名前なし)';
    if (!/^[a-z0-9-]+$/.test(shop.id ?? '')) problems.push(`${where}: id は英小文字・数字・- だけ`);
    if (ids.has(shop.id)) problems.push(`${where}: id が重なっている`);
    ids.add(shop.id);
    if (!shop.name?.trim()) problems.push(`${where}: name が空`);
    if (!shop.address?.trim()) problems.push(`${where}: address が空`);
    // 日本の中にあるか（緯度 24〜46・経度 122〜154）。
    if (!(shop.latitude >= 24 && shop.latitude <= 46)) problems.push(`${where}: latitude が日本の外`);
    if (!(shop.longitude >= 122 && shop.longitude <= 154)) problems.push(`${where}: longitude が日本の外`);
    if (shop.status !== 'open' && shop.status !== 'closed') problems.push(`${where}: status は open か closed`);
  }
  if (problems.length > 0) throw new Error(problems.join('\n'));
  return file.shops;
}

/** 中身から決まる ETag。中身が同じなら同じ値になるので、アプリは変わったときだけ取り直せる。 */
export async function etagOf(shops: CuratedShop[]): Promise<string> {
  const bytes = new TextEncoder().encode(JSON.stringify(shops));
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  const hex = [...new Uint8Array(digest)]
    .slice(0, 16)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return `"${hex}"`;
}
