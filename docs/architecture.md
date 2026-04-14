# LocalShot Architecture

## Overview
Native macOS screenshot tool built with Swift + AppKit. Menu bar app with screen capture, area selection, annotation editor, and quick overlay. Follows the same architecture as Open Wispr.

## Tech Stack
- **Language:** Swift 5.9
- **UI:** AppKit (NSStatusItem, NSWindow, NSView, Core Graphics)
- **Capture:** CGDisplayCreateImage (native macOS API)
- **Build:** Swift Package Manager (two-target: lib + executable)
- **Bundle:** scripts/bundle-app.sh creates .app with Info.plist + codesign

## Package Structure
```
Package.swift
  LocalShotLib (library) -- all app logic
  localshot (executable) -- entry point only
```

## App Lifecycle
1. `main.swift` sets activation policy to `.accessory` (no dock icon)
2. `AppDelegate` creates StatusBarController, HotkeyManager, ScreenCaptureManager
3. App sits in menu bar, waiting for hotkey or menu click
4. On capture: ScreenCaptureManager -> SelectionWindow (optional) -> QuickOverlayWindow -> AnnotationWindow

## Key Files

| File | Purpose |
|------|---------|
| `main.swift` | Entry point, NSApplication setup |
| `AppDelegate.swift` | Coordinator: capture flow, clipboard, save |
| `StatusBarController.swift` | NSStatusItem, context menu, template icon |
| `HotkeyManager.swift` | NSEvent.addGlobalMonitorForEvents for Cmd+Shift+1/2 |
| `ScreenCaptureManager.swift` | CGDisplayCreateImage wrapper |
| `SelectionWindow.swift` | Transparent fullscreen overlay, drag-to-select |
| `AnnotationTool.swift` | Tool enum, icon drawing, shortcuts, colors |
| `Annotations.swift` | Annotation protocol + 9 concrete types |
| `AnnotationView.swift` | Custom NSView: renders image + annotations, handles mouse |
| `AnnotationWindow.swift` | Editor window with sidebar toolbar |
| `QuickOverlayWindow.swift` | Floating thumbnail with copy/annotate/save buttons |

## Capture Flow
1. User presses Cmd+Shift+1 or Cmd+Shift+2
2. CGDisplayCreateImage captures the display
3. For area: full screenshot shown behind a transparent overlay, user drags to crop
4. Quick overlay appears (bottom-right corner, auto-closes 8s)
5. User clicks "Annotate" to open editor, or "Copy" for clipboard

## Annotation System
- Protocol-based: each annotation type implements `draw(in:)`, `hitTest(point:)`, `move(by:)`
- AnnotationView manages the array, handles mouse events per active tool
- Core Graphics rendering (no third-party canvas library)
- Export renders at full image resolution regardless of view scale
