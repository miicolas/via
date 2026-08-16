import { createHash } from "node:crypto";
import { describe, expect, test } from "bun:test";
import { generateKeyPair, SignJWT } from "jose";

import { env } from "../../env";
import {
  exchangeAndRevokeAppleAuthorization,
  verifyFreshAppleIdentityToken,
} from "./apple-revocation";

const issuer = "https://appleid.apple.com";

async function identityToken(
  privateKey: CryptoKey,
  subject: string,
  rawNonce?: string,
) {
  const token = new SignJWT(
    rawNonce
      ? { nonce: createHash("sha256").update(rawNonce).digest("hex") }
      : {},
  )
    .setProtectedHeader({ alg: "RS256", kid: "test" })
    .setIssuer(issuer)
    .setAudience(env.APPLE_APP_BUNDLE_IDENTIFIER)
    .setSubject(subject)
    .setIssuedAt()
    .setExpirationTime("5m");
  return token.sign(privateKey);
}

describe("Apple account revocation", () => {
  test("accepts a signed identity token with the matching SHA-256 nonce", async () => {
    const { privateKey, publicKey } = await generateKeyPair("RS256");
    const token = await identityToken(privateKey, "apple-user", "raw-nonce");

    await expect(
      verifyFreshAppleIdentityToken(token, "raw-nonce", publicKey),
    ).resolves.toBe("apple-user");
  });

  test("rejects an otherwise valid token when the raw nonce differs", async () => {
    const { privateKey, publicKey } = await generateKeyPair("RS256");
    const token = await identityToken(privateKey, "apple-user", "raw-nonce");

    await expect(
      verifyFreshAppleIdentityToken(token, "another-nonce", publicKey),
    ).rejects.toThrow("Invalid Apple identity token nonce or subject");
  });

  test("exchanges the one-time code and revokes the refresh token", async () => {
    const { privateKey, publicKey } = await generateKeyPair("RS256");
    const exchangedIdentityToken = await identityToken(
      privateKey,
      "apple-user",
    );
    const requests: Array<{ url: string; parameters: URLSearchParams }> = [];
    const responses = [
      Response.json({
        id_token: exchangedIdentityToken,
        refresh_token: "apple-refresh-token",
      }),
      new Response(null, { status: 200 }),
    ];
    const fetchImplementation = Object.assign(
      async (input: string | URL | Request, init?: RequestInit) => {
        requests.push({
          url: input.toString(),
          parameters: new URLSearchParams(init?.body?.toString()),
        });
        return responses.shift()!;
      },
      { preconnect() {} },
    ) as typeof fetch;

    await exchangeAndRevokeAppleAuthorization("one-time-code", "apple-user", {
      fetchImplementation,
      identityTokenKey: publicKey,
      generateClientSecret: async () => "client-secret",
    });

    expect(requests.map((request) => request.url)).toEqual([
      `${issuer}/auth/token`,
      `${issuer}/auth/revoke`,
    ]);
    expect(requests[0]?.parameters.get("code")).toBe("one-time-code");
    expect(requests[1]?.parameters.get("token")).toBe("apple-refresh-token");
    expect(requests[1]?.parameters.get("token_type_hint")).toBe(
      "refresh_token",
    );
  });

  test("stops before revocation when the code belongs to another Apple user", async () => {
    const { privateKey, publicKey } = await generateKeyPair("RS256");
    const exchangedIdentityToken = await identityToken(
      privateKey,
      "another-user",
    );
    let requestCount = 0;
    const fetchImplementation = Object.assign(
      async () => {
        requestCount += 1;
        return Response.json({
          id_token: exchangedIdentityToken,
          refresh_token: "apple-refresh-token",
        });
      },
      { preconnect() {} },
    ) as typeof fetch;

    await expect(
      exchangeAndRevokeAppleAuthorization("one-time-code", "apple-user", {
        fetchImplementation,
        identityTokenKey: publicKey,
        generateClientSecret: async () => "client-secret",
      }),
    ).rejects.toThrow("Apple authorization code belongs to another account");
    expect(requestCount).toBe(1);
  });
});
