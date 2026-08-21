import { and, eq, sql } from "drizzle-orm";
import { ORPCError } from "@orpc/server";
import { accounts, db, notificationDevices, users } from "@via/db";

import { implementer } from "../../orpc/implementer";
import {
  lockInstallations,
  tombstoneNotificationInstallations,
} from "../../notifications/repository";
import { redis } from "../../redis";
import {
  exchangeAndRevokeAppleAuthorization,
  verifyFreshAppleIdentityToken,
} from "./apple-revocation";
import { synchronizeAccount } from "./sync";

const sync = implementer.account.sync.handler(async ({ input, context }) => {
  if (!context.userId || context.isAnonymous)
    throw new ORPCError("UNAUTHORIZED");
  return synchronizeAccount(context.userId, input);
});

const deleteAccount = implementer.account.delete.handler(
  async ({ input, context }) => {
    if (!context.userId || context.isAnonymous)
      throw new ORPCError("UNAUTHORIZED");
    const userId = context.userId;

    const appleAccounts = await db
      .select({ accountId: accounts.accountId })
      .from(accounts)
      .where(and(eq(accounts.userId, userId), eq(accounts.providerId, "apple")))
      .limit(1);
    const appleAccount = appleAccounts[0];
    if (!appleAccount) throw new ORPCError("UNAUTHORIZED");

    let subject: string;
    try {
      subject = await verifyFreshAppleIdentityToken(
        input.identityToken,
        input.nonce,
      );
    } catch {
      throw new ORPCError("UNAUTHORIZED");
    }
    if (subject !== appleAccount.accountId) throw new ORPCError("UNAUTHORIZED");

    try {
      await exchangeAndRevokeAppleAuthorization(
        input.authorizationCode,
        subject,
      );
    } catch {
      // Do not delete anything until Apple confirms revocation. The user can retry
      // with a new one-time authorization code.
      throw new ORPCError("BAD_GATEWAY");
    }

    const deletedInstallations = await db.transaction(async (transaction) => {
      await transaction.execute(
        sql`select pg_advisory_xact_lock(hashtext(${userId}))`,
      );
      const installations = await transaction
        .select({ installationId: notificationDevices.installationId })
        .from(notificationDevices)
        .where(eq(notificationDevices.userId, userId));
      await lockInstallations(
        transaction,
        installations.map((device) => device.installationId),
      );
      const lockedInstallations = await transaction
        .select({ installationId: notificationDevices.installationId })
        .from(notificationDevices)
        .where(eq(notificationDevices.userId, userId))
        .for("update");
      await transaction.delete(users).where(eq(users.id, userId));
      return lockedInstallations.map((device) => device.installationId);
    });
    await tombstoneNotificationInstallations(redis, deletedInstallations).catch(
      (error) => {
        // PostgreSQL is authoritative: post-claim DB revalidation rejects these
        // installations even when this cache invalidation must be retried later.
        console.error("[account] notification invalidation deferred", error);
      },
    );
    return { deleted: true as const };
  },
);

export const accountRouter = { delete: deleteAccount, sync };
