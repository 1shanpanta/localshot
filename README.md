# LocalShot

Local screenshot tool with annotation for macOS. A free, open-source alternative to CleanShot X.

## Features

- **Screen Capture** -- Full screen and area selection with crosshair overlay
- **Annotation Editor** -- Rectangle (red boxes!), ellipse, arrow, line, text, freehand, highlight, blur, counter badges
- **Quick Access Overlay** -- Floating thumbnail after capture with one-click copy/save/annotate
- **Menu Bar App** -- Lives in your menu bar, stays out of the way
- **Global Shortcuts** -- Cmd+Shift+1 (full screen), Cmd+Shift+2 (area select)
- **Keyboard-Driven** -- Every tool has a single-key shortcut (V, R, A, T, P, etc.)
- **Copy & Save** -- Clipboard copy and file save with Retina quality export

## Setup

```bash
# Install dependencies
npm install

# Run in development
npm run dev

# Build for production
npm run build

# Package as .app
npm run package
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
| Crop | C |
| Undo | Cmd+Z |
| Delete selection | Delete/Backspace |

## Tech Stack

- Electron 34
- React 19 + TypeScript
- Fabric.js 6 (canvas annotation)
- Tailwind CSS
- Lucide Icons
- electron-vite (build tooling)

## Permissions

On first run, macOS will ask for Screen Recording permission. Grant it in System Settings > Privacy & Security > Screen Recording.
