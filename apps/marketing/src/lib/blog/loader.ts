import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";

import { articleFrontmatterSchema, type ArticleFrontmatter, type ArticleLineKey } from "./schema";
import { transitLines } from "@/constants/transit";
import { articleStatus, parisToday, type ArticleStatus } from "./status";
import matter from "gray-matter";

/**
 * Les articles vivent sur le disque, en Markdown, et sont lus au build.
 *
 * Pas de CMS et pas de base : un article de travaux est un document daté qu’on
 * relit en revue avant de le publier, et une pull request est exactement le
 * bon objet pour ça. Le frontmatter est validé ici, et une erreur de validation
 * casse le build — un article dont les dates ne se lisent pas ne doit jamais
 * atteindre la production à moitié rendu.
 */

const CONTENT_DIRECTORY = join(process.cwd(), "content", "blog", "travaux");

export interface Article {
  readonly slug: string;
  readonly frontmatter: ArticleFrontmatter;
  /** Le corps Markdown, frontmatter retiré. */
  readonly body: string;
}

export interface ArticleSummary {
  readonly slug: string;
  readonly frontmatter: ArticleFrontmatter;
  readonly status: ArticleStatus;
}

/**
 * Lu une fois par processus. Next rend les pages statiquement au build, donc
 * ceci s’exécute une poignée de fois — mais `generateStaticParams`, chaque page
 * et le sitemap demandent tous la même liste.
 */
let cache: Promise<Article[]> | null = null;

export function loadArticles(): Promise<Article[]> {
  cache ??= readArticles();
  return cache;
}

async function readArticles(): Promise<Article[]> {
  const entries = await readdir(CONTENT_DIRECTORY).catch(() => [] as string[]);
  const files = entries.filter((entry) => entry.endsWith(".md"));

  const articles = await Promise.all(files.map(readArticle));

  // Le plus récent d’abord : c’est l’ordre du sommaire.
  return articles.sort((left, right) =>
    right.frontmatter.publishedAt.localeCompare(left.frontmatter.publishedAt),
  );
}

async function readArticle(file: string): Promise<Article> {
  const slug = file.replace(/\.md$/, "");
  const raw = await readFile(join(CONTENT_DIRECTORY, file), "utf8");
  const parsed = matter(raw);
  const frontmatter = articleFrontmatterSchema.safeParse(parsed.data);

  if (!frontmatter.success) {
    const problems = frontmatter.error.issues
      .map((issue) => `  · ${issue.path.join(".") || "(racine)"} : ${issue.message}`)
      .join("\n");
    throw new Error(`Frontmatter invalide dans content/blog/travaux/${file} :\n${problems}`);
  }

  return { slug, frontmatter: frontmatter.data, body: parsed.content };
}

export async function findArticle(slug: string): Promise<Article | null> {
  const articles = await loadArticles();
  return articles.find((article) => article.slug === slug) ?? null;
}

export async function listArticleSummaries(today = parisToday()): Promise<ArticleSummary[]> {
  const articles = await loadArticles();
  return articles.map((article) => ({
    slug: article.slug,
    frontmatter: article.frontmatter,
    status: articleStatus(article.frontmatter, today),
  }));
}

/**
 * Les lignes qui méritent une page « hub » : celles dont au moins un article
 * parle. Une page de ligne vide n’a rien à dire et ne doit pas exister.
 */
export async function listCoveredLines(): Promise<ArticleLineKey[]> {
  const articles = await loadArticles();
  const covered = new Set<ArticleLineKey>();
  for (const article of articles) {
    for (const line of article.frontmatter.lines) covered.add(line);
  }

  /*
   * L'ordre du réseau, pas celui des clés : trier `m13`, `m18`, `m8` comme des
   * chaînes donne « 13, 18, 8 », ce qu'aucun plan de métro n'affiche. Métro
   * d'abord, puis RER, et les numéros comparés numériquement.
   */
  const collator = new Intl.Collator("fr", { numeric: true });
  return [...covered].sort((left, right) => {
    const first = transitLines[left];
    const second = transitLines[right];
    if (first.mode !== second.mode) return first.mode === "metro" ? -1 : 1;
    return collator.compare(first.shortName, second.shortName);
  });
}

/**
 * Les articles d’une ligne : en cours et à venir d’abord, terminés ensuite.
 * Un lecteur qui arrive sur `/blog/ligne/13` cherche ce qui le concerne
 * aujourd’hui ; l’archive vient après, et elle compte parce qu’elle porte les
 * liens que Google a déjà indexés.
 */
export async function articlesForLine(
  line: ArticleLineKey,
  today = parisToday(),
): Promise<{ current: ArticleSummary[]; archived: ArticleSummary[] }> {
  const summaries = await listArticleSummaries(today);
  const matching = summaries.filter((summary) => summary.frontmatter.lines.includes(line));

  return {
    current: matching.filter((summary) => summary.status !== "ended"),
    archived: matching.filter((summary) => summary.status === "ended"),
  };
}
