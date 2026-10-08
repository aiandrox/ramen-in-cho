-- Yahoo! YOLP への1日（日本時間）の問い合わせ回数。上限（5万回）に近づいたら Yahoo! を使わない（#373）。
-- 日付と回数だけを残し、誰が・何を探したかは残さない。
CREATE TABLE yahoo_daily_usage (
  day TEXT PRIMARY KEY,
  count INTEGER NOT NULL
);
