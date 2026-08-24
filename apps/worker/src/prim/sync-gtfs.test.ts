import { expect, test } from 'bun:test';

import {
  synchronizePrimGtfs,
  type PrimGtfsSyncAdapters,
} from './sync-gtfs';

function adapters(
  overrides: Partial<PrimGtfsSyncAdapters> = {}
): { events: string[]; value: PrimGtfsSyncAdapters } {
  const events: string[] = [];
  return {
    events,
    value: {
      async createTemporaryDirectory() {
        events.push('create temporary directory');
        return '/temporary/gtfs-sync';
      },
      async removeTemporaryDirectory(path) {
        events.push(`remove ${path}`);
      },
      async loadValidators() {
        events.push('load validators');
        return { etag: '"previous"' };
      },
      async download({ destination }) {
        events.push(`download ${destination}`);
        return {
          status: 'downloaded',
          validators: { etag: '"current"', lastModified: 'today' },
        };
      },
      async extract(archive, destination) {
        events.push(`extract ${archive} to ${destination}`);
      },
      async importSnapshot(path) {
        events.push(`import ${path}`);
        return { status: 'imported', feedHash: 'hash' };
      },
      async saveValidators(validators) {
        events.push(`save ${validators.etag} ${validators.lastModified}`);
      },
      ...overrides,
    },
  };
}

test('imports the downloaded snapshot before committing its HTTP validators', async () => {
  const fake = adapters();

  const result = await synchronizePrimGtfs('dataset-token', fake.value);

  expect(result).toEqual({ status: 'imported', feedHash: 'hash' });
  expect(fake.events).toEqual([
    'create temporary directory',
    'load validators',
    'download /temporary/gtfs-sync/snapshot.zip',
    'extract /temporary/gtfs-sync/snapshot.zip to /temporary/gtfs-sync/feed',
    'import /temporary/gtfs-sync/feed',
    'save "current" today',
    'remove /temporary/gtfs-sync',
  ]);
});

test('does not import an archive that PRIM reports unchanged', async () => {
  const fake = adapters({
    async download() {
      fake.events.push('unchanged');
      return { status: 'unchanged' };
    },
  });

  const result = await synchronizePrimGtfs('dataset-token', fake.value);

  expect(result).toEqual({ status: 'unchanged' });
  expect(fake.events).toEqual([
    'create temporary directory',
    'load validators',
    'unchanged',
    'remove /temporary/gtfs-sync',
  ]);
});

test('keeps the previous validators and cleans temporary files when import fails', async () => {
  const fake = adapters({
    async importSnapshot() {
      fake.events.push('failed import');
      throw new Error('invalid GTFS');
    },
  });

  await expect(synchronizePrimGtfs('dataset-token', fake.value)).rejects.toThrow('invalid GTFS');
  expect(fake.events).not.toContain('save "current" today');
  expect(fake.events.at(-1)).toBe('remove /temporary/gtfs-sync');
});

test('fails before any work when the PRIM dataset token is missing', async () => {
  const fake = adapters();

  await expect(synchronizePrimGtfs('', fake.value)).rejects.toThrow(
    'PRIM_STATIC_DATA_TOKEN is required'
  );
  expect(fake.events).toEqual([]);
});
