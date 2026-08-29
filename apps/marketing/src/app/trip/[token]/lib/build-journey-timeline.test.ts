import { expect, test } from "bun:test";

import type { Journey } from "../journey-share-types";
import { buildJourneyTimeline } from "./build-journey-timeline";

const journey = {
  durationSeconds: 900,
  walkingDurationSeconds: 0,
  transferCount: 0,
  departureAt: "2026-08-29T08:00:00+02:00",
  arrivalAt: "2026-08-29T08:15:00+02:00",
  status: "normal",
  warnings: [],
  sections: [
    {
      id: "metro-1",
      type: "transit",
      durationSeconds: 900,
      from: {
        name: "La Défense",
        coordinate: { latitude: 48.8918, longitude: 2.2381 },
      },
      to: {
        name: "Nation",
        coordinate: { latitude: 48.8484, longitude: 2.3958 },
      },
      departureAt: "2026-08-29T08:00:00+02:00",
      arrivalAt: "2026-08-29T08:15:00+02:00",
      geometry: [],
      stops: [
        {
          name: "La Défense",
          departureAt: "2026-08-29T08:00:00+02:00",
        },
        {
          name: "Charles de Gaulle — Étoile",
          arrivalAt: "2026-08-29T08:06:00+02:00",
        },
        {
          name: "Nation",
          arrivalAt: "2026-08-29T08:15:00+02:00",
        },
      ],
      route: {
        shortName: "1",
        longName: "Métro 1",
        color: "#ffcd00",
        textColor: "#111111",
      },
      direction: "Château de Vincennes",
    },
  ],
} satisfies Journey;

test("builds the iOS-style continuous rail through intermediate stops", () => {
  const nodes = buildJourneyTimeline(journey);

  expect(nodes.map(({ kind, label, bead }) => ({ kind, label, bead }))).toEqual(
    [
      { kind: "board", label: "La Défense", bead: "major" },
      {
        kind: "stop",
        label: "Charles de Gaulle — Étoile",
        bead: "minor",
      },
      { kind: "alight", label: "Nation", bead: "major" },
    ],
  );
  expect(nodes[0]?.railAbove).toEqual({ kind: "none" });
  expect(nodes[0]?.railBelow).toEqual({ kind: "transit", color: "#ffcd00" });
  expect(nodes[1]?.railAbove).toEqual({ kind: "transit", color: "#ffcd00" });
  expect(nodes[1]?.railBelow).toEqual({ kind: "transit", color: "#ffcd00" });
  expect(nodes[2]?.railAbove).toEqual({ kind: "transit", color: "#ffcd00" });
  expect(nodes[2]?.railBelow).toEqual({ kind: "none" });
});
