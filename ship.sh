#!/bin/bash
# Rally release preparation. Default is a read-only toolchain check.
#   ./ship.sh --check    verify selected SDK without building or uploading
#   ./ship.sh --archive archive only
#   ./ship.sh --ipa     archive + export an .ipa (no upload)
#   ./ship.sh --upload  archive + upload to App Store Connect
# Archive/export/upload require BUILD_NUMBER, e.g. BUILD_NUMBER=1 ./ship.sh --archive.
#   TEAM_ID=ABCDE12345 ./ship.sh   force a specific Apple team
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:---check}"
[ "$#" -le 1 ] || { echo 'Expected one release mode.' >&2; exit 2; }
case "$MODE" in
  --help|-h) sed -n '2,8p' "$0"; exit 0 ;;
  --check|--archive|--ipa|--upload) ;;
  *) echo 'Usage: ./ship.sh [--check|--archive|--ipa|--upload|--help]' >&2; exit 2 ;;
esac

echo "▶ Xcode: $(xcodebuild -version | head -1)"

# Apple requires iOS SDK 26+ for uploads since April 28, 2026.
# https://developer.apple.com/news/?id=ueeok6yw
SDK_VERSION=$(xcodebuild -sdk iphoneos -version SDKVersion)
SDK_MAJOR=${SDK_VERSION%%.*}
if ! [[ "$SDK_MAJOR" =~ ^[0-9]+$ ]] || [ "$SDK_MAJOR" -lt 26 ]; then
  echo "Release stopped: selected iOS SDK is $SDK_VERSION. Update/select Xcode with iOS SDK 26 or later." >&2
  exit 1
fi
[ -f Rally.xcodeproj/project.pbxproj ] || { echo 'Reviewed Xcode project is missing.' >&2; exit 1; }
plutil -lint Config/ExportOptions-TestFlight.plist >/dev/null
if [ "$MODE" = '--check' ]; then
  echo 'Toolchain preflight passed. Membership, App Store Connect access and product readiness still need verification.'
  exit 0
fi

# Keep Rally's existing team. Never choose whichever certificate appears first.
TEAM_ID="${TEAM_ID:-832KFP5M8B}"
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo 'Invalid TEAM_ID.' >&2; exit 1; }
BUILD_NUMBER="${BUILD_NUMBER:-}"
# CFBundleVersion permits up to four digits, then up to two digits per component.
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]{0,3}(\.[0-9]{1,2}){0,2}$ ]] || {
  echo 'Set BUILD_NUMBER to an unused value such as 1 or 1.0.1, not a long date stamp.' >&2; exit 1;
}
AUTH=(-allowProvisioningUpdates)
if [ -n "${ASC_KEY_PATH:-}${ASC_KEY_ID:-}${ASC_ISSUER_ID:-}" ]; then
  if [ -z "${ASC_KEY_PATH:-}" ] || [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_ISSUER_ID:-}" ]; then
    echo 'Provide all three ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID values, or none.' >&2; exit 1
  fi
  [ -r "$ASC_KEY_PATH" ] || { echo 'App Store Connect key file is not readable.' >&2; exit 1; }
  AUTH+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

# Preserve previous archives, local signing settings and reviewed project registration.
# Regeneration is a separate reviewed operation, never an upload side effect.
mkdir -p build
RUN_DIR=$(mktemp -d "$PWD/build/release-XXXXXX")
ARCHIVE="$RUN_DIR/Rally.xcarchive"
EXPORT_DIR="$RUN_DIR/export"
echo "▶ Team $TEAM_ID, build $BUILD_NUMBER; logs: $RUN_DIR"

# 4. Archive (Release, generic iOS device)
if ! xcodebuild archive \
  -project Rally.xcodeproj -scheme Rally -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  "${AUTH[@]}" \
  DEVELOPMENT_TEAM="$TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  2>&1 | tee "$RUN_DIR/archive.log"; then
  echo "Archive failed; nothing was exported or uploaded. See $RUN_DIR/archive.log" >&2
  exit 1
fi
[ -f "$ARCHIVE/Info.plist" ] && [ -d "$ARCHIVE/Products/Applications/Rally.app" ] || {
  echo 'Archive output is incomplete; nothing was exported or uploaded.' >&2; exit 1;
}
echo "✔ Archived $ARCHIVE"
if [ "$MODE" = '--archive' ]; then
  echo 'No upload performed.'
  exit 0
fi

# 5. Export / upload
OPTIONS="$RUN_DIR/ExportOptions.plist"
cp Config/ExportOptions-TestFlight.plist "$OPTIONS"
plutil -replace teamID -string "$TEAM_ID" "$OPTIONS"
if [ "$MODE" = "--ipa" ]; then
  plutil -replace destination -string export "$OPTIONS"
fi
if ! xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$OPTIONS" "${AUTH[@]}" 2>&1 | tee "$RUN_DIR/export.log"; then
  echo "Export/upload did not complete successfully. Check $RUN_DIR/export.log and App Store Connect before retrying." >&2
  exit 1
fi
if [ "$MODE" = '--ipa' ]; then
  [ -f "$EXPORT_DIR/Rally.ipa" ] || { echo 'Expected Rally.ipa is missing.' >&2; exit 1; }
  echo "✔ IPA: $EXPORT_DIR/Rally.ipa (no upload performed)"
else
  echo 'Upload command succeeded. Verify processing in App Store Connect; tester distribution and App Review are separate steps.'
fi
