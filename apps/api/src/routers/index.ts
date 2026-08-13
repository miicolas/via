import { implementer } from '../orpc/implementer';
import { departuresRouter } from './departures/router';
import { healthRouter } from './health/router';
import { journeysRouter } from './journeys/router';
import { networkRouter } from './network/router';
import { searchRouter } from './search/router';

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
  departures: departuresRouter,
  health: healthRouter,
  journeys: journeysRouter,
  network: networkRouter,
  search: searchRouter,
});
