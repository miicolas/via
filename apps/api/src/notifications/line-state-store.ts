import type { RedisClient } from '../redis';

export interface NotificationLineStateStore {
  get(routeId: string): Promise<ReadonlySet<string>>;
  set(routeId: string, disruptionIds: ReadonlySet<string>): Promise<void>;
}

export function createRedisNotificationLineStateStore(
  redis: RedisClient,
): NotificationLineStateStore {
  return {
    async get(routeId) {
      const value = await redis.get<unknown>(`notifications:line-state:${routeId}`);
      return new Set(
        Array.isArray(value)
          ? value.filter((id): id is string => typeof id === 'string')
          : [],
      );
    },
    async set(routeId, disruptionIds) {
      await redis.set(
        `notifications:line-state:${routeId}`,
        JSON.stringify([...disruptionIds]),
        { ex: 60 * 60 * 48 },
      );
    },
  };
}
