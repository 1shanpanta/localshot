# LocalShot Components

Native macOS screenshot + annotation tool. Swift 5.9, AppKit, CoreGraphics, CoreImage, QuartzCore. macOS 13+.

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
- `captureFullScreen()` — capture entire display
- `captureArea()` — launch area selection flow
- `showOverlay()` — display QuickOverlayWindow with captured image
- `openEditor()` — open AnnotationWindow with image
- `copyToClipboard()` — copy current image to pasteboard
- `saveImage()` — save current image to disk

---

## StatusBarController

NSStatusItem in the macOS menu bar.

- Custom crosshair icon
- `flashIcon()` — visual feedback on copy

**Menu items:**

| Item | Shortcut |
|---|---|
| Capture Full Screen | Cmd+Shift+S |
| Capture Area | Cmd+Shift+A |
| Quit | — |

---

## HotkeyManager

Global + local hotkey listener. Installs both `NSEvent.addGlobalMonitorForEvents` (fires when other apps are frontmost) and `addLocalMonitorForEvents` (fires when LocalShot owns the focused window) so the hotkey works in all states.

| Action | Shortcut | keyCode |
|---|---|---|
| Capture Full Screen | Cmd+Shift+S | 1 |
| Capture Area | Cmd+Shift+A | 0 |

---

## ScreenCaptureManager

Thin wrapper around `CGWindowListCreateImage`.

- `captureFullScreen()` — captures the full display
- `captureRect()` — captures a specific CGRect region

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

**Behavior:**
- Auto-closes after 8 seconds
- Fade-in animation on appear

---

## AnnotationWindow

Main editor NSWindow. Dark sidebar + canvas layout.

**Sidebar contents:**
- 10 tool buttons with keyboard shortcuts
- 8-color palette
- 5 stroke width options
- Action buttons: Copy, Save, Undo, Clear

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
- `draw(in:viewBounds:)`
- `hitTest(point:) -> Bool`
- `move(by: CGSize)`

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
