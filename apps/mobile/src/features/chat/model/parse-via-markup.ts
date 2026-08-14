/**
 * Via's answers carry a two-token markup the server prompt enforces:
 * `{{11}}` marks a transit line, `__République__` marks a place. This parser
 * turns an answer into renderable segments.
 */

export type ViaMarkupSegment =
  | { type: 'text'; value: string }
  | { type: 'line'; value: string }
  | { type: 'place'; value: string };

const TOKEN_PATTERN = /\{\{([^{}]{1,14})\}\}|__([^_]{1,60})__/g;

export function parseViaMarkup(text: string): ViaMarkupSegment[] {
  const segments: ViaMarkupSegment[] = [];
  let cursor = 0;
  for (const match of text.matchAll(TOKEN_PATTERN)) {
    if (match.index > cursor) segments.push({ type: 'text', value: text.slice(cursor, match.index) });
    if (match[1] !== undefined) segments.push({ type: 'line', value: match[1].trim() });
    else segments.push({ type: 'place', value: match[2]!.trim() });
    cursor = match.index + match[0].length;
  }
  if (cursor < text.length) segments.push({ type: 'text', value: text.slice(cursor) });
  return segments;
}
