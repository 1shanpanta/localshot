# LocalShot Components

Native macOS screenshot + annotation tool. Swift 5.9, AppKit, CoreGraphics, QuartzCore, Carbon (for HIToolbox keycodes). macOS 13+.

---

## AppDelegate

Central orchestrator. Owns all major components.

| Managed Component | Role |
|---|---|
| StatusBarController | Menu bar icon + menu |
| HotkeyManager | Global keyboard shortcuts |
| ScreenCaptureManager | Screenshot capture |
| SelectionWindow | Area selection overlay |
| QuickOverlayWindow | Post-capture thumbnail |
| AnnotationWindow | Full editor |

**Key methods:**
- `captureFullScreen()` — capture entire active screen
- `captureArea()` — launch area selection flow
- `showOverlay(image:on:)` — display QuickOverlayWindow with captured image
- `openEditor(with:)` — open AnnotationWindow with image; prompts to discard if existing editor has unsaved annotations
- `copyToClipboard(image:)` — copy current image to pasteboard
- `quickSaveToDesktop(image:)` — write a `LocalShot YYYY-MM-DD at HH.mm.ss.png` file to the user's Desktop
- `windowWillClose(_:)` — `NSWindowDelegate` callback that releases the editor reference (and its screenshot) the moment the user closes the editor

---

## StatusBarController

NSStatusItem in the macOS menu bar.

- Custom hand-drawn viewfinder/crosshair icon (template-tinted)
- `flashCopied()` — checkmark glyph flash after Copy
- `flashSaved()` — down-arrow glyph flash after Save (lets the user tell copy from save apart at a glance)

**Menu items:**

| Item | Shortcut |
|---|---|
| Capture Full Screen | Cmd+Shift+S |
| Capture Area | Cmd+Shift+A |
| Quit | — |

---

## HotkeyManager

`CGEventTap` on `.cgSessionEventTap` with `.defaultTap` options, so LocalShot can **consume** the matching keyDown — the focused app never receives Cmd+Shift+S / Cmd+Shift+A. Plain `NSEvent` monitors cannot consume events, which is why this replaced the earlier monitor-based implementation.

Filters to `[.maskCommand, .maskShift]` exactly (rejects Ctrl/Option to stay out of the way), drops auto-repeat, and debounces fires to 500ms. Self-heals from `tapDisabledByTimeout` / `tapDisabledByUserInput` by re-enabling the tap.

Requires the **Input Monitoring** TCC permission (`NSInputMonitoringUsageDescription`).

| Action | Shortcut | keyCode |
|---|---|---|
| Capture Full Screen | Cmd+Shift+S | 1 |
| Capture Area | Cmd+Shift+A | 0 |

---

## ScreenCaptureManager

Thin wrapper around `CGWindowListCreateImage`.

- `captureScreen(_ screen: NSScreen)` — captures the full frame of a specific NSScreen, converting NSScreen's bottom-left coordinates into CG global top-left coordinates relative to the primary display
- `captureRect(_ rect: CGRect)` — captures a specific CGRect region in CG global coordinates

---

## SelectionWindow

Transparent fullscreen NSWindow for area selection. Contains `SelectionView` (NSView subclass).

**Behavior:**
- Crosshair cursor
- Drag-to-select rectangle
- Dark overlay with transparent cutout over selected area
- Dimension label showing pixel dimensions (W x H)
- Esc to cancel

---

## QuickOverlayWindow

NSPanel floating thumbnail in bottom-right corner. Shown immediately after capture.

**Action bar:**
- Copy
- Annotate
- Save
- Close

**Thumbnail interactions:**
- **Click** — opens the annotation editor
- **Drag-out** — initiates an `NSDraggingSession` with a temp PNG file URL on the pasteboard, so you can drop the screenshot into Claude Code, Slack, Messages, Finder, mail composers, etc. Click vs drag is disambiguated by a 4pt movement threshold

**Behavior:**
- Auto-closes after 5 seconds (paused while cursor is over the overlay)
- Fade + 20pt slide-up animation on appear
- `.nonactivatingPanel` so opening it doesn't steal focus from your current app

---

## AnnotationWindow

Main editor NSWindow. Dark sidebar + canvas layout. Non-resizable; minimum canvas size is 320×600 (the floor that keeps the sidebar layout from collapsing).

**Sidebar contents:**
- 10 tool buttons with single-key shortcuts
- 8-color palette (18pt circular swatches, fits inside the 156pt color row)
- 5 stroke width options
- Action buttons: Copy, Save, Undo, Clear — implemented as `FlatButton`, a private `NSButton` subclass that suppresses macOS's default recessed pressed-overlay and replaces it with a subtle alpha-dim press animation

**Canvas:** `AnnotationView` (see below)

---

## AnnotationView

Custom NSView that renders the screenshot + all annotations.

**Responsibilities:**
- Mouse event handling for all tools (mouseDown, mouseDragged, mouseUp)
- Inline text field editing for TextAnnotation
- Annotation selection and dragging
- Keyboard shortcuts for tool switching
- Export at full image resolution (scales view coordinates to image coordinates)

---

## AnnotationTool

`AnnotationToolType` enum with 10 cases.

| Tool | Label | Shortcut | keyCode | Description |
|---|---|---|---|---|
| select | Select | V | — | Select/move annotations |
| rectangle | Rectangle | R | — | Draw rectangles |
| ellipse | Ellipse | E | — | Draw ellipses |
| arrow | Arrow | A | — | Draw arrows with arrowheads |
| line | Line | L | — | Draw straight lines |
| text | Text | T | — | Place editable text |
| freehand | Freehand | P | — | Freehand pencil drawing |
| highlight | Highlight | H | — | Semi-transparent highlight |
| blur | Blur | B | — | Pixelated mosaic blur |
| counter | Counter | N | — | Numbered circle badges |

- Each case has `drawIcon()` for toolbar rendering
- `defaultColors` — array of 8 default NSColor values

---

## Annotations

`Annotation` protocol + 9 concrete implementations.

**Protocol requirements:**
- `id: UUID`
- `color: NSColor`
- `strokeWidth: CGFloat`
- `isSelected: Bool`
- `bounds: NSRect`
- `draw(in ctx: CGContext, viewBounds: NSRect)`
- `hitTest(point: NSPoint) -> Bool`
- `move(by delta: NSPoint)`

**Implementations:**

| Type | Properties | Notes |
|---|---|---|
| RectAnnotation | origin, size | Stroked rectangle |
| EllipseAnnotation | origin, size | Stroked ellipse |
| ArrowAnnotation | start, end | Line + arrowhead |
| LineAnnotation | start, end | Straight line |
| TextAnnotation | origin, text, fontSize | Bold system font |
| FreehandAnnotation | points array | Connected line segments |
| HighlightAnnotation | origin, size | Semi-transparent fill (0.3 alpha) |
| BlurAnnotation | origin, size | Pixelated mosaic effect |
| CounterAnnotation | center, number, radius=16 | Filled circle with white number |

- All selected annotations render `drawSelectionHandles()` (corner/edge handles)
