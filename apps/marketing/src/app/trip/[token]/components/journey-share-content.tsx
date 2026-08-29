import { Route as RouteIcon } from "lucide-react";
import type { ReactNode } from "react";

import { Reveal } from "@/components/ui/reveal";
import { cn } from "@/lib/utils";
import type { PublicJourneyShareResponse } from "@via/contract/public";
import type { JourneyView } from "../journey-share-types";
import { formatJourneyDate } from "../lib/format-journey-date";
import { sectionPresentation } from "../lib/section-presentation";
import { JourneyAppCallout } from "./journey-app-callout";
import { JourneyShareMap } from "./journey-share-map";
import { JourneyTimeline } from "./journey-timeline";
import { JourneyViewSwitch } from "./journey-view-switch";
import { JourneyWarnings } from "./journey-warnings";

export function JourneyShareContent({
  token,
  share,
  selectedLeg,
  locale,
  timeZone,
  view,
  onSelectLeg,
  onViewChange,
}: {
  readonly token: string;
  readonly share: PublicJourneyShareResponse;
  readonly selectedLeg: number;
  readonly locale: string;
  readonly timeZone: string;
  readonly view: JourneyView;
  readonly onSelectLeg: (index: number) => void;
  readonly onViewChange: (view: JourneyView) => void;
}): ReactNode {
  const journey = share.snapshot.journey;
  const sections = journey.sections;
  const selectedSection = sections[selectedLeg] ?? sections[0];

  return (
    <section
      aria-labelledby="journey-steps-title"
      className="px-6 py-20 sm:py-28"
    >
      <div className="mx-auto max-w-7xl">
        <div className="mb-10 flex items-end justify-between gap-8 sm:mb-14">
          <Reveal className="max-w-3xl">
            <p className="text-sm font-medium text-muted-foreground">
              Le détail
            </p>
            <h2
              id="journey-steps-title"
              className="mt-3 text-4xl leading-[1.05] font-medium tracking-tight text-balance sm:text-5xl lg:text-6xl"
            >
              Chaque étape, au{" "}
              <span className="font-serif text-accent italic">bon moment.</span>
            </h2>
            <p className="mt-5 max-w-2xl text-base leading-7 text-muted-foreground sm:text-lg">
              Sélectionnez une étape pour la retrouver immédiatement sur la
              carte.
            </p>
          </Reveal>
        </div>

        <JourneyViewSwitch view={view} onChange={onViewChange} />

        <div className="grid items-start gap-8 lg:grid-cols-[minmax(0,1.08fr)_minmax(25rem,0.92fr)] lg:gap-10">
          <section
            aria-label="Carte du trajet"
            className={cn(
              "relative h-[68svh] min-h-[32rem] overflow-hidden rounded-[2.5rem] bg-muted shadow-[0_28px_80px_rgba(0,0,0,0.12)] lg:sticky lg:top-28 lg:h-[calc(100svh-8rem)] lg:max-h-[52rem] lg:min-h-[38rem]",
              view === "details" && "hidden lg:block",
            )}
          >
            <JourneyShareMap journey={journey} selectedLeg={selectedLeg} />
            <div className="absolute top-5 left-5 max-w-[calc(100%-2.5rem)] rounded-2xl bg-frame/92 px-4 py-3 text-foreground shadow-xl/15 backdrop-blur-xl">
              <p className="text-[0.68rem] font-semibold tracking-[0.14em] text-muted-foreground uppercase">
                Étape {selectedLeg + 1} sur {sections.length}
              </p>
              <p className="mt-1 max-w-sm text-sm font-semibold text-balance">
                {selectedSection
                  ? sectionPresentation(selectedSection).title
                  : "Vue d’ensemble"}
              </p>
            </div>
            <div className="absolute bottom-5 left-5 hidden items-center gap-2 rounded-full bg-neutral-950/88 px-4 py-2 text-xs font-medium text-white shadow-xl backdrop-blur-xl sm:flex">
              <RouteIcon
                className="size-3.5 text-[#63adff]"
                aria-hidden="true"
              />
              La couleur suit chaque ligne du réseau
            </div>
          </section>

          <section
            aria-label="Détails du trajet"
            className={cn("min-w-0", view === "map" && "hidden lg:block")}
          >
            {journey.warnings.length > 0 && (
              <JourneyWarnings warnings={journey.warnings} />
            )}

            <JourneyTimeline
              journey={journey}
              selectedLeg={selectedLeg}
              locale={locale}
              timeZone={timeZone}
              onSelectLeg={onSelectLeg}
            />
            <JourneyAppCallout token={token} />

            <p className="mx-auto mt-6 max-w-md text-center text-xs leading-5 text-muted-foreground">
              Trajet calculé le{" "}
              {formatJourneyDate(share.snapshot.generatedAt, locale, timeZone)}{" "}
              · ce lien reste disponible jusqu’au{" "}
              {formatJourneyDate(share.expiresAt, locale, timeZone)}.
            </p>
          </section>
        </div>
      </div>
    </section>
  );
}
