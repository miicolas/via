import { RefreshCw, Share2 } from "lucide-react";
import Link from "next/link";
import type { ReactNode } from "react";

import { ActionButton } from "@/components/ui/action-button";
import type { JourneyShareErrorCode } from "@/lib/journey-share";

export function JourneyShareErrorState({
  code,
  onRetry,
}: {
  readonly code: JourneyShareErrorCode;
  readonly onRetry: () => void;
}): ReactNode {
  const { title, body, permanent } = {
    journey_share_not_found: {
      title: "Trajet introuvable",
      body: "Ce lien ne correspond à aucun trajet partagé.",
      permanent: true,
    },
    journey_share_expired: {
      title: "Lien expiré",
      body: "Ce lien de trajet n’est plus disponible.",
      permanent: true,
    },
    journey_share_revoked: {
      title: "Lien supprimé",
      body: "L’expéditeur a supprimé ce trajet partagé.",
      permanent: true,
    },
    journey_share_unavailable: {
      title: "Trajet indisponible",
      body: "Le trajet ne peut pas être chargé pour le moment.",
      permanent: false,
    },
    unavailable: {
      title: "Connexion impossible",
      body: "Vérifiez votre connexion puis réessayez.",
      permanent: false,
    },
  }[code];

  return (
    <main
      id="main-content"
      className="grid min-h-svh place-items-center px-6 pt-36 pb-20"
    >
      <section className="w-full max-w-4xl rounded-[3rem] bg-card-secondary px-6 py-16 text-center sm:px-12 sm:py-24">
        <div className="mx-auto grid size-14 place-items-center rounded-2xl bg-accent text-white shadow-lg">
          {permanent ? (
            <Share2 className="size-6" aria-hidden="true" />
          ) : (
            <RefreshCw className="size-6" aria-hidden="true" />
          )}
        </div>
        <p className="mt-6 text-sm font-medium text-muted-foreground">
          Trajet partagé <span className="text-accent">✦</span>
        </p>
        <h1 className="mx-auto mt-4 max-w-3xl text-5xl leading-[1.02] font-medium tracking-tight text-balance sm:text-7xl">
          {title}
        </h1>
        <p className="mx-auto mt-6 max-w-xl text-base leading-7 text-muted-foreground sm:text-lg">
          {body}
        </p>
        <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
          {!permanent && (
            <ActionButton
              type="button"
              onClick={onRetry}
              className="inline-flex min-h-11 items-center gap-2 px-5"
            >
              <RefreshCw className="size-4" aria-hidden="true" />
              Réessayer
            </ActionButton>
          )}
          <Link
            href="/"
            className="focus-ring inline-flex min-h-11 items-center justify-center rounded-xl border border-foreground/10 bg-frame px-5 text-sm font-semibold transition-colors hover:bg-muted"
          >
            Découvrir Metyro
          </Link>
        </div>
      </section>
    </main>
  );
}
