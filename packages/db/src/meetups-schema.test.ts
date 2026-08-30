import { expect, test } from 'bun:test';
import { getTableName } from 'drizzle-orm';
import { getTableConfig } from 'drizzle-orm/pg-core';

import {
  friendInvitations,
  friendships,
  meetupActivityTokens,
  meetupDeviceKeys,
  meetupInvitations,
  meetupKeyEnvelopes,
  meetupParticipants,
  meetups,
} from './schema';

test('the rendez-vous domain owns the planned eight tables', () => {
  expect([
    meetups,
    meetupParticipants,
    meetupInvitations,
    friendships,
    friendInvitations,
    meetupDeviceKeys,
    meetupKeyEnvelopes,
    meetupActivityTokens,
  ].map(getTableName)).toEqual([
    'meetups',
    'meetup_participants',
    'meetup_invitations',
    'friendships',
    'friend_invitations',
    'meetup_device_keys',
    'meetup_key_envelopes',
    'meetup_activity_tokens',
  ]);
});

test('capability tables persist hashes and never raw tokens', () => {
  for (const table of [meetupParticipants, meetupInvitations, friendInvitations]) {
    const columnNames = getTableConfig(table).columns.map((column) => column.name);
    expect(columnNames).toContain('token_hash');
    expect(columnNames).not.toContain('token');
  }
});

test('removing a rendez-vous cascades every ephemeral child', () => {
  for (const table of [
    meetupParticipants,
    meetupInvitations,
    meetupDeviceKeys,
    meetupKeyEnvelopes,
    meetupActivityTokens,
  ]) {
    const references = getTableConfig(table).foreignKeys.map((foreignKey) => ({
      table: getTableName(foreignKey.reference().foreignTable),
      onDelete: foreignKey.onDelete,
    }));
    expect(references).toContainEqual({ table: 'meetups', onDelete: 'cascade' });
  }
});
