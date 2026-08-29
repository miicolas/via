import { expect, test } from 'bun:test';

import { defaultNotificationPreferences } from './preferences';
import { evaluateDelivery } from './policy';

test('legacy in-app master switch no longer disables delivery', () => {
  const preferences = defaultNotificationPreferences();
  preferences.enabled = false;

  expect(evaluateDelivery({
    preferences,
    category: 'journey',
  })).toEqual({ send: true, interruptionLevel: 'timeSensitive' });
});

test('disabled categories win before their daily cap', () => {
  const preferences = defaultNotificationPreferences(new Date('2026-08-21T10:00:00Z'));
  preferences.categories = preferences.categories.map((category) =>
    category.category === 'line'
      ? { ...category, enabled: false, dailyCap: 0 }
      : category,
  );

  expect(evaluateDelivery({
    preferences,
    category: 'line',
    severity: 'suspended',
    sentToday: 99,
  })).toEqual({ send: false, reason: 'category-off' });
});

test('quiet hours wrap across midnight', () => {
  const preferences = defaultNotificationPreferences();
  preferences.quietHoursStartMinute = 22 * 60;
  preferences.quietHoursEndMinute = 7 * 60;

  expect(evaluateDelivery({
    preferences,
    category: 'line',
    at: new Date('2026-08-21T21:30:00.000Z'), // 23:30 in Paris
  })).toEqual({ send: false, reason: 'quiet-hours' });
});

test('line alerts are time-sensitive only inside a declared window', () => {
  const preferences = defaultNotificationPreferences();

  expect(evaluateDelivery({
    preferences,
    category: 'line',
    severity: 'suspended',
    inDeclaredWindow: true,
  })).toEqual({ send: true, interruptionLevel: 'timeSensitive' });
  expect(evaluateDelivery({
    preferences,
    category: 'line',
    severity: 'suspended',
    inDeclaredWindow: false,
  })).toEqual({ send: true, interruptionLevel: 'active' });
});

test("a line alert inside the user's declared window is time-sensitive", () => {
  const preferences = defaultNotificationPreferences();

  expect(evaluateDelivery({
    preferences,
    category: 'line',
    severity: 'disrupted',
    inDeclaredWindow: true,
  })).toEqual({ send: true, interruptionLevel: 'timeSensitive' });
});
