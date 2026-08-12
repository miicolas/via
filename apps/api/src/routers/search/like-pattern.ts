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
