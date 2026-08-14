/** Hides a trailing Via-markup token still being streamed, so raw markup never flashes. */
export function hideOpenViaMarkup(text: string): string {
  const lastBrace = text.lastIndexOf('{{');
  let safe =
    lastBrace !== -1 && text.indexOf('}}', lastBrace) === -1 ? text.slice(0, lastBrace) : text;
  const underscores = [...safe.matchAll(/__/g)];
  if (underscores.length % 2 === 1) safe = safe.slice(0, underscores.at(-1)!.index);
  return safe.replace(/[{_]$/, '');
}
