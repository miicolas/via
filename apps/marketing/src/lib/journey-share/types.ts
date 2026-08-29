import type { PublicJourneyShareResponse } from "@via/contract/public";

export type JourneyShareErrorCode =
  | "journey_share_not_found"
  | "journey_share_expired"
  | "journey_share_revoked"
  | "journey_share_unavailable"
  | "unavailable";

export type JourneyShareQueryData =
  | { readonly kind: "ready"; readonly share: PublicJourneyShareResponse }
  | {
      readonly kind: "error";
      readonly code: JourneyShareErrorCode;
      readonly status: number;
    };

export type JourneyShareFetcher = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

export type FetchJourneyShareOptions = {
  readonly signal?: AbortSignal;
  readonly timeoutMs?: number;
  readonly fetcher?: JourneyShareFetcher;
};
