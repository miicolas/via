import { importPKCS8, SignJWT } from 'jose';

import { env } from '../env';

const APPLE_AUDIENCE = 'https://appleid.apple.com';
const CLIENT_SECRET_LIFETIME_SECONDS = 180 * 24 * 60 * 60;
const CLIENT_SECRET_RENEWAL_MARGIN_SECONDS = 24 * 60 * 60;

export type AppleClientSecretConfiguration = {
  clientId: string;
  teamId: string;
  keyId: string;
  privateKey: string;
};

/** Apple requires an ES256 JWT in place of a conventional OAuth client secret. */
export async function generateAppleClientSecret(
  configuration: AppleClientSecretConfiguration,
  now = new Date()
): Promise<string> {
  const issuedAt = Math.floor(now.getTime() / 1_000);
  const privateKey = configuration.privateKey.replaceAll('\\n', '\n').trim();
  const key = await importPKCS8(privateKey, 'ES256');

  return new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: configuration.keyId })
    .setIssuer(configuration.teamId)
    .setSubject(configuration.clientId)
    .setAudience(APPLE_AUDIENCE)
    .setIssuedAt(issuedAt)
    .setExpirationTime(issuedAt + CLIENT_SECRET_LIFETIME_SECONDS)
    .sign(key);
}

let cachedSecret: { value: Promise<string>; expiresAtMs: number } | undefined;

/**
 * The env-configured secret, memoized: the JWT is valid for 180 days, so it is
 * regenerated (PKCS8 import + ES256 signature) only when it nears expiry, not
 * on every sign-in or revocation.
 */
export function getAppleClientSecret(now = new Date()): Promise<string> {
  const renewAfterMs = cachedSecret
    ? cachedSecret.expiresAtMs - CLIENT_SECRET_RENEWAL_MARGIN_SECONDS * 1_000
    : 0;
  if (!cachedSecret || now.getTime() >= renewAfterMs) {
    cachedSecret = {
      value: generateAppleClientSecret(
        {
          clientId: env.APPLE_CLIENT_ID,
          teamId: env.APPLE_TEAM_ID,
          keyId: env.APPLE_KEY_ID,
          privateKey: env.APPLE_PRIVATE_KEY,
        },
        now
      ),
      expiresAtMs: now.getTime() + CLIENT_SECRET_LIFETIME_SECONDS * 1_000,
    };
  }
  return cachedSecret.value;
}
