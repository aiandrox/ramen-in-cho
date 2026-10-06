import { type JWTVerifyGetKey, createRemoteJWKSet, jwtVerify } from 'jose';

/** Firebase プロジェクト ramen-in-cho のプロジェクト番号。 */
export const firebaseProjectNumber = '452252955491';

const firebaseJwks = createRemoteJWKSet(new URL('https://firebaseappcheck.googleapis.com/v1/jwks'));

export type AppCheckResult = 'ok' | 'missing' | 'invalid';

/** [appId] はトークンの sub（Firebase のアプリ ID。端末ごとではなく iOS・Android のアプリごと）。 */
export interface AppCheck {
  result: AppCheckResult;
  appId?: string;
}

/** `X-Firebase-AppCheck` のトークンが、このプロジェクトのアプリが発行したものか確かめる。 */
export async function verifyAppCheck(
  token: string | null,
  keys: JWTVerifyGetKey = firebaseJwks,
  projectNumber = firebaseProjectNumber,
): Promise<AppCheck> {
  if (!token) return { result: 'missing' };
  try {
    const { payload } = await jwtVerify(token, keys, {
      algorithms: ['RS256'],
      typ: 'JWT',
      issuer: `https://firebaseappcheck.googleapis.com/${projectNumber}`,
      audience: `projects/${projectNumber}`,
    });
    return { result: 'ok', appId: payload.sub };
  } catch {
    return { result: 'invalid' };
  }
}
