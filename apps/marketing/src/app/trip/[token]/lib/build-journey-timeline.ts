import type { PublicJourneySection } from "@via/contract/public";
import {
  noTimelineRail,
  pedestrianTimelineRail,
  type Journey,
  type JourneyTimelineNode,
  type JourneyTimelineRailStyle,
} from "../journey-share-types";
import { cssColor } from "./css-color";

type TimelineDraft = Omit<JourneyTimelineNode, "railAbove" | "railBelow"> & {
  readonly rail: JourneyTimelineRailStyle;
};

export function buildJourneyTimeline(
  journey: Journey,
): readonly JourneyTimelineNode[] {
  let cursor = new Date(journey.departureAt).getTime();
  const schedules = journey.sections.map((section) => {
    const startsAt = section.departureAt
      ? new Date(section.departureAt).getTime()
      : cursor;
    const endsAt = section.arrivalAt
      ? new Date(section.arrivalAt).getTime()
      : startsAt + section.durationSeconds * 1_000;
    cursor = Math.max(startsAt, endsAt);
    return {
      section,
      startsAt: new Date(startsAt).toISOString(),
      endsAt: new Date(endsAt).toISOString(),
    };
  });
  const drafts: TimelineDraft[] = [];

  const railForSection = (
    section: PublicJourneySection,
  ): JourneyTimelineRailStyle =>
    section.type === "transit"
      ? {
          kind: "transit",
          color: section.route
            ? cssColor(section.route.color, "#1872f7")
            : "#1872f7",
        }
      : pedestrianTimelineRail;

  const first = schedules[0];
  if (first && first.section.type !== "transit") {
    drafts.push({
      id: "origin",
      sectionIndex: 0,
      sectionType: first.section.type,
      kind: "origin",
      eyebrow: "Départ",
      label: first.section.from.name,
      startsAt: journey.departureAt,
      endsAt: journey.departureAt,
      durationSeconds: 0,
      rail: railForSection(first.section),
      bead: "terminus",
    });
  }

  schedules.forEach(({ section, startsAt, endsAt }, sectionIndex) => {
    const rail = railForSection(section);
    const common = {
      sectionIndex,
      sectionType: section.type,
      durationSeconds: section.durationSeconds,
      rail,
    } as const;

    if (section.type !== "transit") {
      const copy = {
        walk: { eyebrow: "À pied", label: "Vers " + section.to.name },
        bike: { eyebrow: "À vélo", label: "Vers " + section.to.name },
        wait: { eyebrow: "Attente", label: "À " + section.from.name },
        transfer: {
          eyebrow: "Correspondance",
          label: "Vers " + section.to.name,
        },
        transit: { eyebrow: "Transport", label: section.to.name },
      }[section.type];

      drafts.push({
        ...common,
        id: (section.id ?? "section-" + sectionIndex) + ":movement",
        kind: "movement",
        ...copy,
        startsAt,
        endsAt,
        bead: "none",
      });
      return;
    }

    const stops = section.stops ?? [];
    const firstStop = stops[0];
    const lastStop = stops[stops.length - 1];
    const boardingName = firstStop?.name ?? section.from.name;
    const alightingName = lastStop?.name ?? section.to.name;
    const boardingAt =
      firstStop?.departureAt ?? firstStop?.arrivalAt ?? startsAt;
    const alightingAt = lastStop?.arrivalAt ?? lastStop?.departureAt ?? endsAt;
    const routeDetails = section.direction
      ? "Direction " + section.direction
      : section.route?.longName;

    drafts.push({
      ...common,
      id: (section.id ?? "section-" + sectionIndex) + ":board",
      kind: "board",
      eyebrow: section.route ? "Ligne " + section.route.shortName : "Transport",
      label: boardingName,
      ...(routeDetails ? { detail: routeDetails } : {}),
      startsAt: boardingAt,
      endsAt: boardingAt,
      bead: "major",
      ...(section.route ? { route: section.route } : {}),
    });

    stops.slice(1, -1).forEach((stop, stopIndex) => {
      const stopAt = stop.arrivalAt ?? stop.departureAt ?? startsAt;
      drafts.push({
        ...common,
        id: (section.id ?? "section-" + sectionIndex) + ":stop:" + stopIndex,
        kind: "stop",
        label: stop.name,
        startsAt: stopAt,
        endsAt: stopAt,
        bead: "minor",
        ...(section.route ? { route: section.route } : {}),
      });
    });

    drafts.push({
      ...common,
      id: (section.id ?? "section-" + sectionIndex) + ":alight",
      kind: "alight",
      eyebrow: "Descendre",
      label: alightingName,
      startsAt: alightingAt,
      endsAt: alightingAt,
      bead: "major",
      ...(section.route ? { route: section.route } : {}),
    });
  });

  const last = schedules[schedules.length - 1];
  if (last && last.section.type !== "transit") {
    drafts.push({
      id: "destination",
      sectionIndex: schedules.length - 1,
      sectionType: last.section.type,
      kind: "destination",
      eyebrow: "Arrivée",
      label: last.section.to.name,
      startsAt: journey.arrivalAt,
      endsAt: journey.arrivalAt,
      durationSeconds: 0,
      rail: railForSection(last.section),
      bead: "terminus",
    });
  }

  const gaps = drafts.slice(0, -1).map((draft, index) => {
    const next = drafts[index + 1];
    return draft.kind === "alight" && next ? next.rail : draft.rail;
  });

  return drafts.map(({ rail: _rail, ...draft }, index) => ({
    ...draft,
    railAbove:
      index === 0 ? noTimelineRail : (gaps[index - 1] ?? noTimelineRail),
    railBelow:
      index === drafts.length - 1
        ? noTimelineRail
        : (gaps[index] ?? noTimelineRail),
  }));
}
