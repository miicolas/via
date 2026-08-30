import { Hono } from 'hono';

import type { AppEnv } from '../http/app-env';
import { errorBody } from '../http/errors';

/**
 * The four ways a capability link can fail, and the one status each maps to.
 *
 * Every `/public` capability route answers the same way, because nothing but a
 * shared table forces them to agree: a link that has expired is `410 Gone` —
 * it existed, it will not come back — while a revoked link and a wrong guess
 * are both `404`, so an outsider cannot tell revocation from a bad token by
 * status alone. `corrupt` is the stored payload failing validation: the
 * caller's request was fine, so it is `503`, not a `4xx`.
 */
export type CapabilityLinkOutcome = 'not_found' | 'revoked' | 'expired' | 'corrupt';

const OUTCOME_STATUS = {
  not_found: 404,
  revoked: 404,
  expired: 410,
  corrupt: 503,
} as const satisfies Record<CapabilityLinkOutcome, 404 | 410 | 503>;

/** A service error reason lands on an outcome; anything unforeseen is a 404. */
function outcomeOf(reason: string): CapabilityLinkOutcome {
  return reason === 'expired' || reason === 'revoked' || reason === 'corrupt'
    ? reason
    : 'not_found';
}

export type CapabilityLinkConfig<Loaded> = {
  /** Contract schema for the URL token; a value it rejects is a `not_found`. */
  tokenSchema: {
    safeParse: (value: unknown) => { success: true; data: string } | { success: false };
  };
  /** Service lookup; anything it throws beyond the service error re-throws. */
  load: (token: string) => Promise<Loaded>;
  /** The hand-written ADR-0003 projection to the public shape. */
  project: (loaded: Loaded) => unknown;
  /** Narrows a thrown value to this resource's service error. */
  isServiceError: (error: unknown) => error is Error & { reason: string };
  /** Code and wording per outcome; the table above owns the statuses. */
  errors: Record<CapabilityLinkOutcome, { code: string; message: string }>;
  /** `Cache-Control` for the success response. */
  cacheControl: string;
};

/**
 * `GET /:token` for a capability link: parse the opaque token, load through
 * the resource's service, answer with its projection. Written per resource,
 * the copies differed on nothing but their strings — until they differed on
 * their statuses too, and an expired invitation was a 404 while an expired
 * trip link was a 410. One router, one status table, no way to disagree.
 */
export function capabilityLinkRouter<Loaded>(config: CapabilityLinkConfig<Loaded>) {
  return new Hono<AppEnv>().get('/:token', async (c) => {
    const answer = (outcome: CapabilityLinkOutcome) => {
      const { code, message } = config.errors[outcome];
      return c.json(errorBody(c, code, message), OUTCOME_STATUS[outcome]);
    };

    const token = config.tokenSchema.safeParse(c.req.param('token'));
    if (!token.success) return answer('not_found');

    try {
      const loaded = await config.load(token.data);
      c.header('Cache-Control', config.cacheControl);
      return c.json(config.project(loaded));
    } catch (error) {
      if (!config.isServiceError(error)) throw error;
      return answer(outcomeOf(error.reason));
    }
  });
}
