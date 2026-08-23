import { type Context, Hono } from 'hono';
import { z } from 'zod';

import { env } from '../../env';
import type { AppEnv } from '../../http/app-env';
import type { ErrorBody } from '../../http/errors';
import { requestIPHash } from '../../http/ip-identity';
import { redis } from '../../redis';
import { isVotableCity } from './catalogue';
import { rankCities } from './ranking';
import { withinCityVoteQuota } from './rate-limiter';
import { createDatabaseCityDemandRepository, type CityDemandRepository } from './repository';

const voteBody = z.object({ city: z.string().min(1).max(64) });

/**
 * The demand poll behind the marketing site's coverage map. It sits outside the
 * oRPC contract on purpose: the contract is the agreement with the iOS app, and
 * nothing here is ever called from it. It is also the API's only unauthenticated
 * write, which is why the visitor is never trusted for anything but their choice
 * of city — the slug is checked against the catalogue and the identity is an
 * HMAC the server derives itself.
 */
export function createCityDemandRouter(
  repository: CityDemandRepository = createDatabaseCityDemandRepository()
) {
  return new Hono<AppEnv>()
    .get('/', async (c) => {
      const board = rankCities(await repository.countVotes());
      // Same answer for everyone, so the page in front of it may hold it briefly.
      c.header('Cache-Control', 'public, max-age=30, s-maxage=30, stale-while-revalidate=300');
      return c.json(board);
    })

    .post('/', async (c) => {
      const parsed = voteBody.safeParse(await c.req.json().catch(() => null));
      if (!parsed.success) {
        return c.json(rejected(c, 'malformed_vote', 'A city slug is required.'), 400);
      }

      const city = parsed.data.city;
      if (!isVotableCity(city)) {
        return c.json(rejected(c, 'unknown_city', 'This city is not open to votes.'), 404);
      }

      const voterHash = requestIPHash(c.req.raw, env.BETTER_AUTH_SECRET);
      if (!(await withinCityVoteQuota(redis, voterHash))) {
        return c.json(rejected(c, 'too_many_votes', 'Too many votes from this address today.'), 429);
      }

      const outcome = await repository.recordVote({ citySlug: city, voterHash });
      const board = rankCities(await repository.countVotes());

      c.header('Cache-Control', 'no-store');
      return c.json({
        ...board,
        outcome,
        city: board.cities.find((candidate) => candidate.slug === city) ?? null,
      });
    });
}

function rejected(c: Context<AppEnv>, code: string, message: string): ErrorBody {
  return { error: { code, message, requestId: c.get('requestId') } };
}

export const cityDemandRouter = createCityDemandRouter();
