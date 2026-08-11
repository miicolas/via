import { implementer } from '../orpc/implementer';
import { healthRouter } from './health/router';
import { networkRouter } from './network/router';

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
  health: healthRouter,
  network: networkRouter,
});
