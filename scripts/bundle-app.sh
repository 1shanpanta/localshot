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
if [ -f "$REPO_DIR/Resources/AppIcon.icns" ]; then
    cp "$REPO_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
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
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc code sign
codesign --force --sign - --identifier com.localshot.app "$APP_DIR"

echo "Done: $APP_DIR"
echo "Install: cp -r \"$APP_DIR\" /Applications/"
