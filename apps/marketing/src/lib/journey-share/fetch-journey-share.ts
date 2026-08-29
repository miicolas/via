import { publicJourneyShareResponseSchema } from "@via/contract/public";

import { apiOrigin, boundedApiSignal, serverHeaders } from "@/lib/api";
import type {
  FetchJourneyShareOptions,
  JourneyShareErrorCode,
  JourneyShareQueryData,
} from "./types";

const abortReason = (signal: AbortSignal): unknown => {
  if (signal.reason !== undefined) return signal.reason;
  if (typeof DOMException !== "undefined") {
    return new DOMException("The operation was aborted.", "AbortError");
  }
  return new Error("The operation was aborted.");
};

const knownErrorCode = (value: unknown): JourneyShareErrorCode => {
  if (!value || typeof value !== "object") return "unavailable";
  const error = (value as { error?: unknown }).error;
  if (!error || typeof error !== "object") return "unavailable";
  const code = (error as { code?: unknown }).code;
  switch (code) {
    case "journey_share_not_found":
    case "journey_share_expired":
    case "journey_share_revoked":
    case "journey_share_unavailable":
      return code;
    default:
      return "unavailable";
  }
};

/** Fetches and validates the public journey snapshot for server and browser. */
export async function fetchJourneyShare(
  token: string,
  options: FetchJourneyShareOptions = {},
): Promise<JourneyShareQueryData> {
  const origin = apiOrigin();
  if (!origin) return { kind: "error", code: "unavailable", status: 0 };

  if (options.signal?.aborted) throw abortReason(options.signal);

  const init: RequestInit & { next?: { revalidate: number } } = {
    headers: serverHeaders(),
    signal: boundedApiSignal(options.signal, options.timeoutMs),
  };
  if (typeof window === "undefined") {
    init.next = { revalidate: 60 };
  } else {
    init.cache = "no-store";
  }

  let response: Response;
  try {
    const fetcher = options.fetcher ?? fetch;
    response = await fetcher(
      `${origin}/public/journey-shares/${encodeURIComponent(token)}`,
      init,
    );
  } catch {
    if (options.signal?.aborted) throw abortReason(options.signal);
    throw new Error("Journey share request failed.");
  }

  if (!response.ok) {
    const body = await response.json().catch(() => null);
    return {
      kind: "error",
      code: knownErrorCode(body),
      status: response.status,
    };
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    throw new Error("Journey share response is invalid.");
  }
  const parsed = publicJourneyShareResponseSchema.safeParse(body);
  if (!parsed.success) throw new Error("Journey share response is invalid.");
  return { kind: "ready", share: parsed.data };
}
