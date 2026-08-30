import { describe, expect, it } from "bun:test";

import { canonicalInvitationToken } from "./canonical-invitation-token";

describe("invitation capability", () => {
  it("accepts only the exact opaque capability", () => {
    const token = "A".repeat(43);
    expect(canonicalInvitationToken(token)).toBe(token);
    expect(canonicalInvitationToken("a".repeat(43))).toBe("a".repeat(43));
    expect(canonicalInvitationToken("short")).toBe("");
    expect(canonicalInvitationToken("public-name")).toBe("");
  });

  it("rejects a capability carrying anything else", () => {
    const token = "A".repeat(43);
    expect(canonicalInvitationToken(`${token}#k=secret`)).toBe("");
    expect(canonicalInvitationToken(`${token}/extra`)).toBe("");
  });
});
