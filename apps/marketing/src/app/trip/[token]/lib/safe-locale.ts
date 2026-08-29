export function safeLocale(value: string): string {
  try {
    new Intl.DateTimeFormat(value);
    return value;
  } catch {
    return "fr-FR";
  }
}
