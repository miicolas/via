export function safeTimeZone(value: string): string {
  try {
    new Intl.DateTimeFormat("en", { timeZone: value });
    return value;
  } catch {
    return "Europe/Paris";
  }
}
