/**
 * Yahoo! YOLP への問い合わせの1日の回数を数える（ローカルサーチとジオコーダを合わせて数える）。
 * 上限は Client ID ごとに24時間で5万回。余裕をみて [yahooDailyLimit] を越える日は Yahoo! を使わない。
 * 残すのは日付（日本時間）と回数だけで、誰が・何を探したかは残さない。
 */
export interface YahooQuota {
  /** [count] 回ぶんを数え、今日の上限の内なら true。数えられなかったときも false（Yahoo! を使わない）。 */
  take(count: number): Promise<boolean>;
}

export const yahooDailyLimit = 45_000;

/** 日本時間の日付（YYYY-MM-DD）。 */
export function jstDay(nowMs: number): string {
  return new Date(nowMs + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

/** D1 の1日1行に足していく。足したあとの回数が上限を越えたら使わない（越えた日の分も数えたまま）。 */
export function d1YahooQuota(
  db: D1Database,
  limit = yahooDailyLimit,
  now: () => number = Date.now,
): YahooQuota {
  return {
    async take(count) {
      try {
        const row = await db
          .prepare(
            'INSERT INTO yahoo_daily_usage (day, count) VALUES (?1, ?2) ' +
              'ON CONFLICT (day) DO UPDATE SET count = count + ?2 RETURNING count',
          )
          .bind(jstDay(now()), count)
          .first<{ count: number }>();
        const used = Number(row?.count);
        if (!Number.isFinite(used)) return false;
        if (used > limit) {
          console.log('yahoo daily limit reached');
          return false;
        }
        return true;
      } catch (e) {
        console.log(`yahoo quota failed: ${e}`);
        return false;
      }
    },
  };
}
