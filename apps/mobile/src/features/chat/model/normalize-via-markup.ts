const MODE_LINE_PATTERN =
  /\b(métro|metro|rer|tram|bus|ligne)\s+([a-z]?\d{1,4}(?:-\d{1,2})?[a-z]?|[a-z])\b/gi;

const MODE_HINTS: Record<string, string> = {
  métro: 'metro',
  metro: 'metro',
  rer: 'rer',
  tram: 'tram',
  bus: 'bus',
};

/**
 * Belt-and-braces cleanup of a Via answer before parsing: the prompt forbids
 * Markdown and demands `{{11}}` line tokens, but a disobedient completion must
 * still render cleanly. Strips bold/italic markers and rewrites plain
 * "métro 1" / "RER A" mentions into line tokens carrying a mode hint
 * (`{{metro:1}}`) so the right badge can be picked.
 */
export function normalizeViaMarkup(text: string): string {
  return text
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/\*([^*\n]+)\*/g, '$1')
    .replace(MODE_LINE_PATTERN, (_full, mode: string, line: string) => {
      const hint = MODE_HINTS[mode.toLowerCase()];
      return `{{${hint ? `${hint}:` : ''}${line.toUpperCase()}}}`;
    });
}
