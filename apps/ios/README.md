# Via iOS native

This directory is the autonomous SwiftUI client being migrated from the Expo app.
It targets iOS 26 with Xcode 26 and deliberately does not share the generated
Expo `ios/` project.

## Run

Open `Via.xcodeproj` in Xcode 26 and select the `Via` scheme. The production
configuration points at `EXPO_PUBLIC_API_URL`'s equivalent for the native app:
set the `VIA_API_URL` launch environment variable to the API origin (for the
iOS Simulator, `http://localhost:3000` works).

For a deterministic visual smoke test without a running API, add the launch
argument `--via-demo`. The demo adapter is never selected by Release builds.

The first vertical slice is intentionally small and production-shaped:

`MapKit map → search → station selection → departures`

The REST adapter consumes the existing `/api` OpenAPI surface while the Expo
client continues to use `/rpc` during coexistence.
