import { createHash } from "node:crypto";
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";

import { env } from "../../env";
import { getAppleClientSecret } from "../../auth/apple-client-secret";

const APPLE_ISSUER = "https://appleid.apple.com";
const appleKeys = createRemoteJWKSet(new URL(`${APPLE_ISSUER}/auth/keys`));
const APPLE_ID_TOKEN_VERIFY_OPTIONS = {
  algorithms: ["RS256"],
  issuer: APPLE_ISSUER,
  audience: env.APPLE_APP_BUNDLE_IDENTIFIER,
  maxTokenAge: "10m",
};

type AppleTokenResponse = {
  access_token?: string;
  refresh_token?: string;
  id_token?: string;
};

type AppleVerificationKey = Parameters<typeof jwtVerify>[1] | JWTVerifyGetKey;

type AppleRevocationDependencies = {
  fetchImplementation?: typeof fetch;
  identityTokenKey?: AppleVerificationKey;
  generateClientSecret?: () => Promise<string>;
};

export async function verifyFreshAppleIdentityToken(
  identityToken: string,
  rawNonce: string,
  verificationKey: AppleVerificationKey = appleKeys,
): Promise<string> {
  const { payload } = await jwtVerify(
    identityToken,
    verificationKey,
    APPLE_ID_TOKEN_VERIFY_OPTIONS,
  );
  const expectedNonce = createHash("sha256").update(rawNonce).digest("hex");
  if (payload.nonce !== expectedNonce || typeof payload.sub !== "string") {
    throw new Error("Invalid Apple identity token nonce or subject");
  }
  return payload.sub;
}

export async function exchangeAndRevokeAppleAuthorization(
  authorizationCode: string,
  expectedSubject: string,
  dependencies: AppleRevocationDependencies = {},
): Promise<void> {
  const fetchImplementation = dependencies.fetchImplementation ?? fetch;
  const clientSecret = await (dependencies.generateClientSecret?.() ??
    getAppleClientSecret());
  const sharedParameters = {
    client_id: env.APPLE_CLIENT_ID,
    client_secret: clientSecret,
  };
  const tokenResponse = await fetchImplementation(
    `${APPLE_ISSUER}/auth/token`,
    {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        ...sharedParameters,
        grant_type: "authorization_code",
        code: authorizationCode,
      }),
      signal: AbortSignal.timeout(10_000),
    },
  );
  if (!tokenResponse.ok)
    throw new Error(`Apple token exchange failed (${tokenResponse.status})`);

  const tokens = (await tokenResponse.json()) as AppleTokenResponse;
  if (!tokens.id_token)
    throw new Error("Apple token exchange did not return an identity token");
  const exchangedIdentity = await jwtVerify(
    tokens.id_token,
    dependencies.identityTokenKey ?? appleKeys,
    APPLE_ID_TOKEN_VERIFY_OPTIONS,
  );
  if (exchangedIdentity.payload.sub !== expectedSubject) {
    throw new Error("Apple authorization code belongs to another account");
  }

  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token)
    throw new Error("Apple token exchange returned no revocable token");
  const revokeResponse = await fetchImplementation(
    `${APPLE_ISSUER}/auth/revoke`,
    {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        ...sharedParameters,
        token,
        token_type_hint: tokens.refresh_token
          ? "refresh_token"
          : "access_token",
      }),
      signal: AbortSignal.timeout(10_000),
    },
  );
  if (!revokeResponse.ok)
    throw new Error(`Apple token revocation failed (${revokeResponse.status})`);
}
