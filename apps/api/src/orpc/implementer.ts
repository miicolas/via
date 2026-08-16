import { implement } from '@orpc/server';
import type { ResponseHeadersPluginContext } from '@orpc/server/plugins';
import { contract } from '@via/contract';

/**
 * What every procedure can reach. `resHeaders` is injected by
 * `ResponseHeadersPlugin` and is how a procedure sets `Cache-Control` without
 * knowing it is being served over HTTP by Hono.
 */
export type ApiContext = ResponseHeadersPluginContext & {
  /** Better Auth user id; absent only for the public health procedure. */
  userId?: string;
};

/**
 * Contract-first: `implement` binds handlers to `@via/contract` and refuses to
 * type-check if a procedure is missing, renamed, or returns the wrong shape. The
 * contract is the source of truth; this file is where the server agrees to it.
 */
export const implementer = implement(contract).$context<ApiContext>();
