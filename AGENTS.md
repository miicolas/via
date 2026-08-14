# Expo HAS CHANGED

Read the exact versioned docs at https://docs.expo.dev/versions/v57.0.0/ before writing any code.

## Component structure

- A source file owns one component function. Extract secondary UI behavior into its own kebab-case component file and configure that component through props so it can be reused.

## Platform

- The mobile app is iOS-only. Implement each platform feature once in an unsuffixed file with iOS and SwiftUI APIs; do not add Android/web branches, fallbacks, or platform-suffixed sibling files.

## Buttons

- Every button uses `@/components/button`, the repo's single SwiftUI Button interface.
- Import `@expo/ui/swift-ui`'s Button only inside `button.tsx`; never implement a button with React Native `Pressable`.
- Reserve `Pressable` for non-button semantics such as links, tabs, adjustable controls, gestures, and map annotations.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context — `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
