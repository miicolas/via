import type {
  PublicJourneySection,
  PublicJourneyShareResponse,
} from "@via/contract/public";
import {
  ArrowRightLeft,
  Bike,
  Clock3,
  Footprints,
  TrainFront,
  type LucideIcon,
} from "lucide-react";

export type Coordinate = {
  readonly latitude: number;
  readonly longitude: number;
};

export type MapCoordinate = [number, number];
export type Journey = PublicJourneyShareResponse["snapshot"]["journey"];
export type JourneyView = "map" | "details";
export type JourneyTimelineRailStyle =
  | { readonly kind: "none" }
  | { readonly kind: "pedestrian" }
  | { readonly kind: "transit"; readonly color: string };

export type JourneyTimelineNode = {
  readonly id: string;
  readonly sectionIndex: number;
  readonly sectionType: PublicJourneySection["type"];
  readonly kind:
    "origin" | "destination" | "movement" | "board" | "stop" | "alight";
  readonly eyebrow?: string;
  readonly label: string;
  readonly detail?: string;
  readonly startsAt: string;
  readonly endsAt: string;
  readonly durationSeconds: number;
  readonly railAbove: JourneyTimelineRailStyle;
  readonly railBelow: JourneyTimelineRailStyle;
  readonly bead: "terminus" | "major" | "minor" | "none";
  readonly route?: NonNullable<PublicJourneySection["route"]>;
};

export type JourneyStatusAppearance = {
  readonly label: string;
  readonly className: string;
  readonly dotClassName: string;
};

export const sectionTypeColors: Record<PublicJourneySection["type"], string> = {
  walk: "#64748b",
  bike: "#059669",
  wait: "#8b5cf6",
  transfer: "#f59e0b",
  transit: "#1872f7",
};

export const sectionTypeIcons: Record<
  PublicJourneySection["type"],
  LucideIcon
> = {
  walk: Footprints,
  bike: Bike,
  wait: Clock3,
  transfer: ArrowRightLeft,
  transit: TrainFront,
};

export const noTimelineRail: JourneyTimelineRailStyle = { kind: "none" };
export const pedestrianTimelineRail: JourneyTimelineRailStyle = {
  kind: "pedestrian",
};

export const journeyStatusAppearances: Record<
  Journey["status"],
  JourneyStatusAppearance
> = {
  disrupted: {
    label: "Trajet perturbé",
    className: "bg-red-50 text-red-700",
    dotClassName: "bg-red-500",
  },
  theoretical: {
    label: "Horaires théoriques",
    className: "bg-amber-50 text-amber-800",
    dotClassName: "bg-amber-500",
  },
  normal: {
    label: "Trajet normal",
    className: "bg-emerald-50 text-emerald-700",
    dotClassName: "bg-emerald-500",
  },
};
