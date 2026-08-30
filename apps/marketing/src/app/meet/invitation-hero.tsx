import type { ReactNode } from "react";

/** The card both invitation pages render once the preview has loaded. */
export function InvitationHero({
  eyebrow,
  title,
  detail,
  status,
  children,
}: {
  readonly eyebrow: string;
  readonly title: ReactNode;
  readonly detail: string;
  readonly status: string;
  readonly children?: ReactNode;
}): ReactNode {
  return (
    <main id="main-content" className="min-h-svh bg-background px-6 py-20 text-foreground">
      <section className="mx-auto max-w-3xl overflow-hidden rounded-[2.5rem] bg-accent p-8 text-white shadow-xl sm:p-12">
        <p className="text-sm font-medium text-white/70">{eyebrow}</p>
        <h1 className="mt-4 text-4xl leading-tight font-medium tracking-tight sm:text-6xl">
          {title}
        </h1>
        <p className="mt-5 text-lg text-white/80">{detail}</p>
        <p className="mt-8 inline-flex rounded-full bg-white/15 px-4 py-2 text-sm font-medium">
          {status}
        </p>
        {children}
      </section>
    </main>
  );
}
