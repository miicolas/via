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

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context — `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
