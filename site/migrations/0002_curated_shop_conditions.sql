-- 手で持つ店の条件（攻略しにくさ）。JSON の配列（例: ["nightOnly","irregular"]）。正本は data/curated_shops.json。
ALTER TABLE curated_shops ADD COLUMN hours_conditions TEXT NOT NULL DEFAULT '[]';
