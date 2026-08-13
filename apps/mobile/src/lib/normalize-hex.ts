/** Line colors arrive as arbitrary hex, so shorthand and alpha are folded away first. */
export function normalizeHex(value: string) {
  const hex = value.startsWith('#') ? value.slice(1) : value;
  if (hex.length === 3) {
    return `#${[...hex].map((channel) => channel.repeat(2)).join('')}`;
  }

  return `#${hex.slice(0, 6)}`;
}
