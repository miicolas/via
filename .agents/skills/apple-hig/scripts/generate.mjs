#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "../../../..");
const skillsRoot = path.join(repositoryRoot, ".agents", "skills");
const rootRoute = "/design/human-interface-guidelines";
const sourceRoot = `https://developer.apple.com${rootRoute}`;
const dataRoot = "https://developer.apple.com/tutorials/data";
const userAgent = "via-apple-hig-skill-generator/1.0";
const ignoredHeadingTitles = new Set([
  "Resources",
  "Related",
  "Developer documentation",
  "Videos",
  "Change log",
]);

const cleanRoute = (route) => {
  const withoutAnchor = route.split("#", 1)[0];
  const withoutTrailingSlash = withoutAnchor.replace(/\/$/, "");
  return withoutTrailingSlash || "/";
};

const sourceURL = (route) => `https://developer.apple.com${cleanRoute(route)}`;
const dataURL = (route) => `${dataRoot}${cleanRoute(route)}.json`;

const pageSkillName = (route) => {
  if (route === rootRoute) return "apple-hig";
  const slug = route.split("/").at(-1);
  return `apple-hig-${slug}`;
};

const pageDirectory = (route) => path.join(skillsRoot, pageSkillName(route));

const collectNavigationChildren = (page) => {
  const children = [];

  for (const section of page.topicSections ?? []) {
    for (const identifier of section.identifiers ?? []) {
      const url = page.references?.[identifier]?.url;
      if (typeof url === "string" && url.startsWith(rootRoute)) {
        children.push(cleanRoute(url));
      }
    }
  }

  return [...new Set(children)];
};

const collectHeadings = (page) => {
  const headings = [];

  const visit = (value) => {
    if (!value || typeof value !== "object") return;

    if (
      value.type === "heading" &&
      typeof value.text === "string" &&
      !ignoredHeadingTitles.has(value.text)
    ) {
      headings.push({
        text: value.text,
        level: value.level ?? null,
        anchor: value.anchor ?? null,
      });
    }

    for (const child of Object.values(value)) {
      if (Array.isArray(child)) child.forEach(visit);
      else visit(child);
    }
  };

  visit(page.primaryContentSections);

  return [...new Map(headings.map((heading) => [heading.anchor ?? heading.text, heading])).values()];
};

const fetchPage = async (route) => {
  const response = await fetch(dataURL(route), {
    headers: { "user-agent": userAgent },
  });

  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}`);
  }

  return response.json();
};

const crawl = async () => {
  const queue = [rootRoute];
  const seen = new Set();
  const pages = [];
  const failures = [];

  const worker = async () => {
    while (queue.length > 0) {
      const route = queue.shift();
      if (!route || seen.has(route)) continue;
      seen.add(route);

      try {
        const page = await fetchPage(route);
        const navigationChildren = collectNavigationChildren(page);

        pages.push({
          route,
          title: page.metadata?.title ?? route.split("/").at(-1),
          role: page.metadata?.role ?? null,
          kind: page.kind ?? null,
          headings: collectHeadings(page),
          availableLanguages: page.metadata?.availableLanguages ?? [],
          navigationChildren,
          schemaVersion: page.schemaVersion ?? null,
        });

        for (const child of navigationChildren) {
          if (!seen.has(child)) queue.push(child);
        }
      } catch (error) {
        failures.push({ route, error: String(error) });
      }
    }
  };

  await Promise.all(Array.from({ length: 12 }, worker));
  pages.sort((left, right) => left.route.localeCompare(right.route));

  return {
    generatedAt: new Date().toISOString(),
    source: sourceRoot,
    pages,
    failures,
  };
};

const buildParentTrails = (pages) => {
  const pagesByRoute = new Map(pages.map((page) => [page.route, page]));
  const trailsByRoute = new Map();

  const visit = (route, trail, activeRoutes) => {
    if (activeRoutes.has(route)) return;

    const page = pagesByRoute.get(route);
    if (!page) return;

    if (!trailsByRoute.has(route)) trailsByRoute.set(route, []);
    const existingTrails = trailsByRoute.get(route);
    const serializedTrail = JSON.stringify(trail);
    if (!existingTrails.some((existing) => JSON.stringify(existing) === serializedTrail)) {
      existingTrails.push(trail);
    }

    const nextActiveRoutes = new Set(activeRoutes);
    nextActiveRoutes.add(route);
    const nextTrail = route === rootRoute ? trail : [...trail, page.title];

    for (const child of page.navigationChildren) {
      visit(child, nextTrail, nextActiveRoutes);
    }
  };

  visit(rootRoute, [], new Set());
  return trailsByRoute;
};

const yamlString = (value) => JSON.stringify(value);

const renderPageSkill = (page, parentTrails, pagesByRoute) => {
  const name = pageSkillName(page.route);
  const description = `Apply Apple's Human Interface Guidelines for ${page.title} when designing, implementing, or reviewing that topic and its platform-specific guidance.`;
  const trails = parentTrails.length > 0 ? parentTrails : [["Human Interface Guidelines"]];
  const focusHeadings = page.headings.slice(0, 16);
  const childPages = page.navigationChildren
    .map((route) => pagesByRoute.get(route))
    .filter(Boolean);
  const trailLines = trails.map((trail) => `- ${["Human Interface Guidelines", ...trail].join(" → ")}`);

  const lines = [
    "---",
    `name: ${name}`,
    `description: ${yamlString(description)}`,
    "metadata:",
    "  generated-by: apple-hig-skill-generator",
    `  source-url: ${sourceURL(page.route)}`,
    "---",
    "",
    `# Apple HIG: ${page.title}`,
    "",
    `Use this page skill when the task touches **${page.title}**. It stores navigation context and routing metadata; it does not copy Apple's article text.`,
    "",
    `Read the shared [page workflow](../apple-hig/references/page-workflow.md), then open the official [${page.title} page](${sourceURL(page.route)}) before relying on detailed rules, platform availability, measurements, examples, or change-log entries.`,
    "",
    "## Navigation context",
    "",
    ...trailLines,
    `- Official source: [${sourceURL(page.route)}](${sourceURL(page.route)})`,
    `- Page role: ${page.role ?? "unspecified"}`,
    `- Local page skill: \`${name}\``,
  ];

  if (focusHeadings.length > 0) {
    lines.push("", "## Focus areas", "", ...focusHeadings.map((heading) => `- ${heading.text}`));
  }

  if (childPages.length > 0) {
    lines.push(
      "",
      "## Child page skills",
      "",
      ...childPages.map(
        (child) => `- [${child.title}](../${pageSkillName(child.route)}/SKILL.md) — [Apple page](${sourceURL(child.route)})`,
      ),
    );
  }

  lines.push("");
  return `${lines.join("\n")}\n`;
};

const buildCatalog = (crawlResult, parentTrails) => {
  const pagesByRoute = new Map(crawlResult.pages.map((page) => [page.route, page]));

  return {
    generatedAt: crawlResult.generatedAt,
    source: crawlResult.source,
    pageCount: crawlResult.pages.length,
    failureCount: crawlResult.failures.length,
    pages: crawlResult.pages.map((page) => ({
      skill: pageSkillName(page.route),
      title: page.title,
      route: page.route,
      url: sourceURL(page.route),
      role: page.role,
      schemaVersion: page.schemaVersion,
      availableLanguages: page.availableLanguages,
      parentTrails: parentTrails.get(page.route) ?? [],
      focusAreas: page.headings,
      children: page.navigationChildren.map((route) => ({
        skill: pageSkillName(route),
        title: pagesByRoute.get(route)?.title ?? route.split("/").at(-1),
        route,
        url: sourceURL(route),
      })),
    })),
    failures: crawlResult.failures,
  };
};

const writeGeneratedFiles = async (crawlResult) => {
  const parentTrails = buildParentTrails(crawlResult.pages);
  const pagesByRoute = new Map(crawlResult.pages.map((page) => [page.route, page]));
  const catalog = buildCatalog(crawlResult, parentTrails);
  const referencesDirectory = path.join(skillsRoot, "apple-hig", "references");

  await fs.mkdir(referencesDirectory, { recursive: true });
  await fs.writeFile(
    path.join(referencesDirectory, "catalog.json"),
    `${JSON.stringify(catalog, null, 2)}\n`,
  );

  for (const page of crawlResult.pages) {
    if (page.route === rootRoute) continue;

    const directory = pageDirectory(page.route);
    await fs.mkdir(directory, { recursive: true });
    await fs.writeFile(
      path.join(directory, "SKILL.md"),
      renderPageSkill(page, parentTrails.get(page.route) ?? [], pagesByRoute),
    );
  }

  return catalog;
};

const crawlResult = await crawl();
const catalog = await writeGeneratedFiles(crawlResult);

console.log(
  JSON.stringify(
    {
      generatedAt: catalog.generatedAt,
      pageCount: catalog.pageCount,
      failureCount: catalog.failureCount,
      outputRoot: skillsRoot,
    },
    null,
    2,
  ),
);

if (catalog.failureCount > 0) process.exitCode = 1;
