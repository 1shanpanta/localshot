# LocalShot Data Model

Swift 5.9, AppKit. All types are native — no IPC or serialization layer.

---

## Annotation Protocol

Base protocol for all drawable annotations.

| Property | Type | Description |
|---|---|---|
| id | UUID | Unique identifier |
| color | NSColor | Stroke/fill color |
| strokeWidth | CGFloat | Line thickness |
| isSelected | Bool | Selection state |
| bounds | NSRect | Computed bounding rectangle |

**Methods:**
- `draw(in ctx: CGContext, viewBounds: NSRect)` — render the annotation
- `hitTest(point: NSPoint) -> Bool` — check if point is inside annotation
- `move(by delta: NSPoint)` — translate annotation position

---

## Shape Annotations

| Type | Stored Properties | Drawing Behavior |
|---|---|---|
| RectAnnotation | origin: NSPoint, size: NSSize | Stroked rectangle path |
| EllipseAnnotation | origin: NSPoint, size: NSSize | Stroked ellipse path |
| ArrowAnnotation | start: NSPoint, end: NSPoint | Line + triangular arrowhead at end |
| LineAnnotation | start: NSPoint, end: NSPoint | Straight stroked line |

---

## Text Annotation

| Property | Type | Default |
|---|---|---|
| origin | NSPoint | — |
| text | String | — |
| fontSize | CGFloat | — |

- Rendered with `NSFont.systemFont(ofSize:weight:)` bold
- Inline editing via NSTextField placed over the annotation

---

## Drawing Annotations

| Type | Stored Properties | Drawing Behavior |
|---|---|---|
| FreehandAnnotation | points: [NSPoint] | Connected line segments through all points |
| HighlightAnnotation | origin: NSPoint, size: NSSize | Filled rectangle at 0.3 alpha (semi-transparent) |

---

## Special Annotations

| Type | Stored Properties | Drawing Behavior |
|---|---|---|
| BlurAnnotation | origin: NSPoint, size: NSSize | Pixelated mosaic effect over captured image region |
| CounterAnnotation | center: NSPoint, number: Int, radius: CGFloat (default 16) | Filled circle with white number centered inside |

---

## AnnotationToolType

Enum with 10 cases. Each case carries metadata for toolbar rendering.

| Case | label | shortcut | keyCode (UInt16) | drawIcon() |
|---|---|---|---|---|
| select | Select | V | — | Cursor arrow |
| rectangle | Rectangle | R | — | Rect outline |
| ellipse | Ellipse | E | — | Ellipse outline |
| arrow | Arrow | A | — | Arrow shape |
| line | Line | L | — | Diagonal line |
| text | Text | T | — | "T" letter |
| freehand | Freehand | P | — | Squiggle |
| highlight | Highlight | H | — | Marker stroke |
| blur | Blur | B | — | Grid/mosaic |
| counter | Counter | N | — | Circled number |

---

## Color Palette

8 default colors defined in `defaultColors`. Values are hand-picked RGB (not `.systemRed` etc) so they render consistently against dark screenshots:

| Index | Color | RGB |
|---|---|---|
| 0 | Red | (1.00, 0.23, 0.23) |
| 1 | Orange | (1.00, 0.58, 0.00) |
| 2 | Yellow | (0.98, 0.75, 0.15) |
| 3 | Green | (0.20, 0.83, 0.60) |
| 4 | Blue | (0.29, 0.62, 1.00) |
| 5 | Purple | (0.65, 0.55, 0.98) |
| 6 | White | `.white` |
| 7 | Black | `.black` |

---

## State Management

`AnnotationView` holds all editor state:

| State | Type | Description |
|---|---|---|
| annotations | [Annotation] | All annotations on canvas |
| activeTool | AnnotationToolType | Currently selected tool |
| activeColor | NSColor | Current drawing color |
| activeStrokeWidth | CGFloat | Current stroke thickness |
| activeFontSize | CGFloat | Current text size |
| counterValue | Int | Next counter badge number (auto-increments) |

**Export behavior:**
- View coordinates are scaled to original image coordinates for full-resolution output
- All annotations re-rendered at image scale during export
