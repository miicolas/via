import { expect, test } from 'bun:test';

import { runWithImportLock, type ImportLock } from './import-lock';

test('rejects a concurrent GTFS import before it starts', async () => {
  let held = false;
  let secondStarted = false;
  let releaseFirst!: () => void;
  const firstCanFinish = new Promise<void>((resolve) => {
    releaseFirst = resolve;
  });

  const makeLock = (): ImportLock => {
    let ownsLock = false;
    return {
      async acquire() {
        if (held) return false;
        held = true;
        ownsLock = true;
        return true;
      },
      async release() {
        if (!ownsLock) return;
        held = false;
        ownsLock = false;
      },
    };
  };

  const first = runWithImportLock(makeLock(), () => firstCanFinish);
  await expect(
    runWithImportLock(makeLock(), async () => {
      secondStarted = true;
    })
  ).rejects.toThrow('A GTFS import is already running');

  expect(secondStarted).toBe(false);
  releaseFirst();
  await first;
  expect(held).toBe(false);
});

test('releases the GTFS import lock when the import fails', async () => {
  let releases = 0;
  const lock: ImportLock = {
    async acquire() {
      return true;
    },
    async release() {
      releases += 1;
    },
  };

  await expect(
    runWithImportLock(lock, async () => {
      throw new Error('import failed');
    })
  ).rejects.toThrow('import failed');
  expect(releases).toBe(1);
});
