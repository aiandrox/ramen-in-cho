/** 回数制限の1つの決まり。[windowSeconds] 秒ごとの区切りの中で [limit] 回まで。 */
export interface RateLimitRule {
  name: string;
  limit: number;
  windowSeconds: number;
}

/** 1台（App Check のアプリと接続元の組）あたりの回数。ふつうの使い方（1日に数回〜数十回の検索）では届かない。 */
export const rateLimitRules: readonly RateLimitRule[] = [
  { name: 'minute', limit: 60, windowSeconds: 60 },
  { name: 'day', limit: 600, windowSeconds: 24 * 60 * 60 },
];

/** [nowMs] を含む区切りの番号と、区切りが終わるまでの秒数（1以上）。 */
export function windowOf(rule: RateLimitRule, nowMs: number): { index: number; secondsLeft: number } {
  const windowMs = rule.windowSeconds * 1000;
  const index = Math.floor(nowMs / windowMs);
  return { index, secondsLeft: Math.max(1, Math.ceil(((index + 1) * windowMs - nowMs) / 1000)) };
}

export type RateLimitDecision = { allowed: true } | { allowed: false; retryAfterSeconds: number };

/** 決まりごとの今の区切りでの回数（この問い合わせの前まで）から、通すか決める。 */
export function decideRateLimit(
  counts: readonly number[],
  rules: readonly RateLimitRule[],
  nowMs: number,
): RateLimitDecision {
  let retryAfterSeconds = 0;
  rules.forEach((rule, i) => {
    if ((counts[i] ?? 0) >= rule.limit) {
      retryAfterSeconds = Math.max(retryAfterSeconds, windowOf(rule, nowMs).secondsLeft);
    }
  });
  return retryAfterSeconds > 0 ? { allowed: false, retryAfterSeconds } : { allowed: true };
}

/**
 * 接続元の IP を数える単位にする。IPv6 は端末ごとに /64 が割り当てられ、その中でアドレスが変わるので /64 にまとめる。
 * 読めない形はそのまま返す。
 */
export function clientNetwork(ip: string): string {
  if (!ip.includes(':')) return ip;
  const [head, tail] = ip.toLowerCase().split('::');
  const left = head ? head.split(':') : [];
  const right = tail ? tail.split(':') : [];
  const groups = tail === undefined ? left : [...left, ...Array(8 - left.length - right.length).fill('0'), ...right];
  if (groups.length !== 8 || groups.some((g) => !/^[0-9a-f]{1,4}$/.test(g))) return ip;
  return `${groups
    .slice(0, 4)
    .map((g) => g.replace(/^0+(?=.)/, ''))
    .join(':')}::/64`;
}

/** 数える単位の鍵。IP が分からなければ数えない（null）。 */
export function rateLimitKey(ip: string | null, appId: string | undefined): string | null {
  if (!ip) return null;
  return `${appId ?? '-'}|${clientNetwork(ip)}`;
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export interface RateLimitDeps {
  cache: Pick<Cache, 'match' | 'put'>;
  /** 数え直しの書き込みを応答のあとに回す（`waitUntil`）。無ければ待つ。 */
  defer?: (promise: Promise<unknown>) => void;
}

/**
 * Cache API に区切りごとの回数だけをためて数える（データセンターごとのおおよその数。同時の問い合わせは数え漏れうる）。
 * 鍵は SHA-256 にして、IP そのものは残さない。
 */
export async function checkRateLimit(
  deps: RateLimitDeps,
  key: string,
  nowMs = Date.now(),
  rules: readonly RateLimitRule[] = rateLimitRules,
): Promise<RateLimitDecision> {
  const hashed = await sha256Hex(key);
  const entries = rules.map((rule) => {
    const { index, secondsLeft } = windowOf(rule, nowMs);
    return { url: `https://cache.ramen-in-cho.internal/rate-limit/v1/${rule.name}/${index}/${hashed}`, secondsLeft };
  });
  const counts = await Promise.all(
    entries.map(async ({ url }) => {
      const hit = await deps.cache.match(url);
      const count = hit ? Number(await hit.text()) : 0;
      return Number.isFinite(count) ? count : 0;
    }),
  );
  const decision = decideRateLimit(counts, rules, nowMs);
  if (decision.allowed) {
    const write = Promise.all(
      entries.map(({ url, secondsLeft }, i) =>
        deps.cache.put(
          url,
          new Response(String(counts[i] + 1), { headers: { 'cache-control': `public, max-age=${secondsLeft}` } }),
        ),
      ),
    );
    if (deps.defer) deps.defer(write);
    else await write;
  }
  return decision;
}
