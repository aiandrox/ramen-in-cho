// mapshaper で簡略化した都道府県の GeoJSON を、アプリに同梱する小さな形（assets/prefectures.json）に直す。
// 座標は 1/1000 度（約100m）単位の整数にし、輪ごとに1つ前の点との差で持つ。
import { readFileSync, writeFileSync } from 'node:fs';

const names = [
  '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県',
  '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
  '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県', '岐阜県',
  '静岡県', '愛知県', '三重県', '滋賀県', '京都府', '大阪府', '兵庫県',
  '奈良県', '和歌山県', '鳥取県', '島根県', '岡山県', '広島県', '山口県',
  '徳島県', '香川県', '愛媛県', '高知県', '福岡県', '佐賀県', '長崎県',
  '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県',
];

const [input, output] = process.argv.slice(2);
const geojson = JSON.parse(readFileSync(input, 'utf8'));

const prefectures = geojson.features.map((feature) => {
  const name = feature.properties.N03_001;
  const code = names.indexOf(name) + 1;
  if (code === 0) throw new Error(`unknown prefecture: ${name}`);
  const polygons =
    feature.geometry.type === 'Polygon'
      ? [feature.geometry.coordinates]
      : feature.geometry.coordinates;
  const rings = [];
  for (const polygon of polygons) {
    for (const ring of polygon) {
      const encoded = [];
      let px = 0;
      let py = 0;
      for (const [lng, lat] of ring) {
        const x = Math.round(lng * 1000);
        const y = Math.round(lat * 1000);
        if (encoded.length > 0 && x === px && y === py) continue;
        encoded.push(x - px, y - py);
        px = x;
        py = y;
      }
      if (encoded.length >= 6) rings.push(encoded);
    }
  }
  return { code, name, rings };
});
if (prefectures.length !== 47) throw new Error(`${prefectures.length} prefectures`);
prefectures.sort((a, b) => a.code - b.code);
writeFileSync(
  output,
  JSON.stringify({
    source:
      '国土数値情報（行政区域データ）N03-2024（国土交通省、CC BY 4.0）を加工して作成',
    prefectures,
  }),
);
