#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$PROJECT_DIR"
BUILD_DIR="$PROJECT_DIR/../../work/swipewipe-ipa-build"
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos/SwipewipeCleanup.app"
IPA_PATH="$OUTPUT_DIR/SwipewipeCleanup.ipa"

if ! xcodebuild -version >/dev/null 2>&1; then
  for developer_dir in /Applications/Xcode*.app/Contents/Developer; do
    if [[ -x "$developer_dir/usr/bin/xcodebuild" ]]; then
      export DEVELOPER_DIR="$developer_dir"
      break
    fi
  done
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required. Install Xcode before building." >&2
  exit 1
fi

xcodebuild \
  -quiet \
  -project "$PROJECT_DIR/SwipewipeCleanup.xcodeproj" \
  -scheme SwipewipeCleanup \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build completed without finding the expected app at: $APP_PATH" >&2
  exit 1
fi

rm -rf "$BUILD_DIR/Payload"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP_PATH" "$BUILD_DIR/Payload/SwipewipeCleanup.app"
rm -f "$IPA_PATH"
ditto -c -k --sequesterRsrc --keepParent "$BUILD_DIR/Payload" "$IPA_PATH"
echo "Created $IPA_PATH"
