/** One row for PostgreSQL's text COPY format. All importer fields are non-null. */
export function copyTextRow(values: readonly (string | number)[]): string {
  return values.map(copyTextCell).join('\t') + '\n';
}

function copyTextCell(value: string | number): string {
  return String(value)
    .replaceAll('\\', '\\\\')
    .replaceAll('\t', '\\t')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r');
}
