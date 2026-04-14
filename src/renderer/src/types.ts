export type AnnotationTool =
  | 'select'
  | 'rectangle'
  | 'ellipse'
  | 'arrow'
  | 'line'
  | 'text'
  | 'freehand'
  | 'highlight'
  | 'blur'
  | 'counter'
  | 'crop'

export interface ToolConfig {
  color: string
  strokeWidth: number
  fontSize: number
  opacity: number
}

export const DEFAULT_COLORS = [
  '#ff3b3b', // Red (default for rectangles)
  '#ff9500', // Orange
  '#fbbf24', // Yellow
  '#34d399', // Green
  '#4a9eff', // Blue
  '#a78bfa', // Purple
  '#ec4899', // Pink
  '#ffffff', // White
  '#000000', // Black
]

export const DEFAULT_TOOL_CONFIG: ToolConfig = {
  color: '#ff3b3b',
  strokeWidth: 3,
  fontSize: 20,
  opacity: 1
}

export const TOOL_LABELS: Record<AnnotationTool, string> = {
  select: 'Select',
  rectangle: 'Rectangle',
  ellipse: 'Ellipse',
  arrow: 'Arrow',
  line: 'Line',
  text: 'Text',
  freehand: 'Pencil',
  highlight: 'Highlight',
  blur: 'Blur',
  counter: 'Counter',
  crop: 'Crop'
}

export const TOOL_SHORTCUTS: Record<string, AnnotationTool> = {
  v: 'select',
  r: 'rectangle',
  e: 'ellipse',
  a: 'arrow',
  l: 'line',
  t: 'text',
  p: 'freehand',
  h: 'highlight',
  b: 'blur',
  n: 'counter',
  c: 'crop'
}
