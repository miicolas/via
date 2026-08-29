import { describe, expect, test } from 'bun:test';

import { finalizeGtfsImportMetadata } from './gtfs-import-metadata';

describe('finalizeGtfsImportMetadata', () => {
  test('writes the hash and generation through one transaction', async () => {
    const transactionObject = {};
    const events: string[] = [];
    let committed = false;

    await finalizeGtfsImportMetadata('feed-hash', {
      transaction: async (work) => {
        events.push('transaction');
        await work(transactionObject);
        committed = true;
      },
      writeFeedHash: async (transaction, hash) => {
        expect(transaction).toBe(transactionObject);
        expect(hash).toBe('feed-hash');
        events.push('hash');
      },
      bumpVersion: async (transaction) => {
        expect(transaction).toBe(transactionObject);
        events.push('generation');
      },
    });

    expect(events).toEqual(['transaction', 'hash', 'generation']);
    expect(committed).toBe(true);
  });

  test('does not report a commit when the generation write fails', async () => {
    let committed = false;
    const failure = new Error('generation unavailable');

    await expect(finalizeGtfsImportMetadata('feed-hash', {
      transaction: async (work) => {
        await work({});
        committed = true;
      },
      writeFeedHash: async () => undefined,
      bumpVersion: async () => { throw failure; },
    })).rejects.toBe(failure);

    expect(committed).toBe(false);
  });

  test('rejects an empty hash before opening a transaction', async () => {
    let opened = false;

    await expect(finalizeGtfsImportMetadata('   ', {
      transaction: async () => { opened = true; },
    })).rejects.toThrow('must not be empty');

    expect(opened).toBe(false);
  });
});
