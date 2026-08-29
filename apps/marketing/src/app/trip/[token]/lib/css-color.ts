export function cssColor(value: string, fallback: string): string {
  const normalized = value.trim();
  if (!normalized) return fallback;
  return normalized.startsWith("#") ? normalized : "#" + normalized;
}
