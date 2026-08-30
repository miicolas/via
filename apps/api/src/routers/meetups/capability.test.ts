import { expect, test } from 'bun:test';

import { capabilityToken, capabilityTokenHash } from './capability';

test('capability retries return the same 256-bit token while namespaces stay isolated', () => {
  const first = capabilityToken('meetup-participant', 'retry-id', 'test-secret');
  const retry = capabilityToken('meetup-participant', 'retry-id', 'test-secret');
  const invitation = capabilityToken('meetup-invitation', 'retry-id', 'test-secret');

  expect(first).toBe(retry);
  expect(first).toHaveLength(43);
  expect(first).not.toBe(invitation);
  expect(capabilityTokenHash(first)).toMatch(/^[a-f0-9]{64}$/);
});
