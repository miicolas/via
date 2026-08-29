import type { PublicJourneySection } from "@via/contract/public";

export function sectionPresentation(section: PublicJourneySection): {
  readonly eyebrow: string;
  readonly title: string;
} {
  if (section.route) {
    return {
      eyebrow: "Ligne " + section.route.shortName,
      title: section.direction ?? section.route.longName,
    };
  }

  switch (section.type) {
    case "wait":
      return { eyebrow: "Attente", title: "À " + section.from.name };
    case "transfer":
      return {
        eyebrow: "Correspondance",
        title: "Vers " + section.to.name,
      };
    case "walk":
      return { eyebrow: "À pied", title: "Vers " + section.to.name };
    case "bike":
      return { eyebrow: "À vélo", title: "Vers " + section.to.name };
    case "transit":
      return { eyebrow: "Transport", title: section.to.name };
  }
}
