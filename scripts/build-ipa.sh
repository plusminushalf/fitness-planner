#!/usr/bin/env bash
# Builds an unsigned FitnessPlanner.ipa for SideStore / AltStore, which re-sign
# it on the phone with the user's own Apple ID. Run from the repo root:
#   scripts/build-ipa.sh [marketing-version] [build-number]
# Output: build/FitnessPlanner.ipa
set -euo pipefail

VERSION="${1:-1.0}"
BUILD_NUMBER="${2:-1}"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/FitnessPlanner.xcarchive"
IPA="$BUILD_DIR/FitnessPlanner.ipa"

xcodegen generate

rm -rf "$ARCHIVE" "$BUILD_DIR/Payload" "$IPA"

xcodebuild archive \
  -project FitnessPlanner.xcodeproj \
  -scheme FitnessPlanner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -quiet

mkdir -p "$BUILD_DIR/Payload"
cp -R "$ARCHIVE/Products/Applications/FitnessPlanner.app" "$BUILD_DIR/Payload/"
(cd "$BUILD_DIR" && zip -qry FitnessPlanner.ipa Payload)
rm -rf "$BUILD_DIR/Payload"

echo "Built $IPA ($VERSION, build $BUILD_NUMBER)"
