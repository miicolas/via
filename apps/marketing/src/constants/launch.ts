import type { CallToAction, LinkItem } from './types';

export const APP_STORE_ID = '6801259695';
export const APP_STORE_URL = `https://apps.apple.com/fr/app/metyro/id${APP_STORE_ID}`;

export type LaunchConfiguration =
  | {
      readonly phase: 'prelaunch';
      readonly availabilityLabel: string;
      readonly appStoreAction: null;
    }
  | {
      readonly phase: 'available';
      readonly availabilityLabel: string;
      readonly appStoreAction: CallToAction;
    };

/** The App Store Connect record is not public yet; keep every CTA truthful. */
export const launch = {
  phase: 'prelaunch',
  availabilityLabel: 'Bientôt disponible sur l’App Store',
  appStoreAction: null,
} as const satisfies LaunchConfiguration;

export const supportAction = {
  label: 'Contacter l’assistance',
  href: '/help',
} as const satisfies CallToAction;

export function launchNavigationFor(configuration: LaunchConfiguration): LinkItem {
  return {
    label: configuration.phase === 'available' ? 'Télécharger' : 'Disponibilité',
    href: '#download',
  };
}

export const launchNavigation = launchNavigationFor(launch);

/** Validate a future public listing before switching the single configuration. */
export function availableLaunch(url: string = APP_STORE_URL): LaunchConfiguration {
  const parsed = new URL(url);
  if (
    parsed.protocol !== 'https:' ||
    parsed.hostname !== 'apps.apple.com' ||
    parsed.pathname !== `/fr/app/metyro/id${APP_STORE_ID}` ||
    parsed.search ||
    parsed.hash
  ) {
    throw new Error('The App Store URL must be the canonical Metyro listing');
  }
  return {
    phase: 'available',
    availabilityLabel: 'Disponible maintenant',
    appStoreAction: {
      label: 'Télécharger Metyro',
      href: parsed.toString(),
    },
  };
}
