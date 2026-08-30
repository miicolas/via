import { describe, expect, test } from 'bun:test';

import type { Journey, MeetupOrigin } from '@via/contract';

import { createMeetupOriginCipher } from './origin-crypto';

const origin: MeetupOrigin = {
  kind: 'address',
  id: 'private-address',
  name: '12 rue secrète',
  context: 'Paris',
  coordinate: { latitude: 48.84, longitude: 2.37 },
};

const privateJourney: Journey = {
  id: 'private-journey',
  qualifier: 'recommended',
  durationSeconds: 600,
  walkingDurationSeconds: 0,
  transferCount: 0,
  departureAt: '2026-08-30T18:40:00+02:00',
  arrivalAt: '2026-08-30T18:50:00+02:00',
  status: 'normal',
  warnings: [],
  sections: [{
    id: 'private-section',
    type: 'transit',
    durationSeconds: 600,
    from: {
      name: '12 rue secrète',
      coordinate: { latitude: 48.84, longitude: 2.37 },
    },
    to: {
      name: 'Châtelet',
      coordinate: { latitude: 48.858, longitude: 2.347 },
    },
    departureAt: '2026-08-30T18:40:00+02:00',
    arrivalAt: '2026-08-30T18:50:00+02:00',
    geometry: [],
    stops: [],
  }],
};

describe('meetup origin encryption', () => {
  test('round-trips without persisting a readable origin', () => {
    const cipher = createMeetupOriginCipher([
      { version: 2, key: Buffer.alloc(32, 7) },
    ]);

    const encrypted = cipher.encrypt(origin);

    expect(cipher.decrypt(encrypted)).toEqual(origin);
    expect(JSON.stringify(encrypted)).not.toContain('rue secrète');
    expect(encrypted.keyVersion).toBe(2);
  });

  test('uses a fresh nonce for every write', () => {
    const cipher = createMeetupOriginCipher([
      { version: 1, key: Buffer.alloc(32, 9) },
    ]);

    expect(cipher.encrypt(origin).nonce).not.toBe(cipher.encrypt(origin).nonce);
  });

  test('round-trips a full journey without persisting its private route', () => {
    const cipher = createMeetupOriginCipher([
      { version: 3, key: Buffer.alloc(32, 5) },
    ]);

    const encrypted = cipher.encryptJourney(privateJourney);

    expect(cipher.decryptJourney(encrypted)).toEqual(privateJourney);
    expect(JSON.stringify(encrypted)).not.toContain('rue secrète');
    expect(JSON.stringify(encrypted)).not.toContain('48.84');
  });

  test('refuses data whose authentication tag no longer matches', () => {
    const cipher = createMeetupOriginCipher([
      { version: 1, key: Buffer.alloc(32, 4) },
    ]);
    const encrypted = cipher.encrypt(origin);

    expect(() => cipher.decrypt({ ...encrypted, ciphertext: `${encrypted.ciphertext}AA` })).toThrow();
  });
});
