/**
 * The coverage poll, as the site sees it: counts and ranks keyed by slug, and
 * nothing else. The names and coordinates stay in `@/constants/cities` so the
 * map still draws when this request fails.
 */
export interface CityDemand {
  readonly slug: string;
  readonly votes: number;
  /** `null` while nobody has asked for the city yet. */
  readonly rank: number | null;
}

export interface CityDemandBoard {
  readonly cities: readonly CityDemand[];
  readonly totalVotes: number;
}

export interface CityVoteResult extends CityDemandBoard {
  /** `duplicate` when this visitor had already backed the city. */
  readonly outcome: "recorded" | "duplicate";
  readonly city: CityDemand | null;
}

export class CityVoteError extends Error {
  constructor(readonly status: number) {
    super(`The vote was refused with ${status}.`);
    this.name = "CityVoteError";
  }
}

/**
 * `NEXT_PUBLIC_` because the vote is sent by the browser and must be: proxying
 * it through a route handler would hand every vote the same server address, and
 * the API counts one voice per address.
 *
 * Unset in production the poll simply does not run — a missing variable turns
 * the map read-only rather than pointing a live site at localhost.
 */
function apiOrigin(): string | null {
  const configured = process.env.NEXT_PUBLIC_API_URL?.trim().replace(/\/+$/, "");
  if (configured) return configured;
  return process.env.NODE_ENV === "production" ? null : "http://localhost:3000";
}

const ENDPOINT = "/public/city-demand";

/**
 * The API answers the site and the app, nobody else. From the browser that is
 * settled by the `Origin` header, which no page can forge for another. Server
 * side there is no origin to send, so the render presents the shared key
 * instead — deliberately without `NEXT_PUBLIC_`, so it never reaches a bundle.
 */
function serverHeaders(): HeadersInit {
  const key = process.env.VIA_SITE_CLIENT_KEY?.trim();
  return key ? { "x-via-client-key": key } : {};
}

/**
 * Read on the server so the counts are in the HTML, and never allowed to fail
 * the page: a poll that is down costs the section its numbers, not its map.
 */
export async function fetchCityDemand(): Promise<CityDemandBoard | null> {
  const origin = apiOrigin();
  if (!origin) return null;

  try {
    const response = await fetch(`${origin}${ENDPOINT}`, {
      headers: serverHeaders(),
      next: { revalidate: 30 },
    });
    if (!response.ok) return null;
    return (await response.json()) as CityDemandBoard;
  } catch {
    return null;
  }
}

export async function submitCityVote(slug: string): Promise<CityVoteResult> {
  const origin = apiOrigin();
  if (!origin) throw new CityVoteError(0);

  const response = await fetch(`${origin}${ENDPOINT}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ city: slug }),
  });

  if (!response.ok) throw new CityVoteError(response.status);
  return (await response.json()) as CityVoteResult;
}
