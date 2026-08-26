/**
 * User input goes into a LIKE pattern, where `%`, `_` and the escape character
 * itself are operators. Left unescaped, a query like "12%" matches everything —
 * not a security hole (the value is still a bound parameter), but wrong results.
 *
 * PostgreSQL's default LIKE escape character is backslash.
 */
export function escapeLikePattern(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}

/**
 * Station names and spoken queries do not use punctuation consistently:
 * `Saint Lazare`, `Saint-Lazare` and `Saint–Lazare` name the same place. Keep
 * every user token escaped, but let PostgreSQL match any separator between
 * tokens. The wildcard is ours, never one supplied by the user.
 */
export function looseLikePattern(value: string): string {
  return value
    .trim()
    .split(/[\s\p{Pd}'’]+/u)
    .filter(Boolean)
    .map(escapeLikePattern)
    .join('%');
}
