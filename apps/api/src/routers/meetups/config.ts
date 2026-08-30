import { env, siteURL } from '../../env';

/**
 * The transport-facing knobs the meetup rules need, read once at the module
 * edge so the rule bodies never reach into `env` themselves.
 */
export type MeetupServiceConfig = {
  /** The shareable capability URL for an invitation token (ADR-0006). */
  invitationURL(token: string): string;
  /** Feature flag: may precise encrypted presence transit through the API? */
  precisePresenceEnabled: boolean;
};

export function meetupConfigFromEnv(): MeetupServiceConfig {
  return {
    invitationURL: (token) => siteURL(`meet/${token}`),
    precisePresenceEnabled: env.MEETUP_PRECISE_PRESENCE_ENABLED,
  };
}
