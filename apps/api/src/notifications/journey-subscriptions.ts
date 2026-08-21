import { and, asc, eq, gt, lte } from 'drizzle-orm';

import {
  db,
  notificationDevices,
  notificationJourneySubscriptions,
} from '@via/db';
import type {
  ActiveJourneyRegistration,
  ActiveJourneyUnregistration,
} from '@via/contract';

export type NotificationJourneySubscription =
  typeof notificationJourneySubscriptions.$inferSelect;

export type NotificationJourneyRecipient = NotificationJourneySubscription & {
  deviceToken: string;
  bundleId: string;
  environment: 'sandbox' | 'production';
};

export class NotificationInstallationOwnershipError extends Error {
  constructor() {
    super('The installation is not owned by this authenticated account.');
    this.name = 'NotificationInstallationOwnershipError';
  }
}

export interface NotificationJourneySubscriptionStore {
  register(userId: string, input: ActiveJourneyRegistration): Promise<void>;
  unregister(
    userId: string,
    input: ActiveJourneyUnregistration
  ): Promise<void>;
  listActiveBatch(
    now: Date,
    afterInstallationId: string | undefined,
    limit: number
  ): Promise<NotificationJourneyRecipient[]>;
  deleteExpired(now: Date): Promise<void>;
}

export function createDatabaseNotificationJourneySubscriptionStore(): NotificationJourneySubscriptionStore {
  return {
    async register(userId, input) {
      const now = new Date();
      const device = await db
        .select({ userId: notificationDevices.userId })
        .from(notificationDevices)
        .where(eq(notificationDevices.installationId, input.installationId))
        .limit(1);
      if (device[0]?.userId !== userId) {
        throw new NotificationInstallationOwnershipError();
      }
      await db
        .insert(notificationJourneySubscriptions)
        .values({
          installationId: input.installationId,
          userId,
          journeyId: input.journeyId,
          routeIds: input.routeIds,
          startsAt: new Date(input.startsAt),
          endsAt: new Date(input.endsAt),
          lastSeenAt: now,
        })
        .onConflictDoUpdate({
          target: notificationJourneySubscriptions.installationId,
          set: {
            userId,
            journeyId: input.journeyId,
            routeIds: input.routeIds,
            startsAt: new Date(input.startsAt),
            endsAt: new Date(input.endsAt),
            lastSeenAt: now,
          },
        });
    },

    async unregister(userId, input) {
      await db
        .delete(notificationJourneySubscriptions)
        .where(
          and(
            eq(notificationJourneySubscriptions.userId, userId),
            eq(
              notificationJourneySubscriptions.installationId,
              input.installationId
            ),
            eq(notificationJourneySubscriptions.journeyId, input.journeyId)
          )
        );
    },

    async listActiveBatch(now, afterInstallationId, limit) {
      return db
        .select({
          installationId: notificationJourneySubscriptions.installationId,
          userId: notificationJourneySubscriptions.userId,
          journeyId: notificationJourneySubscriptions.journeyId,
          routeIds: notificationJourneySubscriptions.routeIds,
          startsAt: notificationJourneySubscriptions.startsAt,
          endsAt: notificationJourneySubscriptions.endsAt,
          createdAt: notificationJourneySubscriptions.createdAt,
          lastSeenAt: notificationJourneySubscriptions.lastSeenAt,
          deviceToken: notificationDevices.deviceToken,
          bundleId: notificationDevices.bundleId,
          environment: notificationDevices.environment,
        })
        .from(notificationJourneySubscriptions)
        .innerJoin(
          notificationDevices,
          eq(notificationDevices.installationId, notificationJourneySubscriptions.installationId)
        )
        .where(
          and(
            gt(notificationJourneySubscriptions.endsAt, now),
            afterInstallationId
              ? gt(notificationJourneySubscriptions.installationId, afterInstallationId)
              : undefined
          )
        )
        .orderBy(asc(notificationJourneySubscriptions.installationId))
        .limit(limit);
    },

    async deleteExpired(now) {
      await db
        .delete(notificationJourneySubscriptions)
        .where(lte(notificationJourneySubscriptions.endsAt, now));
    },
  };
}
