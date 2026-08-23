import { client } from '@via/db';

import { refreshElevatorSnapshot } from './import-elevators';

try {
  const result = await refreshElevatorSnapshot();
  console.log(
    `Imported ${result.imported} elevators across ${result.stations} stations` +
      ` (source ${result.sourceUpdatedAt ?? 'date unknown'}).`
  );
} finally {
  await client.end();
}
