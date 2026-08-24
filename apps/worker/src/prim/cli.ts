import { client } from '@via/db';

import { synchronizePrimGtfs } from './sync-gtfs';

try {
  const result = await synchronizePrimGtfs(process.env.PRIM_STATIC_DATA_TOKEN ?? '');
  console.log(
    result.status === 'unchanged'
      ? 'PRIM GTFS archive unchanged — nothing to import.'
      : `PRIM GTFS ${result.status} (${result.feedHash}).`
  );
} finally {
  await client.end();
}
