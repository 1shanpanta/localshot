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
- `draw(in: NSGraphicsContext, viewBounds: NSRect)` — render the annotation
- `hitTest(point: NSPoint) -> Bool` — check if point is inside annotation
- `move(by: CGSize)` — translate annotation position

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

8 default colors defined in `defaultColors`:

| Index | Color | Approximate NSColor |
|---|---|---|
| 0 | Red | .systemRed |
| 1 | Orange | .systemOrange |
| 2 | Yellow | .systemYellow |
| 3 | Green | .systemGreen |
| 4 | Blue | .systemBlue |
| 5 | Purple | .systemPurple |
| 6 | White | .white |
| 7 | Black | .black |

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
