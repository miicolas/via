# Applying a page-specific HIG skill

The page skill is a routing aid and a small piece of navigation memory. The official Apple page linked from it owns the detailed rules, platform differences, specifications, examples, resources, and change log.

1. Define the user goal and target platform before choosing a control, layout, interaction, or system experience.
2. Open the linked Apple page and read the sections that match the task. Treat platform-specific subsections as scoped guidance rather than universal rules.
3. Prefer the platform's native API and semantic control for the behavior. Add custom presentation only where the product needs a visual treatment that preserves the native interaction, accessibility, focus, keyboard, pointer, and Dynamic Type behavior.
4. Check the relevant states and environments: loading, empty, error, unavailable, interruption, dark appearance, localization, larger text, reduced motion, VoiceOver, pointer/keyboard input, and the supported device family.
5. Keep the implementation consistent with the repository's architecture and local instructions. In Via, preserve the native SwiftUI conventions in `AGENTS.md` and consult `flighty-via-design` for the product's visual language.
6. If the requested design intentionally departs from HIG guidance, name the trade-off, keep the deviation narrow, and verify that the user goal and accessibility semantics remain clear.

Completion means the relevant official page was checked, the page-specific guidance was applied to the affected states and platforms, and the implementation or review records any deliberate deviation.
