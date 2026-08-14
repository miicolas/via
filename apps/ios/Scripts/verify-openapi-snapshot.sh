#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/../../.." && pwd)"
snapshot="$repository_root/apps/ios/Packages/ViaAPIContract/Sources/ViaAPIContract/openapi.json"
generated="$(mktemp)"
trap 'rm -f "$generated"' EXIT

bun --cwd "$repository_root/apps/api" -e \
  'const { getOpenApiDocument } = await import("./src/orpc/openapi.ts"); console.log(JSON.stringify(await getOpenApiDocument(), null, 2))' \
  > "$generated"

if ! cmp -s "$snapshot" "$generated"; then
  echo "OpenAPI snapshot is stale: regenerate it from apps/api/src/orpc/openapi.ts" >&2
  diff -u "$snapshot" "$generated" || true
  exit 1
fi

echo "OpenAPI snapshot is up to date."
