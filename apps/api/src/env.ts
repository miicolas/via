import * as z from 'zod';

/**
 * Only the variables the API itself reads. `DATABASE_URL` is deliberately absent:
 * `packages/db` already validates and owns it, and two owners of one variable is
 * how error messages start disagreeing with each other.
 *
 * The default sits on the string rather than on the number, so it fills in before
 * the transform runs instead of leaning on coercion order.
 */
const envSchema = z.object({
  PORT: z.string().default('3000').transform(Number).pipe(z.number().int().min(1).max(65_535)),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error(`[api] invalid environment:\n${z.prettifyError(parsed.error)}`);
  throw new Error('Invalid environment. Copy .env.example to .env at the repo root.');
}

export const env = parsed.data;
