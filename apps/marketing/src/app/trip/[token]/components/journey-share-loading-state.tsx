import type { ReactNode } from "react";

export function JourneyShareLoadingState(): ReactNode {
  return (
    <main id="main-content" className="min-h-svh bg-background">
      <section className="relative mx-2.5 overflow-hidden rounded-b-[3rem] bg-card-secondary px-6 pt-40 pb-20 max-[850px]:mx-0 max-[850px]:pt-32">
        <div className="mx-auto max-w-7xl animate-pulse">
          <div className="h-8 w-36 rounded-xl bg-white/70" />
          <div className="mt-10 h-16 max-w-2xl rounded-2xl bg-white/55 sm:h-24" />
          <div className="mt-5 h-6 max-w-xl rounded-lg bg-white/45" />
          <div className="mt-10 h-72 rounded-[2.25rem] bg-white/75" />
        </div>
      </section>
      <section className="px-6 py-20 sm:py-28">
        <div className="mx-auto grid max-w-7xl animate-pulse gap-8 lg:grid-cols-[1.08fr_0.92fr]">
          <div className="h-[38rem] rounded-[2.5rem] bg-muted" />
          <div className="space-y-4 rounded-[2.5rem] bg-frame p-4">
            {[1, 2, 3, 4].map((item) => (
              <div key={item} className="h-28 rounded-[1.9rem] bg-muted" />
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}
