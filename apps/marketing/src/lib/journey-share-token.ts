const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const LEGACY_SHARE_MESSAGE = " Voici un trajet partagé dans Metyro.";
const MAX_DECODE_PASSES = 2;

/**
 * Some share destinations concatenated ShareLink's optional message to the URL
 * and then encoded that text once more while opening it. Keep accepting only
 * that exact historical suffix: an arbitrary trailing value must stay invalid.
 */
export function canonicalJourneyShareToken(value: string): string {
  let candidate = value;

  for (let pass = 0; pass <= MAX_DECODE_PASSES; pass += 1) {
    if (TOKEN_PATTERN.test(candidate)) return candidate;

    if (candidate.endsWith(LEGACY_SHARE_MESSAGE)) {
      const token = candidate.slice(0, -LEGACY_SHARE_MESSAGE.length);
      if (TOKEN_PATTERN.test(token)) return token;
    }

    if (pass === MAX_DECODE_PASSES) break;

    try {
      const decoded = decodeURIComponent(candidate);
      if (decoded === candidate) break;
      candidate = decoded;
    } catch {
      break;
    }
  }

  return value;
}
