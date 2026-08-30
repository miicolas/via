import { createHash, createHmac } from "node:crypto";
import { eq } from "drizzle-orm";
import { db, journeyShares, type JourneyShareRow } from "@via/db";
import {
  journeyShareSnapshotSchema,
  type JourneyShareCreateInput,
  type JourneyShareCreateResponse,
  type JourneyShareResponse,
} from "@via/contract";

import { env, siteURL } from "../../env";

const SHARE_TTL_MS = 30 * 24 * 60 * 60 * 1_000;

export type JourneyShareLookupReason =
  | "not_found"
  | "expired"
  | "revoked"
  | "corrupt";

export class JourneyShareLookupError extends Error {
  constructor(readonly reason: JourneyShareLookupReason) {
    super(`Journey share lookup failed: ${reason}`);
    this.name = "JourneyShareLookupError";
  }
}

/**
 * The idempotency key is client-generated and UUID-shaped. HMACing it gives us
 * a deterministic, URL-safe token for retries without storing the raw token in
 * the database. The public value still has 256 bits of server-secret-backed
 * entropy and only its digest is persisted.
 */
function tokenFor(idempotencyKey: string): string {
  return createHmac("sha256", env.BETTER_AUTH_SECRET)
    .update(`journey-share:${idempotencyKey}`)
    .digest("base64url");
}

function tokenHash(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

function shareResponse(row: JourneyShareRow): JourneyShareResponse {
  const parsed = journeyShareSnapshotSchema.safeParse(row.snapshot);
  if (!parsed.success) throw new JourneyShareLookupError("corrupt");

  return {
    snapshot: parsed.data,
    createdAt: row.createdAt.toISOString(),
    expiresAt: row.expiresAt.toISOString(),
  };
}

function createResponse(
  row: JourneyShareRow,
  token: string,
): JourneyShareCreateResponse {
  return {
    ...shareResponse(row),
    token,
    url: siteURL(`trip/${token}`),
  };
}

export async function createJourneyShare({
  input,
  ownerUserId,
  now = new Date(),
}: {
  input: JourneyShareCreateInput;
  ownerUserId?: string;
  now?: Date;
}): Promise<JourneyShareCreateResponse> {
  const token = tokenFor(input.idempotencyKey);
  const hash = tokenHash(token);
  const expiresAt = new Date(now.getTime() + SHARE_TTL_MS);

  // A retry reads the same row and returns the same deterministic URL. If a
  // caller reuses a key after its link expired, the original expiration remains
  // authoritative rather than silently extending the public resource — hence a
  // no-op update rather than new values. Writing it as a conflicting upsert lets
  // `RETURNING` answer on both paths, so a share costs one round trip and not
  // an insert followed by a read of what we just wrote.
  const rows = await db
    .insert(journeyShares)
    .values({
      tokenHash: hash,
      idempotencyKey: input.idempotencyKey,
      ownerUserId,
      snapshot: input.snapshot as Record<string, unknown>,
      createdAt: now,
      expiresAt,
    })
    .onConflictDoUpdate({
      target: journeyShares.idempotencyKey,
      set: { idempotencyKey: input.idempotencyKey },
    })
    .returning();
  const row = rows[0];
  if (!row) throw new JourneyShareLookupError("corrupt");

  return createResponse(row, token);
}

export async function getJourneyShare(
  token: string,
  now = new Date(),
): Promise<JourneyShareResponse> {
  const rows = await db
    .select()
    .from(journeyShares)
    .where(eq(journeyShares.tokenHash, tokenHash(token)))
    .limit(1);
  const row = rows[0];

  if (!row) throw new JourneyShareLookupError("not_found");
  if (row.revokedAt) throw new JourneyShareLookupError("revoked");
  if (row.expiresAt.getTime() <= now.getTime()) {
    throw new JourneyShareLookupError("expired");
  }

  return shareResponse(row);
}
