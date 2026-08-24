#!/bin/bash
set -e

BINARY="${1:-.build/release/localshot}"
APP_NAME="${2:-LocalShot.app}"
VERSION="${3:-0.1.0}"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_DIR/$APP_NAME"

echo "Bundling $APP_NAME v$VERSION..."

# Clean previous bundle
rm -rf "$APP_DIR"

# Create bundle structure
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_DIR/Contents/MacOS/localshot"

# Copy icon if it exists
if [ -f "$REPO_DIR/resources/AppIcon.icns" ]; then
    cp "$REPO_DIR/resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>LocalShot</string>
    <key>CFBundleDisplayName</key>
    <string>LocalShot</string>
    <key>CFBundleIdentifier</key>
    <string>com.localshot.app</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>localshot</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>LocalShot needs screen recording permission to capture screenshots.</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>LocalShot needs Input Monitoring to respond to global hotkeys (Cmd+Shift+S, Cmd+Shift+A).</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST

# TCC stores the grant against `identifier com.localshot.app and certificate
# leaf = H"<hash>"`. Ad-hoc has no leaf, so every rebuild reads as a new app and
# macOS asks for Screen Recording again. Refuse ad-hoc unless it is asked for.
IDENTITIES="$(security find-identity -v -p codesigning \
    | sed -n 's/^ *[0-9][0-9]*) [0-9A-F]* "\(.*\)"$/\1/p')"
COUNT="$(printf '%s' "$IDENTITIES" | grep -c . || true)"

if [ -z "${SIGN_IDENTITY:-}" ] && [ "$COUNT" = "1" ]; then
    SIGN_IDENTITY="$IDENTITIES"
fi

if [ -z "${SIGN_IDENTITY:-}" ]; then
    if [ "$COUNT" = "0" ]; then
        echo "Error: no code signing identity found in your keychains." >&2
    else
        echo "Error: $COUNT code signing identities found, so pick one:" >&2
        printf '%s\n' "$IDENTITIES" | sed 's/^/    /' >&2
    fi
    echo "  Choose one: SIGN_IDENTITY=\"My Identity\" bash scripts/bundle-app.sh" >&2
    echo "  Ad-hoc:     SIGN_IDENTITY=- bash scripts/bundle-app.sh" >&2
    exit 1
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "Signing ad-hoc. macOS will ask for Screen Recording again after every rebuild."
else
    echo "Signing with: $SIGN_IDENTITY"
fi
codesign --force --sign "$SIGN_IDENTITY" --identifier com.localshot.app "$APP_DIR"

echo "Done: $APP_DIR"
echo "Install: mkdir -p ~/Applications && rsync -a --delete \"$APP_DIR/\" ~/Applications/LocalShot.app/"
