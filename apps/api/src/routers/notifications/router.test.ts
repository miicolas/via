import { expect, test } from "bun:test";

import { activeJourneyRouteWindows } from "../../notifications/journey-subscriptions";
import { validateActiveJourneyWindow } from "./router";

const now = new Date("2026-08-21T12:00:00Z");

test("active journey registrations stay inside a bounded current window", () => {
  expect(() =>
    validateActiveJourneyWindow(
      {
        startsAt: "2026-08-21T11:55:00Z",
        endsAt: "2026-08-21T13:00:00Z",
      },
      now,
    ),
  ).not.toThrow();

  expect(() =>
    validateActiveJourneyWindow(
      {
        startsAt: "2026-08-21T12:00:00Z",
        endsAt: "2026-09-21T12:00:00Z",
      },
      now,
    ),
  ).toThrow();

  expect(() =>
    validateActiveJourneyWindow(
      {
        startsAt: "2026-08-20T10:00:00Z",
        endsAt: "2026-08-21T13:00:00Z",
      },
      now,
    ),
  ).toThrow();
});

test("legacy route IDs become journey-wide route windows", () => {
  expect(
    activeJourneyRouteWindows({
      installationId: "018f6f3e-22f1-7b3c-8f52-54b65c6a2c63",
      journeyId: "legacy,journey",
      routeWindows: [],
      routeIds: ["IDFM:C01371"],
      startsAt: "2026-08-21T12:00:00Z",
      endsAt: "2026-08-21T13:00:00Z",
    }),
  ).toEqual([
    {
      routeId: "IDFM:C01371",
      startsAt: "2026-08-21T12:00:00Z",
      endsAt: "2026-08-21T13:00:00Z",
    },
  ]);
});
