import { apiOrigin, boundedApiSignal, serverHeaders } from "@/lib/api";

/**
 * The public preview behind an invitation link, for Rendez-vous and for
 * friends alike. Both surfaces answer the same three outcomes over the same
 * opaque capability, so the fetch — its cache policy, its timeout, and the
 * decision that an unparseable body is "unavailable" rather than "not found"
 * — is written once here. Two copies drifted on the cache header alone.
 */
export type InvitationResult<T> =
  | { readonly kind: "ready"; readonly invitation: T }
  | { readonly kind: "notFound" | "unavailable" };

/** Matches the `Cache-Control: max-age=30` the public routers answer with. */
const INVITATION_REVALIDATE_SECONDS = 30;

export async function fetchInvitation<T>({
  path,
  token,
  schema,
  signal,
}: {
  path: string;
  token: string;
  /** Structural, so the caller's concrete zod object needs no coercion. */
  schema: { safeParse: (value: unknown) => { success: true; data: T } | { success: false } };
  signal?: AbortSignal | undefined;
}): Promise<InvitationResult<T>> {
  const origin = apiOrigin();
  if (!origin) return { kind: "unavailable" };
  if (!token) return { kind: "notFound" };

  let response: Response;
  try {
    response = await fetch(`${origin}/${path}/${encodeURIComponent(token)}`, {
      headers: serverHeaders(),
      signal: boundedApiSignal(signal),
      next: { revalidate: INVITATION_REVALIDATE_SECONDS },
    });
  } catch {
    return { kind: "unavailable" };
  }
  if (response.status === 404) return { kind: "notFound" };
  if (!response.ok) return { kind: "unavailable" };

  const parsed = schema.safeParse(await response.json().catch(() => null));
  return parsed.success
    ? { kind: "ready", invitation: parsed.data }
    : { kind: "unavailable" };
}
