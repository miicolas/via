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
import { networkRouter } from './network/router';
import { searchRouter } from './search/router';

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
  network: networkRouter,
  search: searchRouter,
});
