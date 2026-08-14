#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bash scripts/deploy-testflight.sh [options]

Build the iOS app and upload it to App Store Connect/TestFlight.

Options:
  --dry-run             Validate auth/app/build settings without building or uploading.
  --app APP_ID          Override the App Store Connect app ID.
  --bundle-id BUNDLE_ID Override the iOS bundle identifier.
  --version VERSION     Override the marketing version.
  --group GROUP         Add the uploaded build to an existing TestFlight group.
  -h, --help            Show this help.

Environment overrides:
  ASC_DEPLOY_APP_ID, ASC_DEPLOY_BUNDLE_ID, ASC_DEPLOY_VERSION,
  ASC_DEPLOY_TESTFLIGHT_GROUP, ASC_DEPLOY_TIMEOUT, ASC_DEPLOY_PREBUILD
USAGE
}

log() {
  printf '%s\n' "$*" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Commande requise introuvable: $1"
    exit 1
  fi
}

require_command asc
require_command jq
require_command node
require_command xcodebuild

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

DEPLOY_APP_ID="${ASC_DEPLOY_APP_ID:-6801259695}"
DEPLOY_BUNDLE_ID="${ASC_DEPLOY_BUNDLE_ID:-dev.via.app}"
DEPLOY_VERSION="${ASC_DEPLOY_VERSION:-}"
DEPLOY_TESTFLIGHT_GROUP="${ASC_DEPLOY_TESTFLIGHT_GROUP:-}"
DEPLOY_TIMEOUT="${ASC_DEPLOY_TIMEOUT:-60m}"
DEPLOY_PREBUILD="${ASC_DEPLOY_PREBUILD:-auto}"
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --app)
      shift
      [ "$#" -gt 0 ] || { log "--app attend une valeur"; exit 2; }
      DEPLOY_APP_ID="$1"
      ;;
    --bundle-id)
      shift
      [ "$#" -gt 0 ] || { log "--bundle-id attend une valeur"; exit 2; }
      DEPLOY_BUNDLE_ID="$1"
      ;;
    --version)
      shift
      [ "$#" -gt 0 ] || { log "--version attend une valeur"; exit 2; }
      DEPLOY_VERSION="$1"
      ;;
    --group)
      shift
      [ "$#" -gt 0 ] || { log "--group attend une valeur"; exit 2; }
      DEPLOY_TESTFLIGHT_GROUP="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "Option inconnue: $1"
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ -z "$DEPLOY_VERSION" ]; then
  DEPLOY_VERSION="$(node -e '
    const fs = require("node:fs");
    const config = JSON.parse(fs.readFileSync("apps/mobile/app.json", "utf8"));
    process.stdout.write(config.expo.version);
  ')"
fi

IOS_DIR="apps/mobile/ios"
WORKSPACE_PATH="$IOS_DIR/via.xcworkspace"
ARCHIVE_PATH=".asc/artifacts/via.xcarchive"
IPA_PATH=".asc/artifacts/via.ipa"

log "Validation de l’authentification App Store Connect"
asc auth status --validate

EFFECTIVE_BUNDLE_ID="$(
  cd apps/mobile
  node --env-file=../../.env ./node_modules/.bin/expo config --json | jq -r '.ios.bundleIdentifier'
)"
EFFECTIVE_TEAM_ID="$(
  cd apps/mobile
  node --env-file=../../.env ./node_modules/.bin/expo config --json | jq -r '.ios.appleTeamId // empty'
)"
if [ "$EFFECTIVE_BUNDLE_ID" != "$DEPLOY_BUNDLE_ID" ]; then
  log "Bundle ID Expo inattendu: $EFFECTIVE_BUNDLE_ID (attendu: $DEPLOY_BUNDLE_ID)"
  exit 1
fi
if [ -z "$EFFECTIVE_TEAM_ID" ]; then
  log "Team ID Apple absent de la configuration Expo: ajoute ios.appleTeamId dans apps/mobile/app.json"
  exit 1
fi

APP_JSON="$(asc apps list --bundle-id "$DEPLOY_BUNDLE_ID" --output json)"
APP_COUNT="$(printf '%s' "$APP_JSON" | jq '.data | length')"
RESOLVED_APP_ID="$(printf '%s' "$APP_JSON" | jq -r '.data[0].id // empty')"
if [ "$APP_COUNT" -ne 1 ] || [ "$RESOLVED_APP_ID" != "$DEPLOY_APP_ID" ]; then
  log "L’app App Store Connect ne correspond pas aux paramètres du déploiement."
  log "  Bundle ID: $DEPLOY_BUNDLE_ID"
  log "  APP_ID demandé: $DEPLOY_APP_ID"
  log "  Résultat API: $RESOLVED_APP_ID"
  exit 1
fi

log "App ciblée: $DEPLOY_APP_ID ($DEPLOY_BUNDLE_ID), version $DEPLOY_VERSION"

if [ -n "$DEPLOY_TESTFLIGHT_GROUP" ]; then
  GROUP_JSON="$(asc testflight groups list --app "$DEPLOY_APP_ID" --paginate --output json)"
  if ! printf '%s' "$GROUP_JSON" | jq -e --arg group "$DEPLOY_TESTFLIGHT_GROUP" \
    '[.data[] | select(.id == $group or .attributes.name == $group)] | length == 1' >/dev/null; then
    log "Groupe TestFlight introuvable: $DEPLOY_TESTFLIGHT_GROUP"
    log "Crée d’abord le groupe dans App Store Connect, ou relance sans --group pour téléverser seulement."
    exit 1
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "Mode dry-run: aucun fichier natif, archive ou upload ne sera modifié."
  asc builds next-build-number \
    --app "$DEPLOY_APP_ID" \
    --version "$DEPLOY_VERSION" \
    --platform IOS \
    --output table
  asc testflight groups list --app "$DEPLOY_APP_ID" --paginate --output table
  log "Plan validé: prebuild iOS si nécessaire → prochain build number → archive → IPA → TestFlight."
  exit 0
fi

NEEDS_PREBUILD=0
if [ "$DEPLOY_PREBUILD" = "always" ] || [ ! -d "$WORKSPACE_PATH" ]; then
  NEEDS_PREBUILD=1
else
  NATIVE_BUILD_SETTINGS="$(xcodebuild \
    -showBuildSettings \
    -project "$IOS_DIR/via.xcodeproj" \
    -target via \
    -configuration Release 2>/dev/null)"
  NATIVE_BUNDLE_ID="$(printf '%s\n' "$NATIVE_BUILD_SETTINGS" | awk -F ' = ' '$1 ~ /^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*$/ { print $2; exit }')"
  NATIVE_TEAM_ID="$(printf '%s\n' "$NATIVE_BUILD_SETTINGS" | awk -F ' = ' '$1 ~ /^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*$/ { print $2; exit }')"
  if [ "$NATIVE_BUNDLE_ID" != "$DEPLOY_BUNDLE_ID" ] || [ "$NATIVE_TEAM_ID" != "$EFFECTIVE_TEAM_ID" ]; then
    log "Projet iOS obsolète (bundle/team: $NATIVE_BUNDLE_ID/$NATIVE_TEAM_ID): prebuild nécessaire"
    NEEDS_PREBUILD=1
  fi
fi

if [ "$NEEDS_PREBUILD" -eq 1 ]; then
  log "Régénération du projet iOS Expo"
  (
    cd apps/mobile
    node --env-file=../../.env ./node_modules/.bin/expo prebuild \
      --platform ios \
      --no-clean
  )
else
  log "Projet iOS déjà généré: prebuild ignoré (ASC_DEPLOY_PREBUILD=always pour le forcer)"
fi

if [ ! -d "$WORKSPACE_PATH" ]; then
  log "Workspace Xcode introuvable après le prebuild: $WORKSPACE_PATH"
  exit 1
fi

mkdir -p .asc/artifacts

log "Récupération du prochain numéro de build App Store Connect"
NEXT_BUILD_JSON="$(asc builds next-build-number \
  --app "$DEPLOY_APP_ID" \
  --version "$DEPLOY_VERSION" \
  --platform IOS \
  --output json)"
NEXT_BUILD_NUMBER="$(printf '%s' "$NEXT_BUILD_JSON" | jq -r '.nextBuildNumber // empty')"
if ! [[ "$NEXT_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  log "Numéro de build App Store Connect invalide: $NEXT_BUILD_NUMBER"
  exit 1
fi
log "Version native: $DEPLOY_VERSION ($NEXT_BUILD_NUMBER)"

log "Création de l’archive Xcode"
asc xcode archive \
  --workspace "$WORKSPACE_PATH" \
  --scheme via \
  --configuration Release \
  --archive-path "$ARCHIVE_PATH" \
  --overwrite \
  --xcodebuild-flag=-destination \
  --xcodebuild-flag=generic/platform=iOS \
  --xcodebuild-flag="MARKETING_VERSION=$DEPLOY_VERSION" \
  --xcodebuild-flag="CURRENT_PROJECT_VERSION=$NEXT_BUILD_NUMBER" \
  --xcodebuild-flag=-allowProvisioningUpdates \
  --output json

log "Export de l’IPA"
asc xcode export \
  --archive-path "$ARCHIVE_PATH" \
  --ipa-path "$IPA_PATH" \
  --overwrite \
  --timeout "$DEPLOY_TIMEOUT" \
  --xcodebuild-flag=-allowProvisioningUpdates \
  --output json

if [ -n "$DEPLOY_TESTFLIGHT_GROUP" ]; then
  log "Upload et distribution au groupe TestFlight: $DEPLOY_TESTFLIGHT_GROUP"
  asc publish testflight \
    --app "$DEPLOY_APP_ID" \
    --ipa "$IPA_PATH" \
    --group "$DEPLOY_TESTFLIGHT_GROUP" \
    --wait \
    --timeout "$DEPLOY_TIMEOUT" \
    --output json
else
  log "Upload vers TestFlight sans groupe"
  asc publish testflight \
    --app "$DEPLOY_APP_ID" \
    --ipa "$IPA_PATH" \
    --upload-only \
    --wait \
    --timeout "$DEPLOY_TIMEOUT" \
    --output json
fi

log "Déploiement TestFlight terminé. IPA conservée dans $PROJECT_ROOT/$IPA_PATH"
