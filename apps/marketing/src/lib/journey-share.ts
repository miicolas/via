import {
  journeyShareResponseSchema,
  type JourneyShareResponse,
} from "@via/contract";
import { apiOrigin, serverHeaders } from "@/lib/api";

export const journeyShareQueryKey = (token: string) =>
  ["journey-share", token] as const;

export type JourneyShareErrorCode =
  | "journey_share_not_found"
  | "journey_share_expired"
  | "journey_share_revoked"
  | "journey_share_unavailable"
  | "unavailable";

export type JourneyShareQueryData =
  | { readonly kind: "ready"; readonly share: JourneyShareResponse }
  | {
      readonly kind: "error";
      readonly code: JourneyShareErrorCode;
      readonly status: number;
    };

function knownErrorCode(value: unknown): JourneyShareErrorCode {
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
}

/**
 * Server and browser use the same query function. The server sends the private
 * site key and gets cacheable HTML; the browser relies on its Metyro origin and
 * never receives that key.
 */
export async function fetchJourneyShare(
  token: string,
): Promise<JourneyShareQueryData> {
  const origin = apiOrigin();
  if (!origin) return { kind: "error", code: "unavailable", status: 0 };

  const init: RequestInit & { next?: { revalidate: number } } = {
    headers: serverHeaders(),
  };
  if (typeof window === "undefined") {
    init.next = { revalidate: 60 };
  } else {
    init.cache = "no-store";
  }

  let response: Response;
  try {
    response = await fetch(
      `${origin}/public/journey-shares/${encodeURIComponent(token)}`,
      init,
    );
  } catch {
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

  const parsed = journeyShareResponseSchema.safeParse(await response.json());
  if (!parsed.success) throw new Error("Journey share response is invalid.");
  return { kind: "ready", share: parsed.data };
}

export function journeyShareQueryOptions(token: string) {
  return {
    queryKey: journeyShareQueryKey(token),
    queryFn: () => fetchJourneyShare(token),
    staleTime: 60_000,
    refetchOnWindowFocus: false,
    retry: 1,
  } as const;
}

/**
 * Une seule écriture de la durée, parce que l’aperçu du lien et la page qu’il
 * ouvre doivent annoncer le même trajet : la métadonnée est rendue sur le
 * serveur, la puce dans le client, et deux copies finiraient par se contredire.
 */
export function formatDuration(seconds: number): string {
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const remaining = minutes % 60;
  return remaining === 0 ? `${hours} h` : `${hours} h ${remaining}`;
}

export function journeyEndpoints(share: JourneyShareResponse): {
  readonly origin: JourneyShareResponse["snapshot"]["journey"]["sections"][number]["from"];
  readonly destination: JourneyShareResponse["snapshot"]["journey"]["sections"][number]["to"];
} {
  const sections = share.snapshot.journey.sections;
  return {
    origin: sections[0]?.from ?? {
      name: "Départ",
      coordinate: { latitude: 0, longitude: 0 },
    },
    destination: sections[sections.length - 1]?.to ?? {
      name: "Arrivée",
      coordinate: { latitude: 0, longitude: 0 },
    },
  };
}
