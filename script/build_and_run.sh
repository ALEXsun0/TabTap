#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="TabTap"
BUNDLE_ID="app.tabtap.TabTap"
MIN_SYSTEM_VERSION="13.0"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
TARGET_ARCH="${TARGET_ARCH:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

SWIFT_BUILD_ARGUMENTS=(-c release --package-path "$ROOT_DIR")
if [[ -n "$TARGET_ARCH" ]]; then
  SWIFT_BUILD_ARGUMENTS+=(--arch "$TARGET_ARCH")
fi

swift build "${SWIFT_BUILD_ARGUMENTS[@]}"
BUILD_BINARY="$(swift build "${SWIFT_BUILD_ARGUMENTS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$ROOT_DIR/LICENSE" "$APP_RESOURCES/LICENSE"
cp "$ROOT_DIR/README.md" "$APP_RESOURCES/README.md"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.5</string>
  <key>CFBundleVersion</key>
  <string>6</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/xattr -cr "$APP_BUNDLE"
if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
  /usr/bin/codesign \
    --force \
    --options runtime \
    --sign - \
    --identifier "$BUNDLE_ID" \
    "$APP_BUNDLE"
else
  /usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$CODE_SIGN_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    "$APP_BUNDLE"
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

open_app_without_permission_prompt() {
  /usr/bin/open -n "$APP_BUNDLE" --args --no-permission-prompt
}

case "$MODE" in
  run)
    open_app
    ;;
  --build-only|build-only)
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app_without_permission_prompt
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
