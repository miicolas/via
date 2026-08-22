import { expect, test } from 'bun:test';

import {
  fitDeviceNotification,
  payloadByteLength,
  truncateUTF8,
} from './payload';

test('UTF-8 truncation never leaves a partial scalar', () => {
  expect(truncateUTF8('é', 1)).toBe('');
  expect(truncateUTF8('Très long', 5)).toBe('Tr…');
});

test('pathological custom data is stripped before an APNs payload escapes', () => {
  const notification = fitDeviceNotification({
    title: 'Via',
    body: 'Une information',
    data: { oversized: 'x'.repeat(20_000) },
  });

  expect(payloadByteLength(notification)).toBeLessThanOrEqual(4_096);
  expect(notification.data).toBeUndefined();
});
