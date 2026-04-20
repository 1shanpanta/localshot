# LocalShot

A free, open-source, native macOS screenshot tool with annotation — in the spirit of CleanShot X and Shottr.

Built with Swift + AppKit. No Electron, no WebViews. Menu bar app, no Dock icon, ~1 MB binary.

![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)
![macOS](https://img.shields.io/badge/macOS-13%2B-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

---

## Features

- **Capture** — full screen or drag-to-select area, with a crosshair overlay and live pixel dimensions
- **Quick overlay** — a floating thumbnail appears after every capture with one-click **Copy / Annotate / Save**. Auto-dismisses, pauses on hover
- **Annotation editor** — rectangles, ellipses, arrows, lines, text, freehand, highlight, pixel-blur (real pixel sampling, not a generic mosaic), and numbered counter badges
- **Keyboard-first** — every tool has a single-key shortcut; capture hotkeys work while any other app is focused
- **Multi-monitor aware** — capture, selection, and overlay all follow the screen your cursor is on
- **Menu bar only** — lives in the status bar, no Dock icon, no window unless you want one

## Install

Download or clone, then:

```bash
swift build -c release
bash scripts/bundle-app.sh
cp -r LocalShot.app /Applications/
open /Applications/LocalShot.app
```

The app lives in your menu bar (viewfinder icon).

## First-launch permissions

LocalShot needs two TCC permissions. Both prompts appear automatically on first use — they're required for any global-hotkey screenshot tool:

| Permission | Why |
|---|---|
| **Screen Recording** | To capture pixels outside our own windows. |
| **Input Monitoring** | To respond to the global `Cmd+Shift+S` / `Cmd+Shift+A` hotkeys from any app. |

Grant both in **System Settings → Privacy & Security**, then relaunch.

## Capture shortcuts

| Action | Shortcut |
|---|---|
| Capture full screen | **⌘⇧S** |
| Capture area (drag to select) | **⌘⇧A** |

These are consumed by LocalShot — the focused app will **not** also see them (unlike the default `NSEvent` global monitor, LocalShot uses a `CGEventTap` so Cmd+Shift+S won't also open "Save As" in your editor).

Hold Esc during area select to cancel.

## Editor shortcuts

Single-key tool switches (no modifier):

| Key | Tool |
|---|---|
| **V** | Select / move |
| **R** | Rectangle |
| **E** | Ellipse |
| **A** | Arrow |
| **L** | Line |
| **T** | Text |
| **P** | Pencil (freehand) |
| **H** | Highlight |
| **B** | Blur (pixelated) |
| **N** | Counter (numbered badge) |

Editor commands:

| Shortcut | Action |
|---|---|
| **⌘Z** | Undo last annotation |
| **Delete** | Remove selected annotation |
| **⌘C** | Copy the annotated image to clipboard |
| **⌘S** | Save the annotated image (file dialog) |
| **⌘W** | Close the editor |
| **Esc** | Deselect, or switch to Select tool |

## Build from source

```bash
# Debug build + run directly
swift build
.build/debug/localshot

# Release build + .app bundle
swift build -c release
bash scripts/bundle-app.sh
```

The bundle script signs with a hard-coded Apple Development identity. Edit `scripts/bundle-app.sh` if yours differs — without a stable signing identity, macOS will re-prompt for Screen Recording permission on every rebuild.

## Tech stack

- **Language:** Swift 5.9 · **Target:** macOS 13+
- **UI:** AppKit — `NSStatusItem`, `NSWindow`, custom `NSView`, `CGContext`
- **Capture:** `CGWindowListCreateImage` (per-screen, `.bestResolution`)
- **Hotkey:** `CGEventTap` with `defaultTap` (can consume events)
- **Build:** Swift Package Manager, two-target (library + executable)

See `docs/architecture.md`, `docs/components.md`, `docs/data-model.md` for deep details.

## What LocalShot is *not*

- Not a drop-in CleanShot X replacement yet — no scrolling capture, no OCR, no video recording, no cloud upload, no GIF creation.
- Not sandboxed — that's intentional. A screenshot tool with global hotkeys by definition can't be sandboxed.
- Not universal (arm64-only currently). Open a PR if you need x86_64.

## Roadmap

- [ ] Scrolling / full-page capture
- [ ] Recent-captures history (gallery view)
- [ ] Freehand stroke smoothing (Catmull-Rom)
- [ ] Custom colors (beyond the 8 presets)
- [ ] Shutter sound on capture (opt-in)
- [ ] Migrate to `ScreenCaptureKit` (silences `CGWindowList*` deprecation; macOS 14+)
- [ ] Universal binary (arm64 + x86_64)
- [ ] Export as GIF / video

## Known limitations

- **Input Monitoring re-prompt on rebuild if codesign identity changes** — rebuilds signed with a different certificate register as a new app to TCC. Use the same developer identity (or ad-hoc sign consistently) to persist the permission.
- **`CGWindowListCreateImage` is deprecated on macOS 14+** — still works fine today; migration to `ScreenCaptureKit` is on the roadmap.

## Contributing

Issues and pull requests welcome. Keep changes focused; see `CLAUDE.md` style guidance if you're running agents on the codebase.

## License

MIT
