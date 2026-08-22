---
name: apple-hig
description: Use for Apple Human Interface Guidelines design, implementation, or review work across iOS, iPadOS, macOS, tvOS, visionOS, watchOS, games, and Apple technologies. Route the task to the matching page skill and consult Apple's current page before relying on platform guidance.
---

# Apple Human Interface Guidelines

This is the HIG router and the skill for the main Human Interface Guidelines page. It covers the current Apple HIG navigation tree with one discoverable page skill per navigable page.

## Route the work

1. Identify the task's platform, foundation, pattern, component, input method, system experience, or Apple technology.
2. Find the matching entry in [`catalog.json`](references/catalog.json). Each entry gives the official page URL, its navigation trail, focus headings, and child skills.
3. Read the matching page skill, for example [`apple-hig-gestures`](../apple-hig-gestures/SKILL.md) or [`apple-hig-color`](../apple-hig-color/SKILL.md).
4. Read [`page-workflow.md`](references/page-workflow.md), then open the official Apple page when exact behavior, platform availability, measurements, examples, or change-log details matter.
5. Apply the guidance within the repository's existing architecture and instructions. For Via iOS work, `AGENTS.md` and the more specific `flighty-via-design` skill remain in force.

Invoke one directly with `$apple-hig-<page-slug>` when the exact page is known; use this router when it is not.

## Scope

The generated catalog is intentionally metadata-only. It records the live navigation structure without copying Apple's article text. Apple's page is the source of truth and may change; refresh the page skills with:

```sh
node .agents/skills/apple-hig/scripts/generate.mjs
```

The generator follows the official HIG `topicSections` tree, strips in-page `#anchors`, writes the catalog, and creates or updates the page skills. It does not delete unrelated files.
