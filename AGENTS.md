# Native iOS application

`apps/via` is the only mobile application. It is an iOS-only SwiftUI project targeting iOS 26 with Swift 6 strict concurrency. Use Apple’s versioned SwiftUI, MapKit, Foundation, and Observation documentation for platform APIs.

## Component structure

- A Swift source file owns one primary `View`. Extract secondary UI behavior into its own PascalCase view file and configure it through initializer values or bindings.

## Platform

- Implement each mobile feature once with iOS and SwiftUI APIs. Do not add Android, web, JavaScript mobile, or platform-suffixed sibling implementations.

## Buttons

- Use SwiftUI `Button` for button semantics and apply an appropriate native role and style.
- Use gestures only for gesture semantics; map annotations should use MapKit selection where possible.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context — `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
