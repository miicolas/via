import type { ReactNode } from "react";

import { LaunchAction } from "@/components/ui/launch-action";
import { SplitActionLink } from "@/components/ui/split-action-link";

export function JourneyAppCallout({
  token,
}: {
  readonly token: string;
}): ReactNode {
  return (
    <section className="relative mt-8 overflow-hidden rounded-[2.5rem] bg-accent p-7 text-white sm:p-8">
      <div
        className="absolute -top-24 -right-20 size-64 rounded-full bg-white/16 blur-3xl"
        aria-hidden="true"
      />
      <div className="relative">
        <p className="text-sm font-medium text-white/70">Sur votre iPhone</p>
        <h3 className="mt-3 max-w-md text-3xl leading-tight font-medium tracking-tight text-balance">
          Gardez le trajet avec vous, jusqu’à l’arrivée.
        </h3>
        <p className="mt-4 max-w-md text-sm leading-6 text-white/75">
          Ouvrez-le dans Metyro pour retrouver le suivi complet et préparer vos
          prochains déplacements.
        </p>
        <div className="mt-7 flex flex-wrap items-center gap-4">
          <SplitActionLink
            label="Ouvrir dans l’app"
            href={"via://trip/" + token}
            tone="dark"
          />
          <LaunchAction mode="badge" appearance="black" />
        </div>
      </div>
    </section>
  );
}
