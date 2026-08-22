# Native iOS application

`apps/via` is the only mobile application. It is an iOS-only SwiftUI project targeting iOS 26 with Swift 6 strict concurrency. Use Apple’s versioned SwiftUI, MapKit, Foundation, and Observation documentation for platform APIs.

## Component structure

- A Swift source file owns one primary `View`. Extract secondary UI behavior into its own PascalCase view file and configure it through initializer values or bindings.

## Platform

- Implement each mobile feature once with iOS and SwiftUI APIs. Do not add Android, web, JavaScript mobile, or platform-suffixed sibling implementations.

## Buttons

- Use SwiftUI `Button` for button semantics and apply an appropriate native role and style.
- Use gestures only for gesture semantics; map annotations should use MapKit selection where possible.

## Symbols over words

- A control shows a symbol, not a word. Give every button, toggle, and toolbar item an SF Symbol and hide the text with `labelStyle(.iconOnly)` or the shared `iconAction()`; the words stay in `accessibilityLabel`/`accessibilityValue` so VoiceOver still reads them. The only text that survives on a control is the screen's full-width `primaryAction`/`secondaryAction`, where the verb is the point.
- Never ship a stock control that renders its own word — `EditButton()`, a `Toggle` with a title, a `Text`-labelled toolbar item. Rebuild it as a symbol button over the same state.
- A symbol that changes with state animates the change: `contentTransition(.symbolEffect(.replace.magic(fallback: .offUp.byLayer), options: .nonRepeating))`, degraded to `.identity` when `accessibilityReduceMotion` is on. `StationDetailView`'s favourite star is the reference.
- This holds for every symbol that flips with state, not just toolbar icons: the reminder bell, the favourite star, a play/pause, a mute. A control the user toggles never swaps its glyph abruptly. When the control is a full-width labelled action, build the `Label` with an explicit `Image(systemName:)` and put `contentTransition` on that image — the transition belongs to the symbol, not to the wording next to it. A state that lands from an `async` task carries no transaction, so pair the transition with `.animation(reduceMotion ? nil : .default, value:)` — otherwise the glyph still swaps in one frame.

## Empty states

- Nothing to show is a designed screen, not an absence. Every empty, unavailable, or failed state goes through `EmptyStateView` with an `EmptyState` (`via/Shared/Presentation/View/`) — one centred column, one optional glyph, one title, one sentence, and the way out underneath.
- Never `ContentUnavailableView`: it draws Apple's grey, ignores Via's typography, and offers no action. Never a column hand-written inside a feature either — a state Via has already worded lives as a `static` on `EmptyState`, so two screens cannot word it differently.
- When the way out is *somewhere else on screen*, it is an `EmptyStateHint`, never a button: one grey sentence naming the control, with that control's own SF Symbol interpolated inline (`Text("Touchez \(Image(systemName: "magnifyingglass.circle.fill")) Recherche pour trouver une station près de vous")`), tappable when it can open the target, and carrying a `label:` because the symbol is silent to VoiceOver. `StationsView` is the reference. Never restate the same instruction as a capsule underneath — a prominent button there steals the emphasis from the control the sentence points at, and never as plain prose either: a hint without its symbol is a hint the eye cannot match to the toolbar.
- A full-width `Button` carrying `primaryAction()` / `secondaryAction()` is for a dead end with something to **do** on this screen — retry, choose, authorise. Those stack under the hint, never in place of it.
- The column hugs its content. Filling the screen is the container's call (`.frame(maxHeight: .infinity)`), which is what lets the same component sit in a `List` `Section` and in a full-height overlay.
- Loading keeps its own vocabulary: `SkeletonGate` / `SkeletonList` wherever there is geometry to preserve, `EmptyState.searching(_:)` only where there is none.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context — `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
