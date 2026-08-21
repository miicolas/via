import { describe, expect, test } from 'bun:test';

import { safetyIdentifier } from './safety-identifier';

describe('safety identifier', () => {
  test('is a stable HMAC, never the raw identity', () => {
    const id = safetyIdentifier('user-123', 'secret');

    expect(id).not.toBe('user-123');
    expect(id).not.toContain('user-123');
    expect(id).toMatch(/^[0-9a-f]{64}$/);
    expect(safetyIdentifier('user-123', 'secret')).toBe(id);
  });

  test('different identities and secrets diverge', () => {
    expect(safetyIdentifier('a', 'secret')).not.toBe(safetyIdentifier('b', 'secret'));
    expect(safetyIdentifier('a', 'secret-1')).not.toBe(safetyIdentifier('a', 'secret-2'));
  });
});
