#!/bin/bash
# Rally → TestFlight in one command.
#   ./ship.sh            archive + upload to TestFlight
#   ./ship.sh --ipa      archive + export an .ipa to build/ (no upload)
#   TEAM_ID=ABCDE12345 ./ship.sh   force a specific Apple team
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-upload}"
ARCHIVE=build/Rally.xcarchive
EXPORT_DIR=build/export

echo "▶ Xcode: $(xcodebuild -version | head -1)"

# 1. Apple team (auto-detect from the signing cert Xcode installed)
if [ -z "${TEAM_ID:-}" ]; then
  TEAM_ID=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)
fi
if [ -z "${TEAM_ID:-}" ]; then
  TEAM_ID=$(security find-certificate -a -c "Apple Distribution" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)
fi
if [ -z "${TEAM_ID:-}" ]; then
  echo "✖ No Apple team found on this Mac."
  echo "  Xcode → Settings → Accounts → add your Apple ID (must be enrolled in the Apple Developer Program),"
  echo "  then click 'Manage Certificates…' → + → Apple Development. Re-run ./ship.sh"
  echo "  (or run: TEAM_ID=YOUR10CHARID ./ship.sh)"
  exit 1
fi
echo "▶ Team: $TEAM_ID"
printf 'DEVELOPMENT_TEAM = %s\n' "$TEAM_ID" > Config/Local.xcconfig

# 2. Regenerate the Xcode project if xcodegen is available (keeps project.yml the source of truth)
if command -v xcodegen >/dev/null 2>&1; then
  echo "▶ xcodegen generate"; xcodegen generate >/dev/null
else
  echo "▶ xcodegen not installed — using committed Rally.xcodeproj (brew install xcodegen to regenerate)"
fi

# 3. Build number = UTC timestamp so every upload is unique
BUILD_NUMBER=$(date -u +%Y%m%d%H%M)
echo "▶ Version $(sed -n 's/.*MARKETING_VERSION: *"\([^"]*\)".*/\1/p' project.yml | head -1) ($BUILD_NUMBER)"

# 4. Archive (Release, generic iOS device)
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild archive \
  -project Rally.xcodeproj -scheme Rally -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  | grep -E "error:|warning: .*signing|ARCHIVE|\*\* " || true
[ -d "$ARCHIVE" ] || { echo "✖ Archive failed — scroll up for the first 'error:' line."; exit 1; }
echo "✔ Archived $ARCHIVE"

# 5. Export / upload
if [ "$MODE" = "--ipa" ]; then
  sed 's#<string>upload</string>#<string>export</string>#' Config/ExportOptions-TestFlight.plist > build/ExportOptions-ipa.plist
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist build/ExportOptions-ipa.plist -allowProvisioningUpdates
  echo "✔ IPA: $EXPORT_DIR/Rally.ipa  (drop it into the Transporter app to upload)"
else
  AUTH=()
  if [ -n "${ASC_KEY_PATH:-}" ]; then
    AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
  fi
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist Config/ExportOptions-TestFlight.plist -allowProvisioningUpdates "${AUTH[@]}"
  echo "✔ Uploaded to App Store Connect. Processing takes ~5–15 min, then it appears under TestFlight."
fi
