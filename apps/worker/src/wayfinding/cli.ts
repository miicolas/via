import { client } from '@via/db';

import { refreshWayfindingSnapshot } from './import-wayfinding';

try {
  const result = await refreshWayfindingSnapshot();
  console.log(
    `Imported ${result.exits} station exits (source ${result.exitsUpdatedAt ?? 'date inconnue'})` +
      ` and ${result.positions} boarding positions` +
      ` (source ${result.positionsUpdatedAt ?? 'date inconnue'}).`
  );
} finally {
  await client.end();
}
