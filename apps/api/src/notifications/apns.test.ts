import { exportPKCS8, generateKeyPair } from "jose";
import { expect, test } from "bun:test";

import {
  APNsError,
  type APNsFetcher,
  type APNsRequestInit,
  createAPNsProvider,
  liveActivityPayload,
  swiftReferenceDateSeconds,
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
    payload: { aps: { alert: { title: "Via", body: "Test" } } },
  });
  await provider.send({
    token: "bb".repeat(32),
    bundleId: "dev.via.app",
    environment: "sandbox",
    pushType: "liveactivity",
    priority: 5,
    payload: { aps: { timestamp: 1, event: "update" } },
  });

  expect(requests).toHaveLength(2);
  expect(requests[0].url).toBe(
    `https://api.sandbox.push.apple.com/3/device/${"aa".repeat(32)}`,
  );
  expect(requests[0].init?.headers).toMatchObject({
    "apns-topic": "dev.via.app",
    "apns-push-type": "alert",
    "apns-priority": "10",
  });
  expect(requests[0].init?.protocol).toBe("http2");
  expect(requests[1].init?.headers).toMatchObject({
    "apns-topic": "dev.via.app.push-type.liveactivity",
    "apns-push-type": "liveactivity",
    "apns-priority": "5",
  });
  expect(
    (requests[0].init?.headers as Record<string, string>).authorization,
  ).toBe((requests[1].init?.headers as Record<string, string>).authorization);
});

test("APNs errors preserve the reason and identify invalid tokens", async () => {
  const keyPair = await generateKeyPair("ES256", { extractable: true });
  const signingKey = await exportPKCS8(keyPair.privateKey);
  const provider = createAPNsProvider({
    teamId: "TEAM123",
    keyId: "KEY123",
    privateKey: signingKey,
    fetcher: async () =>
      new Response(JSON.stringify({ reason: "Unregistered" }), {
        status: 410,
        headers: { "apns-id": "gone-id" },
      }),
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
    });
    expect((error as APNsError).isInvalidToken).toBe(true);
  }
});

test("Live Activity payload uses Swift Date encoding and required APNs fields", () => {
  const arrivalAt = new Date("2026-08-21T12:30:00Z");
  const payload = liveActivityPayload({
    event: "end",
    now: new Date("2026-08-21T12:00:00Z"),
    dismissalDate: new Date("2026-08-21T13:00:00Z"),
    contentState: {
      phaseTitle: "En route",
      instructionTitle: "Nation",
      arrivalAt,
      isOffline: false,
      isArrived: false,
      progressFraction: 0.5,
    },
  });

  const aps = payload.aps as Record<string, unknown>;
  expect(aps.timestamp).toBe(
    Math.floor(new Date("2026-08-21T12:00:00Z").getTime() / 1000),
  );
  expect(aps.event).toBe("end");
  expect(aps["dismissal-date"]).toBe(
    Math.floor(new Date("2026-08-21T13:00:00Z").getTime() / 1000),
  );
  expect((aps["content-state"] as Record<string, unknown>).arrivalAt).toBe(
    swiftReferenceDateSeconds(arrivalAt),
  );
});

test("Live Activity start payload includes attributes", () => {
  const payload = liveActivityPayload({
    event: "start",
    attributes: { journeyID: "journey-1" },
    contentState: {
      phaseTitle: "Départ",
      instructionTitle: "Châtelet",
      arrivalAt: 800_000_000,
      isOffline: false,
      isArrived: false,
      progressFraction: 0,
    },
  });

  expect(payload.aps).toMatchObject({
    event: "start",
    "attributes-type": "JourneyActivityAttributes",
    attributes: { journeyID: "journey-1" },
  });
});
