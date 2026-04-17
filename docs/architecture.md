# LocalShot Architecture

## Overview
Native macOS screenshot tool built with Swift + AppKit. Menu bar app with screen capture, area selection, annotation editor, and quick overlay. Follows the same architecture as Open Wispr.

## Tech Stack
- **Language:** Swift 5.9
- **UI:** AppKit (NSStatusItem, NSWindow, NSView, Core Graphics)
- **Capture:** CGWindowListCreateImage (native macOS API)
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
| `HotkeyManager.swift` | NSEvent global + local monitors for Cmd+Shift+S / Cmd+Shift+A |
| `ScreenCaptureManager.swift` | CGWindowListCreateImage wrapper |
| `SelectionWindow.swift` | Transparent fullscreen overlay, drag-to-select |
| `AnnotationTool.swift` | Tool enum, icon drawing, shortcuts, colors |
| `Annotations.swift` | Annotation protocol + 9 concrete types |
| `AnnotationView.swift` | Custom NSView: renders image + annotations, handles mouse |
| `AnnotationWindow.swift` | Editor window with sidebar toolbar |
| `QuickOverlayWindow.swift` | Floating thumbnail with copy/annotate/save buttons |

## Permissions
- **Screen Recording:** checked on launch via `CGPreflightScreenCaptureAccess()`, prompts via `CGRequestScreenCaptureAccess()`. Re-checked before each capture.
- **Input Monitoring:** checked in HotkeyManager via `CGPreflightListenEventAccess()`, needed for global hotkey events.

## Capture Flow
1. User presses Cmd+Shift+S or Cmd+Shift+A
2. Permission gate: Screen Recording checked, prompted if missing
3. CGWindowListCreateImage captures the display
4. For area: full screenshot shown behind transparent overlay, user drags to crop
5. Quick overlay appears (bottom-right corner, slide-up animation, auto-closes 5s)
6. User clicks thumbnail or "Annotate" to open editor, "Copy" for clipboard, "Save" for Desktop

## Annotation System
- Protocol-based: each annotation type implements `draw(in:)`, `hitTest(point:)`, `move(by:)`
- AnnotationView manages the array, handles mouse events per active tool
- Blur uses real image pixels via BlurImageProvider protocol (pixelated mosaic sampling)
- Core Graphics rendering (no third-party canvas library)
- Export renders at full image resolution regardless of view scale
- Keyboard shortcuts: tool keys (V/R/E/A/L/T/P/H/B/N), Cmd+Z undo, Cmd+C copy, Cmd+S save, Escape deselect/select tool, Delete remove selected
