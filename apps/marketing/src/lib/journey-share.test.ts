import { afterEach, beforeEach, expect, test } from "bun:test";

import {
  publicJourneyShareResponseSchema,
  type PublicJourneyShareResponse,
} from "@via/contract/public";

import {
  fetchJourneyShare,
  journeyShareQueryOptions,
  type JourneyShareFetcher,
} from "./journey-share";

const token = "A".repeat(43);
const fixture = {
  snapshot: {
    schemaVersion: 1,
    generatedAt: "2026-08-29T10:00:00+02:00",
    locale: "fr-FR",
    timeZone: "Europe/Paris",
    journey: {
      durationSeconds: 1_800,
      walkingDurationSeconds: 240,
      transferCount: 1,
      departureAt: "2026-08-29T10:05:00+02:00",
      arrivalAt: "2026-08-29T10:35:00+02:00",
      status: "normal",
      warnings: [],
      sections: [
        {
          type: "walk",
          durationSeconds: 240,
          from: {
            name: "Départ",
            coordinate: { latitude: 48.85, longitude: 2.35 },
          },
          to: {
            name: "Châtelet",
            coordinate: { latitude: 48.858, longitude: 2.347 },
          },
          geometry: [
            { latitude: 48.85, longitude: 2.35 },
            { latitude: 48.858, longitude: 2.347 },
          ],
        },
      ],
    },
  },
  expiresAt: "2026-09-28T10:00:00+02:00",
} satisfies PublicJourneyShareResponse;

const originalApiUrl = process.env.NEXT_PUBLIC_API_URL;
const originalClientKey = process.env.VIA_SITE_CLIENT_KEY;

beforeEach(() => {
  process.env.NEXT_PUBLIC_API_URL = "https://api.example.test";
  delete process.env.VIA_SITE_CLIENT_KEY;
});

afterEach(() => {
  if (originalApiUrl === undefined) delete process.env.NEXT_PUBLIC_API_URL;
  else process.env.NEXT_PUBLIC_API_URL = originalApiUrl;
  if (originalClientKey === undefined) delete process.env.VIA_SITE_CLIENT_KEY;
  else process.env.VIA_SITE_CLIENT_KEY = originalClientKey;
});

function neverResolvingFetch(
  onSignal: (signal: AbortSignal) => void,
): JourneyShareFetcher {
  return async (_input, init) => {
    const signal = init?.signal;
    if (!(signal instanceof AbortSignal)) throw new Error("missing signal");
    onSignal(signal);
    if (signal.aborted) return Promise.reject(signal.reason);
    return new Promise<Response>((_resolve, reject) => {
      signal.addEventListener("abort", () => reject(signal.reason), {
        once: true,
      });
    });
  };
}

test("times out a stalled request with a generic message", async () => {
  const started = Promise.resolve();
  await started;
  const start = performance.now();
  await expect(
    fetchJourneyShare(token, {
      timeoutMs: 10,
      fetcher: neverResolvingFetch(() => undefined),
    }),
  ).rejects.toThrow("Journey share request failed.");
  expect(performance.now() - start).toBeLessThan(500);
});

test("does not start the network for an already-aborted caller signal", async () => {
  const controller = new AbortController();
  const reason = new DOMException("caller cancelled", "AbortError");
  controller.abort(reason);
  let called = false;

  await expect(
    fetchJourneyShare(token, {
      signal: controller.signal,
      fetcher: async () => {
        called = true;
        return new Response();
      },
    }),
  ).rejects.toBe(reason);
  expect(called).toBe(false);
});

test("preserves a caller cancellation during a request", async () => {
  const controller = new AbortController();
  const reason = new DOMException("left page", "AbortError");
  const observed = new Promise<void>((resolve) => {
    void fetchJourneyShare(token, {
      signal: controller.signal,
      timeoutMs: 1_000,
      fetcher: neverResolvingFetch((signal) => {
        signal.addEventListener("abort", () => resolve(), { once: true });
      }),
    }).catch((error) => {
      expect(error).toBe(reason);
    });
  });
  controller.abort(reason);
  await observed;
});

test("parses a conforming public response", async () => {
  const result = await fetchJourneyShare(token, {
    fetcher: async () => new Response(JSON.stringify(fixture), { status: 200 }),
  });
  expect(result).toEqual({ kind: "ready", share: fixture });
  expect(publicJourneyShareResponseSchema.safeParse(fixture).success).toBe(
    true,
  );
});

test("keeps known HTTP errors as data and unknown bodies unavailable", async () => {
  const known = await fetchJourneyShare(token, {
    fetcher: async () =>
      new Response(
        JSON.stringify({ error: { code: "journey_share_expired" } }),
        { status: 410 },
      ),
  });
  expect(known).toEqual({
    kind: "error",
    code: "journey_share_expired",
    status: 410,
  });

  const unknown = await fetchJourneyShare(token, {
    fetcher: async () => new Response("not-json", { status: 503 }),
  });
  expect(unknown).toEqual({ kind: "error", code: "unavailable", status: 503 });
});

test("query options pass TanStack Query cancellation through unchanged", async () => {
  const controller = new AbortController();
  const reason = new DOMException("query cancelled", "AbortError");
  controller.abort(reason);

  await expect(
    journeyShareQueryOptions(token).queryFn({ signal: controller.signal }),
  ).rejects.toBe(reason);
});

test("server requests retain the site key boundary and revalidation", async () => {
  process.env.VIA_SITE_CLIENT_KEY = "local-test-key";
  let requestInit: RequestInit | undefined;
  const result = await fetchJourneyShare(token, {
    fetcher: async (_input, init) => {
      requestInit = init;
      return new Response(JSON.stringify(fixture), { status: 200 });
    },
  });

  expect(result.kind).toBe("ready");
  expect(requestInit?.headers).toEqual({
    "x-via-client-key": "local-test-key",
  });
  expect(requestInit?.signal).toBeInstanceOf(AbortSignal);
  expect(
    (requestInit as RequestInit & { next?: { revalidate: number } }).next,
  ).toEqual({
    revalidate: 60,
  });
});
