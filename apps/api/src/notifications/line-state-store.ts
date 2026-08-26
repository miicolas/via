import type { RedisClient } from '../redis';

export type NotificationLineState = {
  disruptionIds: ReadonlySet<string>;
  /** Alert subscriptions that were eligible during the last observation. */
  subscriptionIds: ReadonlySet<string>;
  /** Consecutive polls in which a previously seen disruption was absent. */
  missingCycles: ReadonlyMap<string, number>;
};

export interface NotificationLineStateStore {
  get(routeId: string): Promise<NotificationLineState>;
  set(routeId: string, state: NotificationLineState): Promise<void>;
}

export function createRedisNotificationLineStateStore(
  redis: RedisClient,
): NotificationLineStateStore {
  return {
    async get(routeId) {
      const value = await redis.get<unknown>(`notifications:line-state:${routeId}`);
      if (Array.isArray(value)) {
        // The first version of this store persisted a bare array. Accept it so
        // a deploy does not lose the observed disruptions. The monitor treats
        // the missing subscription metadata as a new observation; its alert
        // claims still prevent a notification already sent from repeating.
        return {
          disruptionIds: new Set(value.filter((id): id is string => typeof id === 'string')),
          subscriptionIds: new Set(),
          missingCycles: new Map(),
        };
      }

      if (typeof value !== 'object' || value === null) {
        return {
          disruptionIds: new Set(),
          subscriptionIds: new Set(),
          missingCycles: new Map(),
        };
      }

      const record = value as Record<string, unknown>;
      const disruptionIds = new Set(
        Array.isArray(record.disruptionIds)
          ? record.disruptionIds.filter((id): id is string => typeof id === 'string')
          : [],
      );
      const subscriptionIds = new Set(
        Array.isArray(record.subscriptionIds)
          ? record.subscriptionIds.filter((id): id is string => typeof id === 'string')
          : [],
      );
      const missingCycles = new Map<string, number>();
      if (typeof record.missingCycles === 'object' && record.missingCycles !== null) {
        for (const [id, cycles] of Object.entries(record.missingCycles)) {
          if (Number.isSafeInteger(cycles) && cycles > 0) {
            missingCycles.set(id, cycles);
          }
        }
      }
      return { disruptionIds, subscriptionIds, missingCycles };
    },
    async set(routeId, state) {
      await redis.set(
        `notifications:line-state:${routeId}`,
        JSON.stringify({
          disruptionIds: [...state.disruptionIds],
          subscriptionIds: [...state.subscriptionIds],
          missingCycles: Object.fromEntries(state.missingCycles),
        }),
        { ex: 60 * 60 * 48 },
      );
    },
  };
}
