import { client } from '@via/db';

import { refreshStationPeakSnapshot } from './import-station-peaks';

try {
  const result = await refreshStationPeakSnapshot();
  if (result.skipped) {
    console.log(`Station peak profiles are already current (source ${result.sourceUpdatedAt}).`);
  } else {
    console.log(
      `Imported ${result.imported} station peak profiles` +
        ` (source ${result.sourceUpdatedAt ?? 'unknown'}).`
    );
  }
} finally {
  await client.end();
}
