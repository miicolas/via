import { expect, test } from 'bun:test';

import { canonicalFriendPair, friendInitials } from './domain';

test('friend pairs have one canonical database identity', () => {
  expect(canonicalFriendPair('zoe', 'alice')).toEqual(['alice', 'zoe']);
  expect(canonicalFriendPair('alice', 'zoe')).toEqual(['alice', 'zoe']);
  expect(() => canonicalFriendPair('alice', 'alice')).toThrow('self');
});

test('friend initials are stable without sharing profile photos', () => {
  expect(friendInitials('Sam Lee')).toBe('SL');
  expect(friendInitials('  Élodie  ')).toBe('É');
  expect(friendInitials('')).toBe('?');
});
