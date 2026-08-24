import { client } from '@via/db';

import { importGtfsSnapshot } from './import-gtfs';

const args = process.argv.slice(2);
const force = args.includes('--force');
const gtfsPath = args.find((arg) => !arg.startsWith('--')) ?? process.env.GTFS_PATH;

if (!gtfsPath) {
  throw new Error('Pass the extracted GTFS directory as an argument or set GTFS_PATH');
}

try {
  await importGtfsSnapshot(gtfsPath, force);
} finally {
  await client.end();
}
