import { SignJWT, createLocalJWKSet, exportJWK, generateKeyPair } from 'jose';
import { describe, expect, it } from 'vitest';

import { verifyAppCheck } from '../src/app-check.ts';

const project = '123';
const { privateKey, publicKey } = await generateKeyPair('RS256');
const keys = createLocalJWKSet({ keys: [{ ...(await exportJWK(publicKey)), kid: 'k', alg: 'RS256' }] });

const sign = (claims: { iss?: string; aud?: string[]; expiresIn?: string } = {}) =>
  new SignJWT({})
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT', kid: 'k' })
    .setIssuer(claims.iss ?? `https://firebaseappcheck.googleapis.com/${project}`)
    .setAudience(claims.aud ?? [`projects/${project}`, `projects/ramen-in-cho`])
    .setSubject('1:123:android:abc')
    .setIssuedAt()
    .setExpirationTime(claims.expiresIn ?? '1h')
    .sign(privateKey);

describe('verifyAppCheck', () => {
  it('このプロジェクトのトークンなら通す', async () => {
    expect(await verifyAppCheck(await sign(), keys, project)).toEqual({ result: 'ok', appId: '1:123:android:abc' });
  });

  it('トークンが無ければ missing', async () => {
    expect(await verifyAppCheck(null, keys, project)).toEqual({ result: 'missing' });
  });

  it('別のプロジェクト・期限切れ・壊れたトークンは invalid', async () => {
    expect(await verifyAppCheck(await sign({ iss: 'https://firebaseappcheck.googleapis.com/999' }), keys, project)).toEqual({ result: 'invalid' });
    expect(await verifyAppCheck(await sign({ aud: ['projects/999'] }), keys, project)).toEqual({ result: 'invalid' });
    expect(await verifyAppCheck(await sign({ expiresIn: '-1m' }), keys, project)).toEqual({ result: 'invalid' });
    expect(await verifyAppCheck('not.a.jwt', keys, project)).toEqual({ result: 'invalid' });
  });
});
