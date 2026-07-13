#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TabTap"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tabtap-dmg.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/script/build_and_run.sh" --build-only

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
ARCHS="$(/usr/bin/lipo -archs "$APP_BUNDLE/Contents/MacOS/$APP_NAME")"
ARCH_LABEL="${ARCHS// /-}"
DMG_PATH="${1:-$DIST_DIR/$APP_NAME-$VERSION-macOS-$ARCH_LABEL.dmg}"

mkdir -p "$(dirname "$DMG_PATH")"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

if [[ "${CODE_SIGN_IDENTITY:--}" != "-" ]]; then
  /usr/bin/codesign \
    --force \
    --timestamp \
    --sign "$CODE_SIGN_IDENTITY" \
    "$DMG_PATH"
fi

/usr/bin/hdiutil verify "$DMG_PATH"
/usr/bin/shasum -a 256 "$DMG_PATH"
