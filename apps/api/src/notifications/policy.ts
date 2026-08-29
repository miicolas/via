import type {
  NotificationCategory,
  NotificationInterruptionLevel,
  NotificationPreferences,
  NotificationSeverity,
} from '@via/contract';
import { frenchHolidays, parisDay, parisDayType } from '../time/paris';
import { categoryPreference, mergeNotificationPreferences, severityRank } from './preferences';

export type DeliveryDropReason =
  | 'quiet-hours'
  | 'cap'
  | 'category-off'
  | 'severity'
  | 'stale'
  | 'no-signal'
  | 'empty'
  | 'muted';

export type DeliveryPolicyInput = {
  preferences: NotificationPreferences | Partial<NotificationPreferences> | null | undefined;
  category: NotificationCategory;
  severity?: NotificationSeverity;
  at?: Date;
  sentToday?: number;
  /** A category-specific cap supplied by the dispatcher or monitor. */
  dailyCap?: number;
  muted?: boolean;
  stale?: boolean;
  hasSignal?: boolean;
  empty?: boolean;
  inDeclaredWindow?: boolean;
};

export type DeliveryPolicyResult =
  | { send: true; interruptionLevel: NotificationInterruptionLevel }
  | { send: false; reason: DeliveryDropReason };

function isInsideQuietHours(minute: number, start: number, end: number): boolean {
  if (start < end) return minute >= start && minute < end;
  return minute >= start || minute < end;
}

export function isNotificationQuietAt(
  rawPreferences: NotificationPreferences | Partial<NotificationPreferences> | null | undefined,
  at: Date,
): boolean {
  const preferences = mergeNotificationPreferences(rawPreferences, at);
  const day = parisDay(at);
  const dayType = parisDayType(at);
  if (
    (preferences.mutedOnWeekends && (dayType === 'saturday' || dayType === 'sunday')) ||
    (preferences.mutedOnHolidays && frenchHolidays(Number(day.date.slice(0, 4))).has(day.date))
  ) {
    return true;
  }
  return (
    preferences.quietHoursStartMinute !== undefined &&
    preferences.quietHoursEndMinute !== undefined &&
    isInsideQuietHours(
      Math.floor(day.seconds / 60),
      preferences.quietHoursStartMinute,
      preferences.quietHoursEndMinute,
    )
  );
}

function interruptionLevelFor(
  category: NotificationCategory,
  _severity: NotificationSeverity | undefined,
  inDeclaredWindow: boolean,
): NotificationInterruptionLevel {
  if (category === 'digest') return 'passive';
  if (category === 'journey' || category === 'commute') {
    return 'timeSensitive';
  }
  if ((category === 'line' || category === 'station') && inDeclaredWindow) {
    return 'timeSensitive';
  }
  return 'active';
}

export function evaluateDelivery(input: DeliveryPolicyInput): DeliveryPolicyResult {
  const preferences = mergeNotificationPreferences(input.preferences);
  const at = input.at ?? new Date();
  const category = categoryPreference(preferences, input.category);

  if (input.muted) return { send: false, reason: 'muted' };
  if (input.stale) return { send: false, reason: 'stale' };
  if (input.empty) return { send: false, reason: 'empty' };
  if (input.hasSignal === false) return { send: false, reason: 'no-signal' };
  if (!category.enabled) return { send: false, reason: 'category-off' };

  if (isNotificationQuietAt(preferences, at)) {
    return { send: false, reason: 'quiet-hours' };
  }

  const severity = input.severity ?? 'attention';
  if (
    severityRank(severity) < severityRank(preferences.minimumSeverity) ||
    severityRank(severity) < severityRank(category.minimumSeverity)
  ) {
    return { send: false, reason: 'severity' };
  }

  const cap = input.dailyCap ?? category.dailyCap ?? preferences.dailyCap;
  if (input.category !== 'journey' && cap !== undefined && (input.sentToday ?? 0) >= cap) {
    return { send: false, reason: 'cap' };
  }

  return {
    send: true,
    interruptionLevel: interruptionLevelFor(
      input.category,
      input.severity,
      input.inDeclaredWindow ?? false,
    ),
  };
}
