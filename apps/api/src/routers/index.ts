import { env } from '../env';
import { implementer } from '../orpc/implementer';
import { redis } from '../redis';
import { accountRouter } from './account/router';
import { departuresRouter } from './departures/router';
import { healthRouter } from './health/router';
import { createGtfsJourneyPlanner } from './journeys/gtfs/loader';
import { createIdfmJourneyPlanner } from './journeys/idfm/client';
import { loadJourneyShapes } from './journeys/idfm/shape-loader';
import { createJourneysRouter } from './journeys/router';
import { createJourneyPlanner } from './journeys/service';
import { linesRouter } from './lines/router';
import { createNaturalJourneysRouter } from './natural-journeys/router';
import { createOpenAiResponsesTransport } from './natural-journeys/openai-transport';
import { createNaturalJourneyService } from './natural-journeys/service';
import { networkRouter } from './network/router';
import { searchRouter } from './search/router';
import { searchPlaces } from './search/search-places';

const journeyPlanner = createJourneyPlanner({
  redis,
  idfm: env.API_KEY_PRISM_IDFM
    ? createIdfmJourneyPlanner({
        apiKey: env.API_KEY_PRISM_IDFM,
        url: env.PRIM_JOURNEY_PLANNER_URL,
        loadShapes: loadJourneyShapes,
      })
    : null,
  gtfs: createGtfsJourneyPlanner(),
  clock: { now: () => new Date() },
  config: {
    personalLimit: env.PRIM_JOURNEYS_PERSONAL_LIMIT,
    personalWindowSeconds: env.PRIM_JOURNEYS_PERSONAL_WINDOW_SECONDS,
    dailyBudget: env.PRIM_JOURNEYS_DAILY_BUDGET,
  },
});

const naturalJourneyService = createNaturalJourneyService({
  redis,
  planner: journeyPlanner,
  searchPlaces: async (query, options) => {
    const { results, banAvailable } = await searchPlaces(query, options);
    return { results, banAvailable };
  },
  // Null adapter when no key: the service answers the recoverable double-failure
  // and the key stays confined to this backend, never shipped to the app.
  transport: env.OPENAI_API_KEY
    ? createOpenAiResponsesTransport({
        apiKey: env.OPENAI_API_KEY,
        timeoutMs: env.OPENAI_TIMEOUT_MS,
      })
    : null,
  clock: { now: () => new Date() },
  config: {
    model: env.OPENAI_MODEL,
    timeoutMs: env.OPENAI_TIMEOUT_MS,
    personalLimit: env.OPENAI_PERSONAL_LIMIT,
    personalWindowSeconds: env.OPENAI_PERSONAL_WINDOW_SECONDS,
    breaker: {
      failureThreshold: env.OPENAI_BREAKER_FAILURE_THRESHOLD,
      openSeconds: env.OPENAI_BREAKER_OPEN_SECONDS,
    },
    safetySecret: env.OPENAI_SAFETY_SECRET ?? env.BETTER_AUTH_SECRET,
    pricing: null,
  },
});

/**
 * The implemented contract. `implementer.router` is the assertion that every
 * procedure the contract declares actually exists here — adding a procedure to
 * `@via/contract` without implementing it fails the typecheck rather than 404ing
 * at runtime.
 *
 * The folder tree still mirrors the URL tree: `routers/network/` serves
 * `/api/network/*`.
 */
export const apiRouter = implementer.router({
  account: accountRouter,
  departures: departuresRouter,
  health: healthRouter,
  journeys: createJourneysRouter(journeyPlanner),
  naturalJourneys: createNaturalJourneysRouter(naturalJourneyService),
  lines: linesRouter,
  network: networkRouter,
  search: searchRouter,
});
