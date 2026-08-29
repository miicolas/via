#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  printf '%s\n' 'Commande requise introuvable: xcodebuild' >&2
  exit 1
fi

IOS_TEST_DESTINATION="${IOS_TEST_DESTINATION:-}"
if [ -z "$IOS_TEST_DESTINATION" ]; then
  printf '%s\n' 'Tests iOS bloqués: IOS_TEST_DESTINATION doit identifier un appareil explicite.' >&2
  exit 1
fi

case "$IOS_TEST_DESTINATION" in
  generic/*|*'generic/platform='*)
    printf '%s\n' 'Tests iOS bloqués: une destination générique ne peut pas exécuter XCTest.' >&2
    exit 1
    ;;
esac

XCODEBUILD_ARGS=(
  xcodebuild
  -project apps/via/via.xcodeproj
  -scheme via
  -configuration Debug
  -destination "$IOS_TEST_DESTINATION"
  -parallel-testing-enabled NO
)
if [ -n "${VIA_API_CLIENT_KEY:-}" ]; then
  XCODEBUILD_ARGS+=("VIA_API_CLIENT_KEY=$VIA_API_CLIENT_KEY")
fi

"${XCODEBUILD_ARGS[@]}" -only-testing:ViaTests test
