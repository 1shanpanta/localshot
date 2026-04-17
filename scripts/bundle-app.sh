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
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST

# Code sign with stable identity (preserves Screen Recording permission across rebuilds)
SIGN_IDENTITY="Apple Development: Ishan Panta (M8456FDZST)"
if security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
    codesign --force --sign "$SIGN_IDENTITY" --identifier com.localshot.app "$APP_DIR"
else
    echo "Warning: signing identity not found, using ad-hoc (permissions won't persist across rebuilds)"
    codesign --force --sign - --identifier com.localshot.app "$APP_DIR"
fi

echo "Done: $APP_DIR"
echo "Install: cp -r \"$APP_DIR\" /Applications/"
