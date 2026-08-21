import { and, eq } from 'drizzle-orm';
import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { anonymous, bearer } from 'better-auth/plugins';
import { accounts, db, schema, users } from '@via/db';

import { env } from '../env';
import { getAppleClientSecret } from './apple-client-secret';

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

        // Apple can omit both values after the first consent. Better Auth still
        // requires an email, so reuse only the profile already linked to this
        // exact Apple subject instead of trusting client-provided fallback data.
        const existing = await db
          .select({ email: users.email, name: users.name })
          .from(accounts)
          .innerJoin(users, eq(accounts.userId, users.id))
          .where(and(eq(accounts.providerId, 'apple'), eq(accounts.accountId, profile.sub)))
          .limit(1);

        const user = existing[0];
        return user
          ? {
              email: profile.email || user.email,
              name: profile.name || user.name,
            }
          : {};
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
