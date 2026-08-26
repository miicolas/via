import { transitLines } from "@/constants/transit";
import type { ArticleLineKey } from "@/lib/blog/schema";
import type { ArticleStatus } from "@/lib/blog/status";
import { Archive } from "lucide-react";
import Link from "next/link";
import type { ReactNode } from "react";

/**
 * Le bandeau d’un chantier terminé.
 *
 * On ne supprime jamais l’URL d’un article périmé : elle porte des liens et un
 * classement que rien ne remplace, et quelqu’un peut légitimement chercher ce
 * qui s’est passé l’an dernier. Mais la page doit le dire avant sa première
 * phrase, et renvoyer vers ce qui concerne le lecteur aujourd’hui — c’est le
 * hub de la ligne, qui ne périme pas.
 */
export function EndedBanner({
  status,
  lines,
}: {
  readonly status: ArticleStatus;
  readonly lines: readonly ArticleLineKey[];
}): ReactNode {
  if (status !== "ended") return null;

  const first = lines[0];

  return (
    <p className="mt-10 flex flex-wrap items-center gap-x-2 gap-y-1 rounded-2xl border border-foreground/10 bg-muted/60 px-5 py-4 leading-7">
      <Archive className="size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
      <span className="font-medium text-foreground">Ces travaux sont terminés.</span>
      <span className="text-muted-foreground">
        Cette page est conservée pour mémoire.
      </span>
      {first && (
        <Link
          href={`/blog/ligne/${first}`}
          className="focus-ring text-foreground underline decoration-accent/50 underline-offset-4 transition-colors hover:decoration-accent"
        >
          Voir l’état actuel de la ligne {transitLines[first].shortName} →
        </Link>
      )}
    </p>
  );
}
