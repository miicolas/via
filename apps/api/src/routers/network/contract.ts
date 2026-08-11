import type { InferResponseType, hc } from 'hono/client';

import type { AppType } from '../../app';
import type { NetworkMap } from './types';

type ApiClient = ReturnType<typeof hc<AppType>>;

/**
 * A type-only tripwire.
 *
 * It resolves the exact expression `apps/mobile/src/lib/network-map.ts` uses —
 * `api.api.network.map.$get` — so moving the mount point, renaming a path
 * segment or reshaping the payload fails `bun run typecheck` here, in the API,
 * instead of forty files deep in the app.
 *
 * Nothing imports this file; `tsc` still checks it because it is under `include`.
 */
type NetworkMapResponse = InferResponseType<ApiClient['api']['network']['map']['$get'], 200>;

/**
 * Mutual assignability rather than strict equality: the wire type is
 * `JSONParsed<NetworkMap>`, a mapped type that is structurally identical here but
 * not referentially equal to `NetworkMap`. Both directions together still pin the
 * shape.
 */
type _WireMatchesContract = NetworkMapResponse extends NetworkMap ? true : never;
type _ContractMatchesWire = NetworkMap extends NetworkMapResponse ? true : never;

const _wireMatchesContract: _WireMatchesContract = true;
const _contractMatchesWire: _ContractMatchesWire = true;

export type { NetworkMapResponse };
export { _wireMatchesContract, _contractMatchesWire };
