#!/usr/bin/env bash
# Writes build/source.json, the SideStore / AltStore source that points at the
# IPA attached to this release. Run after scripts/build-ipa.sh:
#   scripts/make-source.sh <version> <build-number> <release-notes-file>
set -euo pipefail

VERSION="$1"
BUILD_NUMBER="$2"
NOTES_FILE="$3"
REPO="${GITHUB_REPOSITORY:-plusminushalf/fitness-planner}"
IPA="build/FitnessPlanner.ipa"

jq -n \
  --arg version "$VERSION" \
  --arg build "$BUILD_NUMBER" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg notes "$(cat "$NOTES_FILE")" \
  --arg ipa "https://github.com/$REPO/releases/download/v$VERSION/FitnessPlanner.ipa" \
  --arg icon "https://raw.githubusercontent.com/$REPO/main/FitnessPlanner/Assets.xcassets/AppIcon.appiconset/icon-1024.png" \
  --arg source "https://github.com/$REPO/releases/latest/download/source.json" \
  --arg site "https://github.com/$REPO" \
  --argjson size "$(stat -f%z "$IPA")" \
  '{
    name: "Fitness Planner",
    identifier: "dev.garvitkhatri.FitnessPlanner.source",
    sourceURL: $source,
    website: $site,
    iconURL: $icon,
    apps: [{
      name: "Fitness Planner",
      bundleIdentifier: "dev.garvitkhatri.FitnessPlanner",
      developerName: "plusminushalf",
      subtitle: "CSV-planned workouts, Hevy-style logging.",
      localizedDescription: "Turns a CSV of weekly workouts into an in-gym companion: log every set, track progress, export as CSV.",
      iconURL: $icon,
      tintColor: "1F6FEB",
      versions: [{
        version: $version,
        buildVersion: $build,
        date: $date,
        localizedDescription: $notes,
        downloadURL: $ipa,
        size: $size,
        minOSVersion: "17.0"
      }],
      version: $version,
      versionDate: $date,
      versionDescription: $notes,
      downloadURL: $ipa,
      size: $size,
      appPermissions: { entitlements: [], privacy: {} }
    }],
    news: []
  }' > build/source.json

echo "Wrote build/source.json ($VERSION, build $BUILD_NUMBER)"
