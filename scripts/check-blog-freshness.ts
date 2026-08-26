import { readFile, readdir } from 'node:fs/promises';
import { join, resolve } from 'node:path';

import { parisToday } from '../apps/marketing/src/lib/blog/status';

/**
 * Le blog signale lui-même ce qui a besoin d'une main.
 *
 * Un article de travaux se périme, et un chantier terminé garde sa page — c'est
 * voulu, une URL qui meurt emporte son classement avec elle. Ce qui n'est pas
 * voulu, c'est qu'il la garde sans que personne ne repasse dessus : passé un
 * mois, un article terminé doit soit renvoyer vers la suite, soit avoir été
 * relu et daté.
 *
 * Ce contrôle échoue dans ce cas, et seulement dans ce cas. Il ne juge pas la
 * prose, il rappelle une échéance.
 *
 *   bun run check:blog-freshness
 */

const CONTENT = resolve(import.meta.dir, '../apps/marketing/content/blog/travaux');

/** Un mois de battement : le temps de constater qu'un chantier est fini. */
const GRACE_DAYS = 30;

type Problem = { file: string; message: string };

/**
 * Une lecture volontairement naïve du frontmatter — les trois clés de dates,
 * en tête de fichier. Le vrai schéma vit dans le site et casse déjà son build ;
 * ce script tourne dans la CI, où faire tourner Next serait disproportionné.
 * L'échelle de jour vient du site (`parisToday`) : elle décide de ce qu'un
 * article affiche, et deux définitions du « aujourd'hui » parisien dériveraient.
 */
function readDate(frontmatter: string, key: string): string | null {
  const match = new RegExp(`^${key}:\\s*['"]?(\\d{4}-\\d{2}-\\d{2})['"]?\\s*$`, 'm').exec(
    frontmatter
  );
  return match?.[1] ?? null;
}

function daysBetween(from: string, to: string): number {
  const start = Date.parse(`${from}T12:00:00Z`);
  const end = Date.parse(`${to}T12:00:00Z`);
  return Math.round((end - start) / 86_400_000);
}

async function main() {
  const today = parisToday();

  const files = (await readdir(CONTENT).catch(() => [] as string[])).filter((file) =>
    file.endsWith('.md')
  );

  const problems: Problem[] = [];

  for (const file of files) {
    const raw = await readFile(join(CONTENT, file), 'utf8');
    const frontmatter = raw.split('---')[1] ?? '';

    const validUntil = readDate(frontmatter, 'validUntil');
    if (!validUntil || validUntil >= today) continue;

    const overdue = daysBetween(validUntil, today);
    if (overdue <= GRACE_DAYS) continue;

    const updatedAt = readDate(frontmatter, 'updatedAt');
    if (updatedAt && updatedAt > validUntil) continue;

    problems.push({
      file,
      message: `terminé depuis ${overdue} jours et jamais relu depuis. Ajoutez « updatedAt » après l'avoir remis à jour, ou renvoyez vers le chantier suivant.`,
    });
  }

  if (problems.length === 0) {
    console.log(`${files.length} articles, aucun à rafraîchir.`);
    return;
  }

  for (const problem of problems) {
    console.error(`::error file=apps/marketing/content/blog/travaux/${problem.file}::${problem.message}`);
  }
  console.error(`\n${problems.length} article(s) à rafraîchir.`);
  process.exit(1);
}

await main();
