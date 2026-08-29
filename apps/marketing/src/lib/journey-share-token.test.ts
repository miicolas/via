import { expect, test } from "bun:test";

import { canonicalJourneyShareToken } from "./journey-share-token";

const token = "A".repeat(43);
const legacyMessage = " Voici un trajet partagé dans Metyro.";

test("un ancien lien ShareLink retrouve son token après encodage web", () => {
  expect(
    canonicalJourneyShareToken(`${token}${encodeURIComponent(legacyMessage)}`),
  ).toBe(token);
  expect(
    canonicalJourneyShareToken(
      `${token}${encodeURIComponent(encodeURIComponent(legacyMessage))}`,
    ),
  ).toBe(token);
});

test("le message déjà décodé est retiré lui aussi", () => {
  expect(canonicalJourneyShareToken(`${token}${legacyMessage}`)).toBe(token);
});

test("un suffixe inconnu ne transforme pas une route invalide en trajet valide", () => {
  const invalid = `${token} autre contenu`;
  expect(canonicalJourneyShareToken(invalid)).toBe(invalid);
});
