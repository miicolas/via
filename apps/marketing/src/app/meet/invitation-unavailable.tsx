import type { ReactNode } from "react";

/**
 * The API answered, but not with an invitation we can render. Both invitation
 * surfaces reach this state the same way and said the same sentence twice —
 * differing only by an article — so the wording lives here.
 */
export function InvitationUnavailable({ eyebrow }: { readonly eyebrow: string }): ReactNode {
  return (
    <main id="main-content" className="min-h-svh bg-background px-6 py-24 text-foreground">
      <section className="mx-auto max-w-2xl rounded-[2.5rem] bg-white p-8 shadow-sm dark:bg-neutral-900">
        <p className="text-sm font-medium text-muted-foreground">{eyebrow}</p>
        <h1 className="mt-3 text-4xl font-medium tracking-tight">Invitation indisponible</h1>
        <p className="mt-4 text-muted-foreground">Réessayez dans quelques instants.</p>
      </section>
    </main>
  );
}
