import { expect, test } from 'bun:test';

import { copyTextRow } from './copy';

test('encodes a PostgreSQL COPY text row without changing its columns', () => {
  expect(copyTextRow(['trip\\id', 'Gare\tNord', 'line\nfeed', 42])).toBe(
    'trip\\\\id\tGare\\tNord\tline\\nfeed\t42\n'
  );
});
