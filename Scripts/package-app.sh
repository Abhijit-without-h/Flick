#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v swift >/dev/null 2>&1 || die "swift not found"
[[ -f "$ROOT/Resources/Info.plist" ]] || die "missing Resources/Info.plist"

echo "Building Flick (release)…"
swift build -c release --product Flick

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="${BIN_DIR}/Flick"
[[ -x "$BIN" ]] || die "binary not found at $BIN"

APP="${ROOT}/dist/Flick.app"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "$BIN" "${APP}/Contents/MacOS/Flick"
cp "${ROOT}/Resources/Info.plist" "${APP}/Contents/Info.plist"
printf 'APPLFLCK' > "${APP}/Contents/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - --identifier dev.abhijitsr.flick "$APP"
fi

echo "Built ${APP}"
