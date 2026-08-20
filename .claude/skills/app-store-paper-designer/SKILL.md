---
name: app-store-paper-designer
description: Designs, improves, and iterates professional App Store screenshot galleries in Paper using the Paper Desktop MCP. Use when the user asks for App Store screenshots, product marketing screenshots, App Store creatives, screenshot storyboards, iPhone mockup compositions, or wants to turn real app screenshots into a polished App Store campaign. Prioritize real product UI, strong marketing hierarchy, consistent art direction, editable Paper layers, and App Store-safe exports.
compatibility: Requires Paper Desktop with the Paper MCP connected for direct design work. Optional Mobbin or other reference tools may be used for visual research when available.
metadata:
  version: "1.0"
  category: "design"
---

# App Store Paper Designer

Create premium App Store screenshot campaigns directly in Paper.

The goal is not to decorate screenshots. The goal is to create a coherent product-marketing story that:
- looks intentional and premium,
- communicates the product in seconds,
- preserves the real app UI,
- remains fully editable in Paper,
- and is ready for App Store export.

## Operating principle

When Paper MCP is connected, **design in Paper instead of merely describing what to design**.

Do not stop at a written plan if the user has supplied enough material to begin.

Use the real screenshots, product copy, brand assets, and existing Paper document whenever possible.

## Required inputs

Use whatever the user already supplied. Do not ask for information that is already available.

Ideal inputs:
- app screenshots,
- app name,
- product positioning,
- logo or brand assets,
- brand colors if they exist,
- preferred language,
- target App Store device,
- optional visual references.

If some inputs are missing, make reasonable design decisions and proceed.

Only block execution if the essential source screenshots or the target Paper file are genuinely unavailable.

## Tool behavior

### Paper MCP

Before editing:
1. Confirm Paper MCP tools are available.
2. Inspect the open Paper document or current selection.
3. Reuse existing screenshots, colors, type styles, and components where appropriate.
4. Use the actual tool names exposed by the current Paper MCP. Never invent MCP methods.

Build with native editable layers:
- frames,
- text,
- rectangles,
- gradients,
- vectors,
- masks,
- images,
- groups,
- reusable components if supported.

Avoid flattening the full composition into a generated image.

### Optional visual research

If Mobbin or another design-reference tool is available, use it only when references would materially improve the result.

Extract principles such as:
- hierarchy,
- whitespace,
- device scale,
- crop,
- pacing,
- composition,
- typography,
- storytelling.

Do not copy another product's visual identity or reproduce a reference screen literally.

## Default output

Unless the user specifies otherwise, create **6 portrait App Store screenshots**.

Default working size:
- 1290 × 2796 px

This is an accepted 6.9-inch iPhone screenshot size as of the reference date in `references/app-store-rules.md`.

Keep the final screenshot backgrounds opaque.

## Core workflow

Follow these phases in order.

### Phase 1: Audit the product

Inspect the supplied screenshots before creating layouts.

Identify:
- the strongest visual screen,
- the clearest user benefit,
- the most differentiating feature,
- the most visually impressive interaction,
- any UI that should not be enlarged because it becomes misleading,
- any screens that are too similar.

Create a private list of 6–10 candidate product messages.

Rank them by:
1. immediate value,
2. differentiation,
3. visual clarity,
4. usefulness to a first-time App Store visitor.

### Phase 2: Define the story

The gallery must tell a story rather than repeat features.

Default narrative:

1. **Promise**
   - What is the app?
   - Why should someone care?

2. **Core action**
   - Show the main workflow.

3. **Differentiator**
   - Show what makes it better or different.

4. **Confidence**
   - Real-time, intelligence, reliability, personalization, or another trust-building capability.

5. **Breadth**
   - Show a second use case or ecosystem view.

6. **Brand close**
   - Finish with identity, emotion, or an ecosystem-level message.

The first 3 screenshots receive the most design attention.

They must work both:
- individually,
- and as a visible trio in the App Store gallery.

### Phase 3: Write the copy

Copy is part of the composition.

Default rules:
- headline: 2–6 words,
- maximum 2 lines,
- one idea per screenshot,
- avoid feature-list language,
- avoid vague hype,
- avoid punctuation-heavy marketing copy,
- avoid repeating the app name in every frame.

Prefer benefit-led copy.

Weak:
- "AI-Powered Route Planning"

Better:
- "A smarter way there"

Weak:
- "Real-Time Transit Information"

Better:
- "Know before you go"

Keep copy natural in the requested language.

Do not translate literally if a more idiomatic marketing line exists.

### Phase 4: Create the visual system first

Before making all screenshots, create a small internal system in Paper containing:

- background style,
- headline style,
- supporting-copy style,
- device treatment,
- screenshot mask,
- shadow treatment,
- line/badge treatment,
- card treatment,
- spacing tokens,
- corner-radius logic,
- optional decorative motif.

Name the section or frame:

`00 — System`

Then create numbered screenshot frames:

`01 — Hero`
`02 — Core`
`03 — Differentiator`
`04 — Confidence`
`05 — Breadth`
`06 — Closing`

Do not independently design six unrelated posters.

### Phase 5: Build screenshot 01 completely

Create the first frame before cloning the system.

It should establish:
- scale,
- composition,
- typography,
- device treatment,
- brand tone,
- amount of negative space.

The hero should be understandable in roughly 2 seconds.

Preferred structure:

1. headline,
2. optional short supporting line,
3. one dominant product visual,
4. at most 1–3 supporting visual accents.

Do not overcrowd the hero.

### Phase 6: Build screenshots 02–06

Reuse the system but introduce controlled variation.

Allowed variation:
- device position,
- device crop,
- zoomed UI detail,
- one floating UI card,
- background motif,
- illustration density,
- headline placement.

Keep constant:
- typography family,
- spacing logic,
- visual language,
- background family,
- shadow behavior,
- corner-radius logic,
- color semantics.

The gallery should feel like one campaign.

## Product UI integrity

This rule is critical:

**Never replace the real app UI with AI-generated fake UI unless the user explicitly asks for a conceptual mockup.**

When working from real screenshots:
- do not rewrite labels inside the screenshot,
- do not fabricate data that looks like live product output,
- do not change app navigation,
- do not invent controls,
- do not silently alter maps,
- do not place impossible UI inside the device.

You may:
- crop,
- mask,
- enlarge,
- highlight,
- dim unimportant regions,
- detach a real UI element into a floating callout when visually appropriate,
- recreate simple UI callouts outside the device if they accurately reflect the real feature.

If a callout is reconstructed, it must remain faithful to the product.

## Device treatment

Do not automatically place every screen inside a full iPhone mockup.

Choose the treatment that best communicates the feature.

Possible treatments:
- full device,
- oversized device crop,
- edge-to-edge UI crop,
- partial device entering the frame,
- device plus one detached UI callout,
- two overlapping states if needed for comparison.

Use a device frame only when it improves comprehension or polish.

Avoid:
- tiny centered phones,
- excessive perspective distortion,
- fake 3D for its own sake,
- several devices competing for attention.

## Typography

Aim for product-marketing clarity.

Default behavior:
- large, bold headline,
- restrained supporting copy,
- high contrast,
- generous line height,
- short line lengths,
- consistent baseline logic.

Do not use more than 2 type families unless the existing brand requires it.

Use the app's existing brand typeface if available and suitable.

Otherwise use a clean, modern sans serif available in the environment.

## Spacing and composition

Use large calm areas.

Default principles:
- one dominant focal point,
- clear top-to-bottom reading order,
- generous safe margins,
- no edge collisions,
- no decorative element without purpose,
- avoid filling every empty area.

Professional App Store design often feels expensive because it is **edited**, not because it contains more elements.

## Decorative graphics

Decorations must communicate the product category or brand.

Good:
- route lines,
- map geometry,
- subtle grids,
- transit nodes,
- location markers,
- motion paths,
- brand gradients,
- restrained abstract geometry.

Bad:
- generic blobs,
- random sparkles,
- unrelated 3D shapes,
- stock-style illustrations,
- AI-generated decoration that competes with the product.

For a mobility or transit app, route geometry can connect multiple screenshots to create continuity across the gallery.

## Floating UI

Use floating elements sparingly.

Maximum default:
- 1–3 floating elements per frame.

Good uses:
- ETA,
- transport line badge,
- price,
- status,
- delay,
- route score,
- AI suggestion,
- one key metric.

Floating UI should reinforce the exact message of that screenshot.

## Visual hierarchy

At a glance, users should perceive this order:

1. benefit,
2. product,
3. proof/detail,
4. decoration.

If decoration wins, simplify.

If the phone wins but the benefit is unclear, improve the headline.

If the headline wins but the product is unreadable, increase UI scale or crop.

## Consistency checks

After building all frames, compare them side by side.

Check:
- headline positions feel related,
- device scale changes feel deliberate,
- backgrounds belong to the same family,
- no frame is dramatically denser than the others without reason,
- feature claims correspond to visible UI,
- the first 3 screenshots are the strongest,
- there is visual rhythm across the full sequence.

Look for a pattern such as:

large / medium / large / crop / medium / brand

rather than:

same / same / same / same / same / same

## Professional-quality rules

Never default to:
- generic Canva-style templates,
- four cards floating around every phone,
- excessive gradients,
- glassmorphism everywhere,
- glow on every element,
- three-dimensional text,
- mockups that hide the real UI,
- paragraphs of text,
- icon walls,
- feature checklists.

Prefer:
- one idea,
- one visual,
- one strong composition.

## Iteration mode

When the user asks for a revision, edit the existing system instead of rebuilding from scratch.

Examples:

"make it more Apple"
- increase whitespace,
- reduce decorative density,
- simplify copy,
- strengthen typography,
- use larger product crops,
- make visual hierarchy calmer.

"make it less empty"
- do not indiscriminately add decoration,
- first increase product scale,
- add one meaningful UI callout,
- or strengthen the background motif.

"make it more premium"
- simplify,
- improve alignment,
- improve crop,
- reduce color count,
- improve typography,
- increase consistency.

"make it more dynamic"
- vary device position,
- use controlled overlap,
- connect frames with a visual motif,
- introduce asymmetric layouts,
- preserve hierarchy.

## Reference-driven mode

When references are provided:

1. analyze them,
2. extract reusable design principles,
3. identify what should NOT be copied,
4. adapt the principles to the user's product,
5. preserve the user's brand.

Describe the direction internally using attributes such as:

- editorial vs playful,
- calm vs energetic,
- flat vs dimensional,
- minimal vs expressive,
- product-led vs illustration-led,
- neutral vs saturated.

Do not say only "make it like Apple" or "make it like Linear."

Translate reference taste into concrete design decisions.

## App Store compliance

Before export, read `references/app-store-rules.md`.

At minimum:
- use a currently accepted screenshot size,
- export JPEG/JPG/PNG as appropriate,
- ensure there is no alpha/transparency in the final screenshots,
- do not exceed the App Store screenshot count,
- verify current Apple requirements if internet access is available.

Do not assume dimensions remain unchanged forever.

## Export checklist

Before saying the work is complete:

- verify all screenshot frames have identical dimensions,
- verify every background is opaque,
- verify text is inside safe margins,
- verify no accidental clipping,
- verify screenshots are high resolution,
- verify device masks are clean,
- verify shadows are consistent,
- verify headlines are legible at thumbnail scale,
- verify real UI remains accurate,
- verify the gallery works as a sequence,
- verify exports use the requested naming convention.

Suggested export names:

`01-hero.png`
`02-core.png`
`03-differentiator.png`
`04-confidence.png`
`05-breadth.png`
`06-closing.png`

## Completion behavior

When direct Paper editing was possible, finish with a concise summary containing:
- what was created,
- the chosen visual direction,
- any assets still missing,
- any export/compliance caveat that matters.

Do not write a long design essay after completing the work.

When Paper editing was not possible, provide:
- a precise storyboard,
- exact copy,
- exact composition instructions,
- and the minimum steps needed to execute it once Paper MCP is connected.

## Example user triggers

Use this skill for prompts such as:

- "Make my App Store screenshots in Paper."
- "Create 6 premium screenshots from these app screens."
- "Improve my App Store gallery."
- "Make these screenshots look more professional."
- "Create an App Store campaign for my iOS app."
- "Turn these screenshots into Apple-style marketing."
- "Use Paper to build my App Store assets."
- "Redesign screenshot 2 without changing the rest."
