# LocalShot Data Model

## IPC Messages

### Selection Window -> Main
- `selection:area-selected` (croppedDataUrl: string) -- user completed area selection
- `selection:cancelled` -- user pressed Escape

### Overlay -> Main
- `overlay:open-editor` (imageDataUrl?: string) -- open annotation editor
- `overlay:close` -- dismiss overlay
- `overlay:copy` (imageDataUrl: string) -- copy image to clipboard

### Editor -> Main
- `editor:copy` (imageDataUrl: string) -- copy annotated image
- `editor:save` (imageDataUrl: string) -> boolean -- save dialog, returns success
- `editor:get-pending` -> string | null -- retrieve pending screenshot

### Main -> Selection
- `selection:set-screenshot` (dataUrl: string) -- provide screenshot for selection bg

### Main -> Overlay
- `overlay:set-image` (dataUrl: string, bounds: { width, height }) -- set thumbnail

### Main -> Editor
- `editor:load-image` (dataUrl: string) -- load screenshot into editor

## Annotation Objects (Fabric.js)
All annotations are Fabric.js objects on the canvas:
- `fabric.Rect` -- rectangles, highlights, blur base
- `fabric.Ellipse` -- ellipses
- `fabric.Line` -- lines and arrow shafts
- `fabric.Polygon` -- arrowheads
- `fabric.IText` -- editable text
- `fabric.PencilBrush` paths -- freehand drawing
- `fabric.Group` -- counter badges (circle + text), blur mosaics

## Configuration
- `ToolConfig` -- per-session tool settings (not persisted yet)
- Global shortcuts: Cmd+Shift+1 (fullscreen), Cmd+Shift+2 (area)
- Tool shortcuts: V, R, E, A, L, T, P, H, B, N, C
