import { createORPCClient } from '@orpc/client';
import { RPCLink } from '@orpc/client/fetch';
import type { ContractRouterClient } from '@orpc/contract';
import type { contract } from '@via/contract';

/**
 * Trailing slashes are stripped: `EXPO_PUBLIC_API_URL` is hand-written per machine,
 * and a stray one would build `//rpc`, which the server's `/rpc/*` route misses —
 * a 404 that looks like the API is down rather than like a typo.
 */
export const apiBaseUrl = (process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000').replace(
  /\/+$/,
  ''
);

/**
 * `GET` rather than the default `POST`.
 *
 * The full transit map changes at most once a day. Issued as a GET it is cacheable
 * and compressible, so `Cache-Control` from the server actually applies and a
 * warm app start pays nothing; as a POST the platform cache would ignore it.
 * `fallbackMethod` covers any future procedure whose input is too long for a URL.
 */
const link = new RPCLink({
  url: `${apiBaseUrl}/rpc`,
  method: () => 'GET',
  fallbackMethod: 'POST',
});

/**
 * Typed from `@via/contract` alone — the app no longer compiles the API's source,
 * so drizzle and the PostGIS query layer are out of its typecheck entirely.
 */
export const api: ContractRouterClient<typeof contract> = createORPCClient(link);
