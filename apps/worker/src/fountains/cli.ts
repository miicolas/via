import { client } from '@via/db';

import { refreshFountainSnapshot } from './import-fountains';

try {
  const result = await refreshFountainSnapshot();
  if (result.skipped) {
    console.log(`Station fountains are already current (source ${result.sourceUpdatedAt}).`);
  } else {
    console.log(
      `Imported ${result.imported} station fountain facts` +
        ` (source ${result.sourceUpdatedAt ?? 'unknown'}).`
    );
  }
} finally {
  await client.end();
}
