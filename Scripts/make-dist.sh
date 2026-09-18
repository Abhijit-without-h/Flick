#!/usr/bin/env bash
# Build Flick.app and wrap it as a downloadable zip + DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

die() { echo "ERROR: $*" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
[[ -n "$VERSION" ]] || die "could not read version from Info.plist"

bash "${ROOT}/Scripts/package-app.sh"

APP="${ROOT}/dist/Flick.app"
[[ -d "$APP" ]] || die "Flick.app missing"

STAGE="${ROOT}/dist/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Flick.app"
ln -s /Applications "$STAGE/Applications"

ZIP="${ROOT}/dist/Flick-${VERSION}.zip"
DMG="${ROOT}/dist/Flick-${VERSION}.dmg"
rm -f "$ZIP" "$DMG"

# ditto preserves macOS metadata better than zip(1)
ditto -c -k --keepParent "$APP" "$ZIP"

hdiutil create \
  -volname "Flick ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGE"

echo "Downloadables:"
echo "  $ZIP"
echo "  $DMG"
ls -lh "$ZIP" "$DMG"
