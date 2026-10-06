import { verifyAppCheck } from '../../src/app-check.ts';
import { type Env, json } from '../../src/http.ts';
import { checkRateLimit, rateLimitKey } from '../../src/rate-limit.ts';

/** アプリ以外からの呼び出しを見分け、1台あたりの回数を制限する。`APP_CHECK_ENFORCE` が "true" でなければ App Check は記録だけ。 */
export const onRequest: PagesFunction<Env> = async (context) => {
  const { request, env, next } = context;
  const { result, appId } = await verifyAppCheck(request.headers.get('x-firebase-appcheck'));
  if (result !== 'ok') {
    console.log(`app check: ${result}`);
    if (env.APP_CHECK_ENFORCE === 'true') return json({ error: 'アプリからの問い合わせではありません' }, { status: 401 });
  }
  const key = rateLimitKey(request.headers.get('cf-connecting-ip'), appId);
  if (key) {
    const decision = await checkRateLimit({ cache: caches.default, defer: (p) => context.waitUntil(p) }, key);
    if (!decision.allowed) {
      console.log('rate limited');
      return json(
        { error: '問い合わせが多すぎます。しばらくしてからもう一度お試しください' },
        { status: 429, headers: { 'retry-after': String(decision.retryAfterSeconds) } },
      );
    }
  }
  return next();
};
