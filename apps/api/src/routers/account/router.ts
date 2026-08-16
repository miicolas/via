import { and, eq } from 'drizzle-orm';
import { ORPCError } from '@orpc/server';
import { accounts, db, users } from '@via/db';

import { implementer } from '../../orpc/implementer';
import {
  exchangeAndRevokeAppleAuthorization,
  verifyFreshAppleIdentityToken,
} from './apple-revocation';
import { synchronizeAccount } from './sync';

const sync = implementer.account.sync.handler(async ({ input, context }) => {
  if (!context.userId) throw new ORPCError('UNAUTHORIZED');
  return synchronizeAccount(context.userId, input);
});

const deleteAccount = implementer.account.delete.handler(async ({ input, context }) => {
  if (!context.userId) throw new ORPCError('UNAUTHORIZED');

  const appleAccounts = await db
    .select({ accountId: accounts.accountId })
    .from(accounts)
    .where(and(eq(accounts.userId, context.userId), eq(accounts.providerId, 'apple')))
    .limit(1);
  const appleAccount = appleAccounts[0];
  if (!appleAccount) throw new ORPCError('UNAUTHORIZED');

  let subject: string;
  try {
    subject = await verifyFreshAppleIdentityToken(input.identityToken, input.nonce);
  } catch {
    throw new ORPCError('UNAUTHORIZED');
  }
  if (subject !== appleAccount.accountId) throw new ORPCError('UNAUTHORIZED');

  try {
    await exchangeAndRevokeAppleAuthorization(input.authorizationCode, subject);
  } catch {
    // Do not delete anything until Apple confirms revocation. The user can retry
    // with a new one-time authorization code.
    throw new ORPCError('BAD_GATEWAY');
  }

  await db.delete(users).where(eq(users.id, context.userId));
  return { deleted: true as const };
});

export const accountRouter = { delete: deleteAccount, sync };
