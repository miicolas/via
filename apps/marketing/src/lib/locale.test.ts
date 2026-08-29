import { describe, expect, test } from 'bun:test';
import { readFile } from 'node:fs/promises';

import { siteLocale } from '../constants/locale';
import { baseMetadata, createArticleMetadata, createPageMetadata } from './metadata';

describe('site locale', () => {
  test('keeps each locale syntax explicit', () => {
    expect(siteLocale.htmlLanguage).toBe('fr');
    expect(siteLocale.bcp47).toBe('fr-FR');
    expect(siteLocale.openGraph).toBe('fr_FR');
  });

  test('declares French in base, page, and article Open Graph metadata', () => {
    expect(baseMetadata.openGraph).toMatchObject({ locale: 'fr_FR' });
    expect(createPageMetadata({ title: 'Test', path: '/test' }).openGraph).toMatchObject({
      locale: 'fr_FR',
    });
    expect(createArticleMetadata({
      title: 'Article',
      description: 'Description',
      path: '/blog/article',
      publishedTime: '2026-08-01T10:00:00.000Z',
      modifiedTime: '2026-08-02T10:00:00.000Z',
    }).openGraph).toMatchObject({ type: 'article', locale: 'fr_FR' });
  });

  test('wires the root document to the shared HTML locale', async () => {
    const source = await readFile(new URL('../app/layout.tsx', import.meta.url), 'utf8');

    expect(source).toContain('lang={siteLocale.htmlLanguage}');
    expect(source).not.toContain('lang="en"');
  });
});
