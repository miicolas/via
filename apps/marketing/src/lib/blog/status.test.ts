import { expect, test } from "bun:test";

import { articleStatus, formatDateRange, formatLongDate } from "./status";

const chantier = { validFrom: "2026-09-24", validUntil: "2026-11-29" };

test("un chantier bascule tout seul d’à venir à en cours puis à terminé", () => {
  expect(articleStatus(chantier, "2026-09-01")).toBe("upcoming");
  expect(articleStatus(chantier, "2026-10-15")).toBe("ongoing");
  expect(articleStatus(chantier, "2026-12-01")).toBe("ended");
});

test("les bornes sont incluses : le dernier jour, c’est encore en cours", () => {
  expect(articleStatus(chantier, "2026-09-24")).toBe("ongoing");
  expect(articleStatus(chantier, "2026-11-29")).toBe("ongoing");
});

test("sans date de fin, un chantier reste en cours plutôt que de se dire terminé", () => {
  expect(articleStatus({ validFrom: "2026-07-22" }, "2027-06-01")).toBe("open-ended");
  expect(articleStatus({ validFrom: "2026-07-22" }, "2026-01-01")).toBe("upcoming");
});

test("le premier du mois s’écrit « 1er »", () => {
  expect(formatLongDate("2026-11-01")).toBe("1er novembre 2026");
  expect(formatLongDate("2026-11-02")).toBe("2 novembre 2026");
});

test("une plage ne répète ni le mois ni l’année quand ils ne changent pas", () => {
  expect(formatDateRange("2026-09-24", "2026-09-27")).toBe("du 24 au 27 septembre 2026");
  expect(formatDateRange("2026-10-29", "2026-11-01")).toBe("du 29 octobre au 1er novembre 2026");
  expect(formatDateRange("2026-12-30", "2027-01-02")).toBe(
    "du 30 décembre 2026 au 2 janvier 2027",
  );
});

test("une plage d’un seul jour ne dit pas « du … au … »", () => {
  expect(formatDateRange("2026-09-24", "2026-09-24")).toBe("24 septembre 2026");
});
