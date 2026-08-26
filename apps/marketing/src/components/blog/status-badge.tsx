import { statusLabels, type ArticleStatus } from "@/lib/blog/status";
import type { CSSProperties, ReactNode } from "react";

const accents: Record<ArticleStatus, string> = {
  upcoming: "var(--accent)",
  ongoing: "#d97706",
  "open-ended": "#d97706",
  ended: "var(--muted-foreground)",
};

/**
 * Où en sont les travaux, calculé et non écrit.
 *
 * C’est ce badge qui autorise à ne jamais supprimer une URL : un article de
 * juillet passe tout seul de « À venir » à « En cours » puis à « Terminé »,
 * sans que personne n’y revienne, et sans jamais mentir au lecteur.
 */
export function StatusBadge({
  status,
  className = "",
}: {
  readonly status: ArticleStatus;
  readonly className?: string;
}): ReactNode {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full bg-[color-mix(in_srgb,var(--status)_12%,transparent)] px-2.5 py-1 text-xs font-semibold text-[var(--status)] ${className}`}
      style={{ "--status": accents[status] } as CSSProperties}
    >
      <span className="size-1.5 rounded-full bg-[var(--status)]" aria-hidden="true" />
      {statusLabels[status]}
    </span>
  );
}
