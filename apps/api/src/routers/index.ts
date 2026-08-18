import { env } from '../env';
import { implementer } from '../orpc/implementer';
import { redis } from '../redis';
import { accountRouter } from './account/router';
import { departuresRouter } from './departures/router';
import { healthRouter } from './health/router';
import { createGtfsJourneyPlanner } from './journeys/gtfs/loader';
import { createIdfmJourneyPlanner } from './journeys/idfm/client';
import { createJourneysRouter } from './journeys/router';
import { createJourneyPlanner } from './journeys/service';
import { linesRouter } from './lines/router';
import { networkRouter } from './network/router';
import { serviceHorizon } from './natural-journeys/horizon';
import { createNaturalLanguageModel } from './natural-journeys/model';
import { placeResolver } from './natural-journeys/place-resolver';
import { createNaturalJourneysRouter } from './natural-journeys/router';
import { createNaturalJourneyService } from './natural-journeys/service';
import { searchRouter } from './search/router';

const journeyPlanner = createJourneyPlanner({
  redis,
  idfm: env.API_KEY_PRISM_IDFM
    ? createIdfmJourneyPlanner({
        apiKey: env.API_KEY_PRISM_IDFM,
        url: env.PRIM_JOURNEY_PLANNER_URL,
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
  model: createNaturalLanguageModel({
    apiKey: env.OPENAI_API_KEY,
    model: env.OPENAI_MODEL,
    inputCostPerMillion: env.OPENAI_INPUT_COST_PER_MILLION,
    outputCostPerMillion: env.OPENAI_OUTPUT_COST_PER_MILLION,
  }),
  places: placeResolver,
  journeys: journeyPlanner,
  horizon: serviceHorizon,
  clock: { now: () => new Date() },
  config: {
    enabled: env.NATURAL_JOURNEYS_ENABLED,
    rolloutPercent: env.NATURAL_JOURNEYS_ROLLOUT_PERCENT,
    personalLimit: env.NATURAL_JOURNEYS_PERSONAL_LIMIT,
    personalWindowSeconds: env.NATURAL_JOURNEYS_PERSONAL_WINDOW_SECONDS,
    breakerFailures: env.NATURAL_JOURNEYS_BREAKER_FAILURES,
    breakerCooldownSeconds: env.NATURAL_JOURNEYS_BREAKER_COOLDOWN_SECONDS,
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
  lines: linesRouter,
  naturalJourneys: createNaturalJourneysRouter(naturalJourneyService),
  network: networkRouter,
  search: searchRouter,
});
