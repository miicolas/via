# Via iOS native

This directory is the autonomous SwiftUI client being migrated from the Expo app.
It targets iOS 26 with Xcode 26 and deliberately does not share the generated
Expo `ios/` project.

## Run

Open `Via.xcodeproj` in Xcode 26 and select the `Via` scheme. Debug and Staging
are local/test configurations and default to `http://localhost:3000` for the
iOS Simulator. A `VIA_API_URL` launch environment variable overrides that
default. Staging uses the separate bundle identifier `dev.via.app.staging` and
keeps the same local feature overrides as Debug. Release disables those
overrides and requires its API origin to be embedded by the distribution
configuration, for example with `VIA_API_URL=https://...` on the archive
command.

For a deterministic visual smoke test without a running API, add the launch
argument `--via-demo`. The demo adapter is never selected by Release builds.

The native shell now includes onboarding, an authentication gate, the Carte /
Lignes / Navigo tabs, and the Via chat entry point. In Debug, `--via-demo`
also exercises a deterministic streamed answer and a structured itinerary
detail screen without credentials.

The first production-shaped vertical slices are:

`MapKit map → search → station selection → departures → classic journey detail`

`Carte → Via chat → streamed answer → structured journey detail`

The REST adapter consumes the existing `/api` OpenAPI surface while the Expo
client continues to use `/rpc` during coexistence.

The native chat adapter consumes `POST /ai/chat/v1` as newline-delimited JSON;
the existing `POST /ai/chat` UI-message stream remains dedicated to the web
client.

The coexistence rules, Debug-only feature overrides, cohort headers and
cutover gates live in [`docs/ios-native-coexistence.md`](../../docs/ios-native-coexistence.md).

The canonical contract snapshot lives in
`Packages/ViaAPIContract/Sources/ViaAPIContract/openapi.json`. Verify that it
has not drifted from the TypeScript contract with:

```sh
apps/ios/Scripts/verify-openapi-snapshot.sh
```

Swift OpenAPI Generator is isolated in `Packages/ViaAPIContract`; generated
transport types stay behind the app's `TransitAPI` seam and never reach feature
views. The package uses ahead-of-time generation because the generator itself
runs on macOS while the app target runs on iOS. After changing the OpenAPI
document or generator configuration, regenerate and commit the checked-in
sources:

```sh
swift package --package-path apps/ios/Packages/ViaAPIContract \
  --allow-writing-to-package-directory generate-code-from-openapi
```
