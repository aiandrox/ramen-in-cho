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

/** D1 の1日1行に足していく。足すと上限を越えるときは足さずに使わない（行は書き換えない）。 */
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
              'ON CONFLICT (day) DO UPDATE SET count = count + ?2 WHERE count + ?2 <= ?3 RETURNING count',
          )
          .bind(jstDay(now()), count, limit)
          .first<{ count: number }>();
        if (row === null) {
          console.log('yahoo daily limit reached');
          return false;
        }
        return Number(row.count) <= limit;
      } catch (e) {
        console.log(`yahoo quota failed: ${e}`);
        return false;
      }
    },
  };
}

/** Yahoo! に [count] 回問い合わせてよければ Client ID を返す（Client ID があり、今日の上限の内）。[quota] が無ければ数えない。 */
export async function yahooAppIdFor(
  deps: { yahooAppId?: string; yahooQuota?: YahooQuota },
  count: number,
): Promise<string | null> {
  const appId = deps.yahooAppId;
  if (!appId) return null;
  if (deps.yahooQuota && !(await deps.yahooQuota.take(count))) return null;
  return appId;
}
