const formatterCache: Record<string, Intl.DateTimeFormat> = {};

export function journeyDateFormatter(
  locale: string,
  timeZone: string,
  options: Intl.DateTimeFormatOptions,
): Intl.DateTimeFormat {
  const key = [locale, timeZone, JSON.stringify(options)].join("|");
  return (formatterCache[key] ??= new Intl.DateTimeFormat(locale, {
    ...options,
    timeZone,
  }));
}
