import { client } from '@via/db';

import { refreshAccessibilitySnapshot } from './import-accessibility';

try {
  const result = await refreshAccessibilitySnapshot();
  console.log(
    `Imported ${result.imported} accessibility rows` +
      ` (source ${result.sourceUpdatedAt ?? 'date inconnue'}).`
  );
} finally {
  await client.end();
}
