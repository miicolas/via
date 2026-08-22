import type {
  NotificationCategory,
  NotificationCategoryPreference,
  NotificationPreferences,
  NotificationSeverity,
} from '@via/contract';
import { NOTIFICATION_CATEGORIES } from '@via/contract';
import { NOTIFICATION_CATEGORY_DAILY_CAPS } from './config';

export const DEFAULT_NOTIFICATION_CATEGORY_CAPS: Record<NotificationCategory, number | undefined> =
  NOTIFICATION_CATEGORY_DAILY_CAPS;

const DEFAULT_CATEGORY_PREFERENCE = (category: NotificationCategory): NotificationCategoryPreference => ({
  category,
  enabled: true,
  minimumSeverity: 'attention',
  ...(DEFAULT_NOTIFICATION_CATEGORY_CAPS[category] === undefined
    ? {}
    : { dailyCap: DEFAULT_NOTIFICATION_CATEGORY_CAPS[category] }),
});

export function defaultNotificationPreferences(now = new Date()): NotificationPreferences {
  return {
    enabled: true,
    timeZone: 'Europe/Paris',
    mutedOnWeekends: false,
    mutedOnHolidays: false,
    minimumSeverity: 'attention',
    dailyCap: 20,
    categories: NOTIFICATION_CATEGORIES.map(DEFAULT_CATEGORY_PREFERENCE),
    updatedAt: now.toISOString(),
  };
}

/**
 * Merges old or hand-written rows without allowing a missing category to turn
 * into `undefined` in the policy. Unknown categories are ignored at the edge.
 */
export function mergeNotificationPreferences(
  stored: Partial<NotificationPreferences> | null | undefined,
  now = new Date(),
): NotificationPreferences {
  const defaults = defaultNotificationPreferences(now);
  const byCategory = new Map(
    (stored?.categories ?? []).map((preference) => [preference.category, preference]),
  );
  return {
    ...defaults,
    ...stored,
    timeZone: 'Europe/Paris',
    categories: NOTIFICATION_CATEGORIES.map((category) => ({
      ...DEFAULT_CATEGORY_PREFERENCE(category),
      ...(byCategory.get(category) ?? {}),
      category,
    })),
    updatedAt: stored?.updatedAt ?? defaults.updatedAt,
  };
}

export function categoryPreference(
  preferences: NotificationPreferences,
  category: NotificationCategory,
): NotificationCategoryPreference {
  return (
    preferences.categories.find((item) => item.category === category) ??
    DEFAULT_CATEGORY_PREFERENCE(category)
  );
}

export function severityRank(severity: NotificationSeverity): number {
  return { attention: 0, disrupted: 1, suspended: 2 }[severity];
}
