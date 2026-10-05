import { type CuratedShopsFile, validateCuratedShops } from './curated.ts';

const quote = (value: string | null) => (value === null ? 'NULL' : `'${value.replaceAll("'", "''")}'`);

/** 表の中身を正本どおりに入れ替える SQL。D1 は1つのファイルを1回のまとまり（トランザクション）として流す。 */
export function buildSeedSql(file: CuratedShopsFile): string {
  const shops = validateCuratedShops(file);
  const rows = shops.map(
    (s) =>
      `INSERT INTO curated_shops (id, name, address, latitude, longitude, chain, status, hours_conditions) VALUES (` +
      `${quote(s.id)}, ${quote(s.name)}, ${quote(s.address)}, ${s.latitude}, ${s.longitude}, ` +
      `${quote(s.chain ?? null)}, ${quote(s.status)}, ${quote(JSON.stringify(s.hoursConditions))});`,
  );
  return ['DELETE FROM curated_shops;', ...rows, ''].join('\n');
}
