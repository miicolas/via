import { describe, expect, it } from 'bun:test';

import { meetupMetricPayload, type MeetupMetric } from './metrics';

describe('Meetup telemetry privacy', () => {
  it('keeps only the closed aggregate vocabulary', () => {
    const untrusted = {
      event: 'replan',
      reason: 'missed-connection',
      category: 'fallback-at-destination',
      meetupId: 'private-id',
      displayName: 'Alice',
      latitude: 48.8566,
      token: 'secret',
      ciphertext: 'encrypted-presence',
    } as unknown as MeetupMetric;

    expect(meetupMetricPayload(untrusted)).toEqual({
      event: 'replan',
      reason: 'missed-connection',
      category: 'fallback-at-destination',
    });
  });

  it('records freshness as a category without a participant identifier', () => {
    expect(meetupMetricPayload({ event: 'freshness', category: 'delayed' })).toEqual({
      event: 'freshness',
      category: 'delayed',
    });
  });
});
