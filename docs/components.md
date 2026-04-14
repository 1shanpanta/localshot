# LocalShot Components

## Renderer Components

### `App` (`src/renderer/src/App.tsx`)
Root component for the editor window. Manages:
- Active tool state
- Tool configuration (color, stroke, font size)
- Counter value for numbered badges
- Toast notifications
- Keyboard shortcut routing

### `AnnotationEditor` (`src/renderer/src/components/AnnotationEditor.tsx`)
Fabric.js canvas wrapper. Props:
- `imageDataUrl: string | null` -- screenshot to annotate
- `activeTool: AnnotationTool` -- current tool
- `toolConfig: ToolConfig` -- color, stroke width, font size
- `counterValue: number` -- next counter badge number
- `onCounterIncrement: () => void`

Handles all mouse events for drawing shapes, creating text, and blur effects.

### `Toolbar` (`src/renderer/src/components/Toolbar.tsx`)
Sidebar with tool selection, color picker, stroke width, and action buttons. Props:
- `activeTool`, `toolConfig` -- current state
- `onToolChange`, `onConfigChange` -- setters
- `onCopy`, `onSave`, `onUndo`, `onClear` -- action callbacks

### `SelectionOverlay` (`src/renderer/src/components/SelectionOverlay.tsx`)
Fullscreen transparent overlay for area selection. Features:
- Screenshot displayed as background
- Dark overlay with transparent selection hole
- Dimension indicator (W x H)
- Crosshair cursor
- Escape to cancel

### `QuickOverlay` (`src/renderer/src/components/QuickOverlay.tsx`)
Small floating thumbnail shown after capture. Actions:
- Copy to clipboard
- Open in annotation editor
- Save to file
- Close (auto-closes after 8s)

## Types (`src/renderer/src/types.ts`)
- `AnnotationTool` -- union of tool names
- `ToolConfig` -- { color, strokeWidth, fontSize, opacity }
- `DEFAULT_COLORS` -- 9-color palette
- `TOOL_SHORTCUTS` -- keyboard shortcut map
