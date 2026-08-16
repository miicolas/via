#!/usr/bin/env bash

set -euo pipefail

log() {
  printf '%s\n' "$*" >&2
}

fail() {
  log "App icon validation failed: $*"
  exit 1
}

for command_name in jq sips; do
  command -v "$command_name" >/dev/null 2>&1 || fail "missing required command: $command_name"
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/apps/via/via.xcodeproj/project.pbxproj"
ICON_DIR="$PROJECT_ROOT/apps/via/via/Assets.xcassets/AppIcon.appiconset"
ICON_MANIFEST="$ICON_DIR/Contents.json"

grep -q 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' "$PROJECT_FILE" \
  || fail "the iOS target does not select the AppIcon asset catalog"

icon_count="$(jq '[
  .images[]
  | select(
      .idiom == "universal"
      and .platform == "ios"
      and .size == "1024x1024"
      and ((.appearances // []) | length == 0)
      and ((.filename // "") | length > 0)
    )
] | length' "$ICON_MANIFEST")"

[ "$icon_count" -eq 1 ] \
  || fail "the AppIcon catalog must reference exactly one default 1024x1024 iOS image"

icon_filename="$(jq -r '
  .images[]
  | select(
      .idiom == "universal"
      and .platform == "ios"
      and .size == "1024x1024"
      and ((.appearances // []) | length == 0)
      and ((.filename // "") | length > 0)
    )
  | .filename
' "$ICON_MANIFEST")"
icon_path="$ICON_DIR/$icon_filename"

[ -f "$icon_path" ] || fail "referenced image does not exist: $icon_path"

pixel_width="$(sips -g pixelWidth "$icon_path" | awk '/pixelWidth/{print $2}')"
pixel_height="$(sips -g pixelHeight "$icon_path" | awk '/pixelHeight/{print $2}')"
has_alpha="$(sips -g hasAlpha "$icon_path" | awk '/hasAlpha/{print $2}')"

[ "$pixel_width" = 1024 ] && [ "$pixel_height" = 1024 ] \
  || fail "$icon_filename must be exactly 1024x1024 pixels"
[ "$has_alpha" = no ] || fail "$icon_filename must not contain an alpha channel"

log "App icon source is valid: $icon_filename (${pixel_width}x${pixel_height}, opaque)"

if [ "$#" -eq 0 ]; then
  exit 0
fi

[ "$#" -eq 1 ] || fail "usage: $0 [path-to-built-app]"

app_path="$1"
info_plist="$app_path/Info.plist"
[ -f "$info_plist" ] || fail "built app Info.plist does not exist: $info_plist"

icon_name="$(/usr/libexec/PlistBuddy \
  -c 'Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName' \
  "$info_plist" 2>/dev/null || true)"
[ -n "$icon_name" ] || fail "built app is missing CFBundleIconName"

bundled_120_icon="$(find "$app_path" -maxdepth 1 -type f -name '*.png' -print0 \
  | while IFS= read -r -d '' image_path; do
      width="$(sips -g pixelWidth "$image_path" 2>/dev/null | awk '/pixelWidth/{print $2}')"
      height="$(sips -g pixelHeight "$image_path" 2>/dev/null | awk '/pixelHeight/{print $2}')"
      if [ "$width" = 120 ] && [ "$height" = 120 ]; then
        basename "$image_path"
      fi
    done)"
[ -n "$bundled_120_icon" ] || fail "built app does not contain a 120x120 PNG icon"

log "Built app icon is valid: CFBundleIconName=$icon_name, 120x120=$bundled_120_icon"
