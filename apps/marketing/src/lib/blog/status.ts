import type { ArticleFrontmatter } from "./schema";

/**
 * Où en sont les travaux dont parle l’article, maintenant.
 *
 * Dérivé, jamais écrit : un article publié en juillet dit « à venir » en
 * juillet et « terminé » en octobre sans que personne n’y touche. C’est ce qui
 * permet de ne jamais supprimer une URL — un chantier fini garde sa page, avec
 * un bandeau qui le dit et un lien vers la suite.
 */
export type ArticleStatus = "upcoming" | "ongoing" | "ended" | "open-ended";

export const statusLabels: Record<ArticleStatus, string> = {
  upcoming: "À venir",
  ongoing: "En cours",
  ended: "Terminé",
  "open-ended": "En cours",
};

/**
 * Les dates du frontmatter sont des jours, pas des instants. On compare donc
 * des jours : un chantier qui finit le 24 août est encore en cours le 24 août
 * au soir, ce qu’un `Date` à minuit ferait mentir.
 */
export function articleStatus(
  frontmatter: Pick<ArticleFrontmatter, "validFrom" | "validUntil">,
  today: string,
): ArticleStatus {
  if (today < frontmatter.validFrom) return "upcoming";
  if (!frontmatter.validUntil) return "open-ended";
  return today > frontmatter.validUntil ? "ended" : "ongoing";
}

/** Le jour courant à Paris, en `AAAA-MM-JJ` — la même échelle que le frontmatter. */
export function parisToday(now: Date = new Date()): string {
  return new Intl.DateTimeFormat("fr-CA", {
    timeZone: "Europe/Paris",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

const MONTH = new Intl.DateTimeFormat("fr-FR", {
  timeZone: "UTC",
  month: "long",
});

/**
 * Le quantième, en français : le premier du mois est « 1er », tout le reste est
 * un cardinal. `Intl` ne le fait pas pour les dates, et « le 1 novembre » se
 * voit immédiatement.
 */
function dayLabel(isoDay: string): string {
  const day = Number(isoDay.slice(8, 10));
  return day === 1 ? "1er" : String(day);
}

function monthLabel(isoDay: string): string {
  // Midi UTC : aucun décalage horaire ne peut faire changer de jour.
  return MONTH.format(new Date(`${isoDay}T12:00:00Z`));
}

/** « 22 juillet 2026 ». */
export function formatLongDate(isoDay: string): string {
  return `${dayLabel(isoDay)} ${monthLabel(isoDay)} ${isoDay.slice(0, 4)}`;
}

/**
 * « du 24 au 27 septembre 2026 », « du 29 octobre au 1er novembre 2026 » :
 * l’année ne s’écrit qu’une fois, et le mois seulement quand il change.
 */
export function formatDateRange(from: string, to: string): string {
  if (from === to) return formatLongDate(from);

  const sameYear = from.slice(0, 4) === to.slice(0, 4);
  const sameMonth = sameYear && from.slice(0, 7) === to.slice(0, 7);

  if (sameMonth) return `du ${dayLabel(from)} au ${formatLongDate(to)}`;
  if (sameYear) {
    return `du ${dayLabel(from)} ${monthLabel(from)} au ${formatLongDate(to)}`;
  }
  return `du ${formatLongDate(from)} au ${formatLongDate(to)}`;
}
