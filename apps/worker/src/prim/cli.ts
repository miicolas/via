import { client } from '@via/db';

import { refreshWayfindingSnapshot } from '../wayfinding/import-wayfinding';
import { synchronizePrimGtfs } from './sync-gtfs';

try {
  const result = await synchronizePrimGtfs(process.env.PRIM_STATIC_DATA_TOKEN ?? '');
  console.log(
    result.status === 'unchanged'
      ? 'PRIM GTFS archive unchanged — nothing to import.'
      : `PRIM GTFS ${result.status} (${result.feedHash}).`
  );

  // Wayfinding rows hang off the freshly imported stops and patterns, and their
  // open-data sources move on their own schedule — refresh even when the GTFS
  // archive is unchanged, or the carriage advice drifts out from under the API.
  const wayfinding = await refreshWayfindingSnapshot();
  console.log(
    `Wayfinding refreshed: ${wayfinding.exits} station exits` +
      ` and ${wayfinding.positions} boarding positions.`
  );
} finally {
  await client.end();
}
