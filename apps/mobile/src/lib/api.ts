import { createORPCClient } from '@orpc/client';
import { RPCLink } from '@orpc/client/fetch';
import type { ContractRouterClient } from '@orpc/contract';
import type { contract } from '@via/contract';

export const apiBaseUrl = process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000';

/**
 * `GET` rather than the default `POST`.
 *
 * The network map is ~890 kB and changes at most once a day. Issued as a GET it
 * is a cacheable request, so `Cache-Control` from the server actually applies and
 * a warm app start pays nothing; as a POST the platform cache would ignore it.
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
