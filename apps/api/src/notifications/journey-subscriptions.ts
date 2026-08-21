import { and, eq, gt, lte } from 'drizzle-orm';

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
  listActive(now: Date): Promise<NotificationJourneySubscription[]>;
  deleteExpired(now: Date): Promise<number>;
  removeInstallation(userId: string, installationId: string): Promise<void>;
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

    async listActive(now) {
      return db
        .select()
        .from(notificationJourneySubscriptions)
        .where(gt(notificationJourneySubscriptions.endsAt, now));
    },

    async deleteExpired(now) {
      const expired = await db
        .delete(notificationJourneySubscriptions)
        .where(lte(notificationJourneySubscriptions.endsAt, now))
        .returning({ installationId: notificationJourneySubscriptions.installationId });
      return expired.length;
    },

    async removeInstallation(userId, installationId) {
      await db
        .delete(notificationJourneySubscriptions)
        .where(
          and(
            eq(notificationJourneySubscriptions.userId, userId),
            eq(notificationJourneySubscriptions.installationId, installationId)
          )
        );
    },
  };
}
