import { and, eq } from 'drizzle-orm';
import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { anonymous, bearer } from 'better-auth/plugins';
import { accounts, db, schema, users } from '@via/db';

import { env } from '../env';
import { getAppleClientSecret } from './apple-client-secret';

/**
 * Non-deliverable stand-in address for an Apple account whose id token no
 * longer carries an email. Deterministic on the Apple subject so a returning
 * user maps back to the same `users` row; `.invalid` is reserved by RFC 2606
 * and can never resolve. Apple subjects are dot-separated hex, but sanitize
 * anyway so the local part stays a valid address.
 */
const appleSubjectEmail = (sub: string) =>
  `apple-${sub.replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '').toLowerCase()}@metyro.invalid`;

export const auth = betterAuth({
  appName: 'Metyro',
  baseURL: env.BETTER_AUTH_URL,
  basePath: '/api/auth',
  secret: env.BETTER_AUTH_SECRET,
  database: drizzleAdapter(db, {
    provider: 'pg',
    schema,
    usePlural: true,
    transaction: true,
  }),
  user: {
    /**
     * Mirrors the extra `users` columns in `@via/db` — see
     * https://better-auth.com/docs/concepts/typescript#additional-fields.
     * `input: false` because these are written by the account sync endpoint,
     * never by auth requests.
     */
    additionalFields: {
      preferredModes: {
        type: 'string[]',
        required: false,
        defaultValue: [],
        input: false,
      },
      excludedModes: {
        type: 'string[]',
        required: false,
        defaultValue: [],
        input: false,
      },
      preferencesUpdatedAt: {
        type: 'date',
        required: false,
        input: false,
      },
    },
  },
  account: {
    encryptOAuthTokens: true,
  },
  session: {
    expiresIn: 30 * 24 * 60 * 60,
    updateAge: 24 * 60 * 60,
  },
  socialProviders: {
    apple: async () => ({
      clientId: env.APPLE_CLIENT_ID,
      appBundleIdentifier: env.APPLE_APP_BUNDLE_IDENTIFIER,
      clientSecret: await getAppleClientSecret(),
      mapProfileToUser: async (profile) => {
        if (profile.email && profile.name) return {};

        // Apple only sends name and email on the very first consent. Every later
        // id token carries just `sub`, so reuse the profile already linked to
        // that exact subject instead of trusting client-provided fallback data.
        const existing = await db
          .select({ email: users.email, name: users.name })
          .from(accounts)
          .innerJoin(users, eq(accounts.userId, users.id))
          .where(and(eq(accounts.providerId, 'apple'), eq(accounts.accountId, profile.sub)))
          .limit(1);

        const user = existing[0];

        // No linked row means the account was never created here (fresh
        // database, deleted account) while Apple still considers the app
        // authorised — it will never resend the email. `users.email` is NOT
        // NULL, so synthesize a stable placeholder from `sub`; Better Auth
        // reuses it to relink the same person on the next sign-in, and the
        // reserved `.invalid` TLD guarantees nothing is ever deliverable.
        return {
          email: profile.email || user?.email || appleSubjectEmail(profile.sub),
          name: profile.name || user?.name || '',
        };
      },
    }),
  },
  trustedOrigins: [env.BETTER_AUTH_URL, 'https://appleid.apple.com'],
  plugins: [
    bearer({ requireSignature: true }),
    anonymous(),
  ],
  telemetry: { enabled: false },
});

export type AuthSession = typeof auth.$Infer.Session;
