# LocalShot Architecture

## Overview
LocalShot is a macOS screenshot tool built with Electron + React + TypeScript. It provides screen capture, annotation, and quick sharing -- a local alternative to CleanShot X.

## Tech Stack
- **Framework:** Electron 34 (Chromium-based desktop app)
- **Build:** electron-vite (Vite-based build for main/preload/renderer)
- **UI:** React 19 + TypeScript + Tailwind CSS
- **Canvas:** Fabric.js 6 for annotation editor
- **Icons:** Lucide React

## Process Architecture

### Main Process (`src/main/`)
- `index.ts` -- App lifecycle, window management, global shortcuts
- `capture.ts` -- Screen capture using macOS native `screencapture` CLI
- `tray.ts` -- System tray (menu bar) icon and context menu
- `ipc.ts` -- IPC message handlers between main <-> renderer

### Preload (`src/preload/`)
- `index.ts` -- Context bridge exposing `window.localshot` API to renderer

### Renderer (`src/renderer/`)
Three separate HTML entry points, each a mini React app:
1. **Editor** (`index.html`) -- Main annotation editor window
2. **Selection** (`selection.html`) -- Transparent fullscreen overlay for area selection
3. **Overlay** (`overlay.html`) -- Quick access thumbnail after capture

## Capture Flow
1. User triggers via global shortcut or tray menu
2. **Full screen:** `screencapture -x` captures entire screen to temp PNG
3. **Area select:** Full screen captured first, then selection overlay shown with screenshot as background. User drags to select region, cropped client-side on canvas
4. Cropped/full image sent to quick overlay (thumbnail in corner)
5. User can Copy, Save, or open Annotate editor from overlay

## Annotation Tools
All annotation happens on a Fabric.js canvas with the screenshot as background image:
- **Rectangle** (red by default) -- the signature feature
- **Ellipse, Arrow, Line** -- standard shapes
- **Text** -- editable text overlay
- **Freehand** -- pencil drawing with auto-smoothing
- **Highlight** -- semi-transparent color overlay
- **Blur** -- mosaic pixelation effect
- **Counter** -- numbered badges (1, 2, 3...)

## Key Decisions
- macOS `screencapture` CLI over Electron `desktopCapturer` for reliability
- Fabric.js over raw Canvas for object manipulation (select, move, resize, delete)
- Separate HTML entry points per window to keep bundle sizes small
- Template image for tray icon (auto-adapts to dark/light menu bar)
- Menu bar only app (dock icon hidden) to stay out of the way
