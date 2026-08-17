---
name: flighty-via-design
description: Use for any Via iOS SwiftUI screen, component, navigation, sheet, search, station, line, account, settings, accessibility, or visual review task. It translates the Flighty Aug 2026 captures and the two supplied reference captures into precise reusable components, native Apple controls, states, spacing, typography, colors, adaptive sheets, and beam behavior. Read it before changing SwiftUI UI in apps/via or reviewing whether a Via UI matches the reference.
---

# Flighty Via Design

## Purpose

This is Via’s durable design memory. It describes the source captures in text rather than relying on images, identifies recurring Flighty patterns, and maps each interaction to the closest Apple-native API. The implementation target is a native iOS product with Flighty’s visual grammar: calm map context, generous white sheets, high-contrast type, meaningful status color, and obvious empty/error/recovery states.

Use this skill for both new UI and refactors. Preserve the existing domain behavior, `adaptiveSheet` / `adaptiveSheetPresentation`, and `BorderBeamEffect`; change their presentation around the seams instead of replacing them with one-off replicas.

## Non-negotiable rules

- Top-level navigation is a real SwiftUI `TabView`: `Stations`, `Lignes`, `Moi`, then `Tab(role: .search)` for `Recherche`. Never draw a replacement capsule tab bar.
- Use `NavigationStack`, `List`, `Section`, `Menu`, `Picker`, `Toggle`, `TextField`, `searchable`, `ShareLink`, `sheet`, `popover`, `confirmationDialog`, and presentation detents when they express the behavior. Custom UI supplies the Flighty surface, not system semantics.
- Every interactive row is a `Button` or a native control with a 44-point hit target. Do not attach a tap gesture to a card that should behave like a button.
- A custom component must have one clear responsibility and a small interface. Prefer composition and injected closures/repositories over a component that owns unrelated navigation, loading, and networking.
- A visible state needs a designed representation: `empty`, `loading`, `error`, `attention`, `disrupted`, and `suspended` are not afterthoughts. Pair color with text/icon/shape so meaning survives Dynamic Type, dark mode, and VoiceOver.
- Do not introduce a new `Via...` or `via...` Swift filename. Keep technical identifiers that are part of the module, target, bundle, OpenAPI products, or domain contract when renaming would be unsafe.
- Keep motion purposeful and honor `accessibilityReduceMotion`. The beam may disappear under Reduce Motion while the CTA remains fully usable.

## Workflow for a Via UI task

1. Identify the capture family and read the relevant entry in [`references/screen-atlas.md`](references/screen-atlas.md). If the request concerns a supplied image, use the `R1` or `R2` entry.
2. Read the matching cross-screen rules in [`references/pattern-catalog.md`](references/pattern-catalog.md).
3. Decide native versus custom with [`references/native-apple-map.md`](references/native-apple-map.md). Native behavior wins whenever Apple provides it; custom styling wraps it.
4. Find the closest existing domain model, repository, view model, adaptive sheet, or beam seam. Keep the behavior and inject a narrow interface into a new screen/component.
5. Build the smallest reusable component that appears in at least two states or screens. Keep a screen’s primary `View` in its own PascalCase Swift file.
6. Verify light/dark mode, Dynamic Type, VoiceOver labels, keyboard/focus, reduced motion, loading/error/empty states, and sheet detents. If Xcode is unavailable, still run static checks and tests that do not require the unavailable SDK and report the limitation.

## Visual grammar

- Map or satellite is context, not decoration: keep it visible behind floating controls or a large adaptive sheet when a location detail is being explored.
- Sheets are the dominant surface. Use a light, nearly opaque surface, large top corners, a consistent horizontal content margin, and enough bottom safe-area breathing room. Wide screens can use the existing adaptive width/detent behavior.
- Typography is content-first: a large black title, a short secondary explanation in gray, then grouped rows/cards. Avoid excessive borders; use a subtle fill, hairline divider, or semantic outline only when it communicates selection or severity.
- Primary blue means focus/action/selection. Green means healthy or live; orange means attention; red means disruption/destructive; purple means PRO/AI. Always include a textual label.
- Search is a staged flow. Origin and destination become compact neutral tokens; the active field expands, shows the system cursor and clear affordance, and keeps the keyboard available. Natural-language journey input remains available.
- Empty states explain what is absent and give the next action. Loading states preserve geometry with skeletons; errors stay close to the failed content and provide retry.
- Rows are full-width, readable, and ordered by importance. Leading icon/badge communicates kind or mode; title is primary; contextual code/status is secondary; trailing action is native where possible.

## Reusable component vocabulary

Use the existing neutral component files and extract new ones only when the pattern has a stable seam. The current vocabulary is:

- `flightySurface`, `SectionHeader`, and `StatusBadgeView` for surfaces and status.
- `EmptyStateView`, `LoadingStateView`, and `ErrorStateView` for explicit state contracts.
- `LineBadgeView`, `StationRow`, `NearbyStationCard`, `LineStatusCard`, and `DepartureLineRow` for transit data.
- `SearchTokenField`, `SearchResultRow`, `PlaceSearchResultsList`, `LineSearchResultsSection`, and `NaturalJourneySuggestionRow` for the staged search flow.
- `AIBadge`, `AIBeamButtonStyle`, `AISurfaceStyle`, and `AIOnboardingCard` for AI/PRO emphasis.
- `FriendAlertPreferencesView`, `FriendAlertOptionCard`, and `ProBenefitCard` for the R2 alert-choice flow.
- `adaptiveSheetPresentation`, `AdaptiveSheet`, and `BorderBeamEffect` remain infrastructure. A feature supplies content and state; it does not clone their presentation logic.

## Validation checklist

- The four tabs can be selected, labels remain visible, and Search is a distinct trailing search role.
- Closing Search returns to the previously selected tab without losing the draft.
- Stations handles favorites, nearby, no data, location unavailable, loading, and retry; station selection uses MapKit selection where appropriate.
- Lines puts disrupted/attention lines first and supports network/mode/direction/“perturbées uniquement” native menus.
- Me is a native hierarchy with profile, favorites, saved places, preferences, synchronization, onboarding, help, sign-out, and confirmed deletion.
- Search supports focus, keyboard, clear, tokens, result selection, recents, and natural-language submission.
- Sheets retain detents, background interaction, wide-screen behavior, corner radius, and dismiss policy.
- Beam CTA is accessible and static under Reduce Motion.
- Tests cover navigation state, fixtures, token state, sheet behavior, native actions, and semantic labels.

## Reference routing

- [`screen-atlas.md`](references/screen-atlas.md): one precise textual record for captures `0` through `236`, plus `R1` and `R2`.
- [`pattern-catalog.md`](references/pattern-catalog.md): reusable visual and interaction patterns distilled across the atlas.
- [`native-apple-map.md`](references/native-apple-map.md): native API decision table and the small set of custom Flighty exceptions.
