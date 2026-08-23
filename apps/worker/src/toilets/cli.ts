import { client } from '@via/db';

import { bumpTransitNetworkCacheVersion } from '../network-cache-version';
import { refreshToiletSnapshot } from './import-toilets';

try {
  const result = await refreshToiletSnapshot();
  if (result.skipped) {
    console.log(`Station toilets are already current (source ${result.sourceUpdatedAt}).`);
  } else {
    await bumpTransitNetworkCacheVersion();
    console.log(
      `Imported ${result.imported} station toilet facts` +
        ` (source ${result.sourceUpdatedAt ?? 'unknown'}).`
    );
  }
} finally {
  await client.end();
}
