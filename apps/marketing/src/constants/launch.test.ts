import { describe, expect, test } from 'bun:test';

import { analyticsContent } from './analytics-page';
import {
  APP_STORE_ID,
  APP_STORE_URL,
  availableLaunch,
  launch,
  launchNavigation,
  supportAction,
} from './launch';
import { pageContent } from './page';

describe('launch configuration', () => {
  test('prelaunch is a status, not a download action', () => {
    expect(launch.phase).toBe('prelaunch');
    expect(launch.appStoreAction).toBeNull();
    expect(launch.availabilityLabel).toBeTruthy();
    expect(launchNavigation).toEqual({ label: 'Disponibilité', href: '#download' });
  });

  test('validates the canonical public App Store listing', () => {
    const available = availableLaunch();

    expect(available).toEqual({
      phase: 'available',
      availabilityLabel: 'Disponible maintenant',
      appStoreAction: { label: 'Télécharger Metyro', href: APP_STORE_URL },
    });
    expect(APP_STORE_URL).toContain(`id${APP_STORE_ID}`);
    for (const url of [
      'http://apps.apple.com/fr/app/metyro/id6801259695',
      'https://example.com/fr/app/metyro/id6801259695',
      'https://apps.apple.com/fr/app/other/id6801259695',
      'https://apps.apple.com/fr/app/metyro/id1',
    ]) {
      expect(() => availableLaunch(url)).toThrow();
    }
  });

  test('keeps support real and both content pages on the same model', () => {
    expect(supportAction).toEqual({ label: 'Contacter l’assistance', href: '/help' });
    expect(pageContent.hero.action).toBe(launch);
    expect(pageContent.faq.primaryAction).toBe(launch);
    expect(pageContent.footer.action).toBe(launch);
    expect(analyticsContent.hero.action).toBe(launch);
    expect(analyticsContent.download.action).toBe(launch);
  });
});
