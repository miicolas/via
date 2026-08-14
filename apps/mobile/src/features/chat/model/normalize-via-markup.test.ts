import { expect, test } from 'bun:test';

import { normalizeViaMarkup } from '@/features/chat/model/normalize-via-markup';

test('normalizes uppercase RER and four-digit bus lines into hinted badges', () => {
  expect(normalizeViaMarkup('avec le RER A et le bus 6404.')).toBe(
    'avec le {{rer:A}} et le {{bus:6404}}.'
  );
});

test('normalizes prefixed and hyphenated line names', () => {
  expect(normalizeViaMarkup('le bus N145 puis la ligne 91-10')).toBe(
    'le {{bus:N145}} puis la {{91-10}}'
  );
});
