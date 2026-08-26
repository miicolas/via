import { expect, test } from "bun:test";

import { buildLineStrip, LineStripError } from "./line-strip-data";

test("une station traversée sans arrêt est fermée, mais la ligne reste continue", () => {
  const strip = buildLineStrip({
    line: "m8",
    impactedSections: [{ line: "m8", only: "République" }],
  });

  const republique = strip.stops.find((stop) => stop.name === "République");
  expect(republique?.state).toBe("closed");
  // Les rames passent : aucun tronçon n'est coupé.
  expect(strip.cut.some(Boolean)).toBe(false);
  expect(strip.description).toBe("Ligne 8 : République n’est pas desservie.");
});

test("un tronçon coupé ferme ses bornes et tout ce qui est entre elles", () => {
  const strip = buildLineStrip({
    line: "m8",
    impactedSections: [{ line: "m8", from: "Balard", to: "Concorde" }],
  });

  // La direction 0 va de Pointe du Lac à Balard : Concorde vient donc avant.
  const closed = strip.stops.filter((stop) => stop.state === "closed").map((stop) => stop.name);
  expect(closed[0]).toBe("Concorde");
  expect(closed[closed.length - 1]).toBe("Balard");
  expect(closed.length).toBeGreaterThan(2);
  expect(strip.cut.filter(Boolean).length).toBe(closed.length - 1);
});

test("une station mal orthographiée casse le build plutôt que de passer inaperçue", () => {
  expect(() =>
    buildLineStrip({
      line: "m8",
      impactedSections: [{ line: "m8", only: "Republic" }],
    }),
  ).toThrow(LineStripError);
});

test("les accents et la ponctuation ne décident pas d’une correspondance", () => {
  const strip = buildLineStrip({
    line: "m8",
    impactedSections: [{ line: "m8", only: "republique" }],
  });

  expect(strip.stops.find((stop) => stop.name === "République")?.state).toBe("closed");
});

test("une ligne que le référentiel ne connaît pas se déclare dans l’article", () => {
  const strip = buildLineStrip({
    line: "m18",
    impactedSections: [],
    declaredStops: [
      { name: "Massy - Palaiseau", isInterchange: true },
      { name: "Polytechnique" },
      { name: "Christ de Saclay" },
    ],
  });

  expect(strip.stops.map((stop) => stop.name)).toEqual([
    "Massy - Palaiseau",
    "Polytechnique",
    "Christ de Saclay",
  ]);
  expect(strip.segments).toHaveLength(1);
});

test("une ligne absente et non déclarée échoue au lieu de dessiner une bande vide", () => {
  expect(() => buildLineStrip({ line: "m18", impactedSections: [] })).toThrow(LineStripError);
});

test("une ligne longue n’est dessinée qu’autour de ce qui est fermé", () => {
  const strip = buildLineStrip({
    line: "m8",
    impactedSections: [{ line: "m8", only: "République" }],
  });

  const dessines = strip.segments.reduce((total, segment) => total + segment.stops.length, 0);
  expect(strip.stops.length).toBeGreaterThan(30);
  expect(dessines).toBeLessThan(10);

  // Ce qui est escamoté est compté, jamais tu.
  const [segment] = strip.segments;
  expect((segment?.gapBefore?.hidden ?? 0) + (segment?.gapAfter?.hidden ?? 0)).toBe(
    strip.stops.length - dessines,
  );
});

test("la bande ne relie pas deux stations de branches différentes", () => {
  const strip = buildLineStrip({ line: "m13", impactedSections: [] });

  // Sur la 13 aplatie, la branche Saint-Denis finit à Guy Môquet et la branche
  // Asnières commence aux Courtilles : les deux se suivent dans la liste sans
  // se toucher sur le terrain.
  const courtilles = strip.stops.findIndex((stop) =>
    stop.name.startsWith("Asnières - Gennevilliers"),
  );
  expect(courtilles).toBeGreaterThan(0);
  expect(strip.stops[courtilles]?.startsSection).toBe(true);
});

test("aucun tronçon coupé n’est dessiné par-dessus une jonction de branches", () => {
  const strip = buildLineStrip({
    line: "m13",
    impactedSections: [{ line: "m13", from: "Guy Môquet", to: "Les Agnettes" }],
  });

  const jonction = strip.stops.findIndex((stop) => stop.startsSection === true);
  expect(strip.cut[jonction - 1]).not.toBe(true);
});
