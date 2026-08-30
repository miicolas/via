import { CAPABILITY_TOKEN_PATTERN } from "@via/contract";

/**
 * An invitation capability survives the round trip only if it is exactly the
 * shape the API mints. Anything else — a truncated paste, a share sheet that
 * appended its own text, a fragment key that leaked into the path — becomes
 * the empty string, which every caller renders as "introuvable".
 */
export function canonicalInvitationToken(value: string): string {
  return CAPABILITY_TOKEN_PATTERN.test(value) ? value : "";
}
