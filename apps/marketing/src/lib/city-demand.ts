import { apiOrigin, readJson } from "@/lib/api";

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

const ENDPOINT = "/public/city-demand";

/**
 * Read on the server so the counts are in the HTML, and never allowed to fail
 * the page: a poll that is down costs the section its numbers, not its map.
 */
export async function fetchCityDemand(): Promise<CityDemandBoard | null> {
  return readJson<CityDemandBoard>(ENDPOINT, 30);
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
