export type ShopStatus = 'open' | 'closed';

/** 店の条件（攻略しにくさ）。アプリの HoursCondition と同じ名前。 */
export const hoursConditionNames = [
  'lunchOnly',
  'nightOnly',
  'weekdaysOnly',
  'weekendsOnly',
  'fewDays',
  'irregular',
  'badAccess',
] as const;
export type HoursCondition = (typeof hoursConditionNames)[number];

/** API で配る1件。 */
export interface CuratedShop {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  chain: string | null;
  status: ShopStatus;
  /** 初めて記録するときの店の条件の下書き。調べていない店は空。 */
  hoursConditions: HoursCondition[];
}

/** 正本の1件。条件を調べた出どころは正本にだけ残し、API では配らない。 */
export interface CuratedShopEntry extends CuratedShop {
  /** 条件を確かめられたか。false の店は条件を空にする。 */
  conditionsVerified?: boolean;
  conditionsSource?: { url: string; checkedAt: string; confidence?: string };
}

export interface CuratedShopsFile {
  note?: string;
  shops: CuratedShopEntry[];
}

/** 正本の JSON を確かめる。おかしなところがあれば、どこがおかしいかを並べて投げる。 */
export function validateCuratedShops(file: CuratedShopsFile): CuratedShopEntry[] {
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
    const conditions: unknown[] = Array.isArray(shop.hoursConditions) ? shop.hoursConditions : [];
    if (!Array.isArray(shop.hoursConditions)) problems.push(`${where}: hoursConditions は配列`);
    for (const c of conditions) {
      if (!hoursConditionNames.includes(c as HoursCondition)) problems.push(`${where}: 知らない条件 ${String(c)}`);
    }
    if (new Set(conditions).size !== conditions.length) problems.push(`${where}: 条件が重なっている`);
    if (conditions.includes('lunchOnly') && conditions.includes('nightOnly')) {
      problems.push(`${where}: 昼のみと夜のみは同時に持てない`);
    }
    if (conditions.length > 0 && shop.conditionsVerified !== true) {
      problems.push(`${where}: 確かめていない店（conditionsVerified が true でない）に条件がある`);
    }
    const source = shop.conditionsSource;
    if (source !== undefined) {
      if (!/^https:\/\//.test(source.url ?? '')) problems.push(`${where}: conditionsSource.url は https の URL`);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(source.checkedAt ?? '')) {
        problems.push(`${where}: conditionsSource.checkedAt は YYYY-MM-DD`);
      }
    } else if (shop.conditionsVerified === true) {
      problems.push(`${where}: 確かめた店には conditionsSource（url・checkedAt）を書く`);
    }
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
