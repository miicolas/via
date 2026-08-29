export function splitPlaceName(value: string): {
  readonly primary: string;
  readonly context?: string;
} {
  const match = /^(.*) \(([^()]*)\)$/.exec(value.trim());
  if (!match?.[1] || !match[2]) return { primary: value };
  return { primary: match[1], context: match[2] };
}
