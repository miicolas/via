# App Store Paper Designer

A reusable Agent Skill for creating professional App Store screenshot galleries directly in Paper through the Paper Desktop MCP.

## What it does

- audits real app screenshots,
- defines a 6-screen marketing story,
- writes concise App Store copy,
- creates a reusable visual system,
- designs the gallery directly in Paper when MCP is connected,
- preserves real product UI,
- iterates existing frames rather than regenerating everything,
- checks current App Store export constraints.

## Install

The skill folder must remain named:

`app-store-paper-designer`

and must contain:

`app-store-paper-designer/SKILL.md`

In this repo it lives at `.claude/skills/app-store-paper-designer/`, so it is discovered
automatically by Claude Code and can be invoked with `/app-store-paper-designer`.

Paper itself is connected through the `paper-desktop` plugin (Paper Desktop MCP).

## Example commands

- "Use app-store-paper-designer and create 6 App Store screenshots from the screens in my open Paper file."
- "Redo screenshots 1–3 with a more premium, transport-led direction."
- "Keep my current visual system but make screenshot 4 focus on real-time disruption alerts."
- "Analyze these references and adapt the composition principles to my app without copying them."

## Included files

- `SKILL.md` — main workflow
- `references/app-store-rules.md` — current Apple export fallback rules
