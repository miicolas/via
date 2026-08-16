import { describe, expect, test } from 'bun:test';
import { decodeJwt, decodeProtectedHeader, exportPKCS8, generateKeyPair } from 'jose';

import { generateAppleClientSecret } from './apple-client-secret';

describe('generateAppleClientSecret', () => {
  test('creates the ES256 client-secret claims Apple requires', async () => {
    const { privateKey } = await generateKeyPair('ES256', { extractable: true });
    const pem = await exportPKCS8(privateKey);
    const now = new Date('2026-08-16T12:00:00.000Z');

    const token = await generateAppleClientSecret(
      {
        clientId: 'dev.via.app',
        teamId: 'HZAYG4Q47N',
        keyId: 'TESTKEY123',
        privateKey: pem,
      },
      now
    );

    expect(decodeProtectedHeader(token)).toMatchObject({ alg: 'ES256', kid: 'TESTKEY123' });
    expect(decodeJwt(token)).toMatchObject({
      aud: 'https://appleid.apple.com',
      iss: 'HZAYG4Q47N',
      sub: 'dev.via.app',
      iat: Math.floor(now.getTime() / 1_000),
    });
    expect(decodeJwt(token).exp! - decodeJwt(token).iat!).toBe(180 * 24 * 60 * 60);
  });

  test('accepts deployment secrets containing escaped newlines', async () => {
    const { privateKey } = await generateKeyPair('ES256', { extractable: true });
    const escaped = (await exportPKCS8(privateKey)).replaceAll('\n', '\\n');

    const token = await generateAppleClientSecret({
      clientId: 'dev.via.app',
      teamId: 'HZAYG4Q47N',
      keyId: 'TESTKEY123',
      privateKey: escaped,
    });

    expect(token.split('.')).toHaveLength(3);
  });
});
