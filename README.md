# LocalShot

Native macOS screenshot tool with annotation. A free, open-source alternative to CleanShot X.

Built with Swift + AppKit. No Electron, no web views -- pure native.

## Features

- **Screen Capture** -- Full screen and area selection with crosshair overlay
- **Annotation Editor** -- Rectangle (red boxes!), ellipse, arrow, line, text, freehand, highlight, blur, counter badges
- **Quick Access Overlay** -- Floating thumbnail after capture with one-click copy/save/annotate
- **Menu Bar App** -- Lives in your menu bar, no dock icon
- **Global Shortcuts** -- Cmd+Shift+1 (full screen), Cmd+Shift+2 (area select)
- **Keyboard-Driven** -- Every tool has a single-key shortcut (V, R, A, T, P, etc.)
- **Copy & Save** -- Clipboard copy and PNG file save
- **Native Performance** -- Pure Swift/AppKit, uses CGDisplayCreateImage for capture

## Build & Run

```bash
# Debug build + run
swift build && .build/debug/localshot

# Release build + bundle as .app
swift build -c release
bash scripts/bundle-app.sh

# Install to Applications
cp -r LocalShot.app /Applications/
open /Applications/LocalShot.app
```

## Shortcuts

| Action | Shortcut |
|--------|----------|
| Full screen capture | Cmd+Shift+1 |
| Area capture | Cmd+Shift+2 |
| Select tool | V |
| Rectangle | R |
| Ellipse | E |
| Arrow | A |
| Line | L |
| Text | T |
| Pencil | P |
| Highlight | H |
| Blur | B |
| Counter | N |
| Undo | Cmd+Z |
| Delete selection | Delete/Backspace |

## Tech Stack

- Swift 5.9+ / macOS 13+
- AppKit (NSStatusItem, NSWindow, NSView, NSEvent)
- CoreGraphics (CGDisplayCreateImage, custom drawing)
- Swift Package Manager

## Permissions

On first launch, macOS will ask for **Screen Recording** permission. Grant it in System Settings > Privacy & Security > Screen Recording.
