import { expect, test } from 'bun:test';

import {
  NOTIFICATION_ALERT_POLL_SECONDS,
  NOTIFICATION_DISRUPTION_POLL_SECONDS,
} from './config';

test('live notification monitors do not add more than twenty seconds of latency', () => {
  expect(NOTIFICATION_ALERT_POLL_SECONDS).toBeLessThanOrEqual(20);
  expect(NOTIFICATION_DISRUPTION_POLL_SECONDS).toBeLessThanOrEqual(20);
});
