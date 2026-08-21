import { exportPKCS8, generateKeyPair } from "jose";
import { expect, test } from "bun:test";

import {
  APNsError,
  type APNsFetcher,
  type APNsRequestInit,
  createAPNsProvider,
} from "./apns";

test("APNs provider targets the token environment and signs a reusable bearer token", async () => {
  const keyPair = await generateKeyPair("ES256", { extractable: true });
  const signingKey = await exportPKCS8(keyPair.privateKey);
  const requests: Array<{ url: string; init: APNsRequestInit | undefined }> =
    [];
  const fetcher: APNsFetcher = async (input, init) => {
    requests.push({ url: String(input), init });
    return new Response(null, {
      status: 200,
      headers: { "apns-id": "response-id" },
    });
  };
  const provider = createAPNsProvider({
    teamId: "TEAM123",
    keyId: "KEY123",
    privateKey: signingKey,
    fetcher,
    now: () => new Date("2026-08-21T12:00:00Z"),
  });

  await provider.send({
    token: "aa".repeat(32),
    bundleId: "dev.via.app",
    environment: "sandbox",
    pushType: "alert",
    priority: 10,
    expirationAt: new Date("2026-08-21T13:00:00Z"),
    payload: { aps: { alert: { title: "Via", body: "Test" } } },
  });
  await provider.send({
    token: "bb".repeat(32),
    bundleId: "dev.via.app",
    environment: "production",
    pushType: "alert",
    priority: 10,
    payload: { aps: { alert: { title: "Via", body: "Production" } } },
  });

  expect(requests).toHaveLength(2);
  expect(requests[0].url).toBe(
    `https://api.sandbox.push.apple.com/3/device/${"aa".repeat(32)}`,
  );
  expect(requests[0].init?.headers).toMatchObject({
    "apns-topic": "dev.via.app",
    "apns-push-type": "alert",
    "apns-priority": "10",
    "apns-expiration": String(
      Math.floor(Date.parse("2026-08-21T13:00:00Z") / 1_000),
    ),
  });
  expect(requests[0].init?.protocol).toBe("http2");
  expect(requests[0].init?.signal).toBeInstanceOf(AbortSignal);
  expect(requests[1].url).toBe(
    `https://api.push.apple.com/3/device/${"bb".repeat(32)}`,
  );
  expect(requests[1].init?.headers).toMatchObject({
    "apns-topic": "dev.via.app",
    "apns-push-type": "alert",
    "apns-priority": "10",
  });
  expect(
    (requests[0].init?.headers as Record<string, string>).authorization,
  ).toBe((requests[1].init?.headers as Record<string, string>).authorization);
});

test("concurrent cold sends share one provider token generation", async () => {
  const keyPair = await generateKeyPair("ES256", { extractable: true });
  const signingKey = await exportPKCS8(keyPair.privateKey);
  const authorizations: string[] = [];
  const provider = createAPNsProvider({
    teamId: "TEAM123",
    keyId: "KEY123",
    privateKey: signingKey,
    fetcher: async (_input, init) => {
      authorizations.push(
        (init?.headers as Record<string, string>).authorization,
      );
      return new Response(null, { status: 200 });
    },
    now: () => new Date("2026-08-21T12:00:00Z"),
  });

  await Promise.all(
    Array.from({ length: 10 }, (_, index) =>
      provider.send({
        token: String(index).padStart(64, "a"),
        bundleId: "dev.via.app",
        environment: "production",
        pushType: "alert",
        priority: 10,
        payload: { aps: {} },
      }),
    ),
  );

  expect(new Set(authorizations).size).toBe(1);
});

test("concurrent expired-token responses share one refreshed provider token", async () => {
  const keyPair = await generateKeyPair("ES256", { extractable: true });
  const signingKey = await exportPKCS8(keyPair.privateKey);
  const authorizations: string[] = [];
  let expiredAuthorization: string | undefined;
  const provider = createAPNsProvider({
    teamId: "TEAM123",
    keyId: "KEY123",
    privateKey: signingKey,
    fetcher: async (_input, init) => {
      const authorization = (init?.headers as Record<string, string>)
        .authorization;
      authorizations.push(authorization);
      expiredAuthorization ??= authorization;
      if (authorization === expiredAuthorization) {
        return new Response(
          JSON.stringify({ reason: "ExpiredProviderToken" }),
          { status: 403 },
        );
      }
      return new Response(null, { status: 200 });
    },
    now: () => new Date("2026-08-21T12:00:00Z"),
  });

  await Promise.all(
    Array.from({ length: 10 }, (_, index) =>
      provider.send({
        token: String(index).padStart(64, "a"),
        bundleId: "dev.via.app",
        environment: "production",
        pushType: "alert",
        priority: 10,
        payload: { aps: {} },
      }),
    ),
  );

  expect(authorizations).toHaveLength(20);
  expect(new Set(authorizations).size).toBe(2);
});

test("APNs errors preserve the reason and identify invalid tokens", async () => {
  const keyPair = await generateKeyPair("ES256", { extractable: true });
  const signingKey = await exportPKCS8(keyPair.privateKey);
  const provider = createAPNsProvider({
    teamId: "TEAM123",
    keyId: "KEY123",
    privateKey: signingKey,
    fetcher: async () =>
      new Response(
        JSON.stringify({
          reason: "Unregistered",
          timestamp: Date.parse("2026-08-21T11:59:00Z"),
        }),
        {
          status: 410,
          headers: { "apns-id": "gone-id" },
        },
      ),
  });

  await expect(
    provider.send({
      token: "cc".repeat(32),
      bundleId: "dev.via.app",
      environment: "production",
      pushType: "alert",
      priority: 10,
      payload: { aps: {} },
    }),
  ).rejects.toBeInstanceOf(APNsError);

  try {
    await provider.send({
      token: "cc".repeat(32),
      bundleId: "dev.via.app",
      environment: "production",
      pushType: "alert",
      priority: 10,
      payload: { aps: {} },
    });
  } catch (error) {
    expect(error).toMatchObject({
      statusCode: 410,
      reason: "Unregistered",
      apnsId: "gone-id",
      invalidatedAt: new Date("2026-08-21T11:59:00Z"),
    });
    expect((error as APNsError).isInvalidToken).toBe(true);
  }
});

test("APNs failure classification distinguishes device throttling from global failures", () => {
  const cases = [
    {
      error: new APNsError(429, "TooManyRequests", null),
      retryable: true,
      scope: "device",
    },
    {
      error: new APNsError(429, "TooManyProviderTokenUpdates", null),
      retryable: true,
      scope: "global",
    },
    {
      error: new APNsError(400, "IdleTimeout", null),
      retryable: true,
      scope: "global",
    },
    {
      error: new APNsError(400, "BadCollapseId", null),
      retryable: false,
      scope: "global",
    },
    {
      error: new APNsError(410, "Unregistered", null),
      retryable: false,
      scope: "device",
    },
    {
      error: new APNsError(404, "BadPath", null),
      retryable: false,
      scope: "global",
    },
  ] as const;

  for (const item of cases) {
    expect(item.error.isRetryable).toBe(item.retryable);
    expect(item.error.failureScope).toBe(item.scope);
  }
});

test("expired device tokens are eligible for conditional cleanup", () => {
  expect(new APNsError(400, "ExpiredToken", null).isInvalidToken).toBe(true);
});
