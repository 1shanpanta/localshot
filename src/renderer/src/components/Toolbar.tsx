import {
  MousePointer2,
  Square,
  Circle,
  ArrowUpRight,
  Minus,
  Type,
  Pencil,
  Highlighter,
  Grid3X3,
  Hash,
  Crop,
  Copy,
  Download,
  Undo2,
  Trash2
} from 'lucide-react'
import type { AnnotationTool, ToolConfig } from '../types'
import { DEFAULT_COLORS, TOOL_LABELS } from '../types'

interface ToolbarProps {
  activeTool: AnnotationTool
  toolConfig: ToolConfig
  onToolChange: (tool: AnnotationTool) => void
  onConfigChange: (config: Partial<ToolConfig>) => void
  onCopy: () => void
  onSave: () => void
  onUndo: () => void
  onClear: () => void
}

const TOOLS: { tool: AnnotationTool; icon: React.ReactNode; shortcut: string }[] = [
  { tool: 'select', icon: <MousePointer2 size={18} />, shortcut: 'V' },
  { tool: 'rectangle', icon: <Square size={18} />, shortcut: 'R' },
  { tool: 'ellipse', icon: <Circle size={18} />, shortcut: 'E' },
  { tool: 'arrow', icon: <ArrowUpRight size={18} />, shortcut: 'A' },
  { tool: 'line', icon: <Minus size={18} />, shortcut: 'L' },
  { tool: 'text', icon: <Type size={18} />, shortcut: 'T' },
  { tool: 'freehand', icon: <Pencil size={18} />, shortcut: 'P' },
  { tool: 'highlight', icon: <Highlighter size={18} />, shortcut: 'H' },
  { tool: 'blur', icon: <Grid3X3 size={18} />, shortcut: 'B' },
  { tool: 'counter', icon: <Hash size={18} />, shortcut: 'N' },
  { tool: 'crop', icon: <Crop size={18} />, shortcut: 'C' }
]

export function Toolbar({
  activeTool,
  toolConfig,
  onToolChange,
  onConfigChange,
  onCopy,
  onSave,
  onUndo,
  onClear
}: ToolbarProps) {
  return (
    <div className="flex flex-col bg-[#1a1a2e] border-r border-white/10">
      {/* Tools */}
      <div className="flex flex-col gap-0.5 p-2">
        <div className="text-[10px] uppercase tracking-wider text-white/30 px-2 py-1 font-medium">
          Tools
        </div>
        {TOOLS.map(({ tool, icon, shortcut }) => (
          <button
            key={tool}
            onClick={() => onToolChange(tool)}
            className={`
              relative flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm transition-all group
              ${
                activeTool === tool
                  ? 'bg-white/15 text-white shadow-sm'
                  : 'text-white/60 hover:bg-white/8 hover:text-white/90'
              }
            `}
            title={`${TOOL_LABELS[tool]} (${shortcut})`}
          >
            {icon}
            <span className="text-xs">{TOOL_LABELS[tool]}</span>
            <span className="ml-auto text-[10px] text-white/25 font-mono group-hover:text-white/40">
              {shortcut}
            </span>
          </button>
        ))}
      </div>

      {/* Divider */}
      <div className="mx-3 my-1 border-t border-white/8" />

      {/* Color picker */}
      <div className="px-3 py-2">
        <div className="text-[10px] uppercase tracking-wider text-white/30 mb-2 font-medium">
          Color
        </div>
        <div className="grid grid-cols-5 gap-1.5">
          {DEFAULT_COLORS.map((color) => (
            <button
              key={color}
              onClick={() => onConfigChange({ color })}
              className={`
                w-6 h-6 rounded-full border-2 transition-all
                ${
                  toolConfig.color === color
                    ? 'border-white scale-110 shadow-lg'
                    : 'border-transparent hover:border-white/30 hover:scale-105'
                }
              `}
              style={{ backgroundColor: color }}
              title={color}
            />
          ))}
        </div>
      </div>

      {/* Stroke width */}
      <div className="px-3 py-2">
        <div className="text-[10px] uppercase tracking-wider text-white/30 mb-2 font-medium">
          Stroke
        </div>
        <div className="flex gap-1">
          {[1, 2, 3, 5, 8].map((w) => (
            <button
              key={w}
              onClick={() => onConfigChange({ strokeWidth: w })}
              className={`
                flex-1 h-8 rounded flex items-center justify-center transition-all
                ${
                  toolConfig.strokeWidth === w
                    ? 'bg-white/15 text-white'
                    : 'bg-white/5 text-white/40 hover:bg-white/10 hover:text-white/70'
                }
              `}
              title={`${w}px`}
            >
              <div
                className="rounded-full"
                style={{
                  width: Math.min(w * 2 + 2, 16),
                  height: Math.min(w * 2 + 2, 16),
                  backgroundColor: toolConfig.color
                }}
              />
            </button>
          ))}
        </div>
      </div>

      {/* Font size (for text tool) */}
      {activeTool === 'text' && (
        <div className="px-3 py-2">
          <div className="text-[10px] uppercase tracking-wider text-white/30 mb-2 font-medium">
            Font Size
          </div>
          <input
            type="range"
            min={12}
            max={72}
            value={toolConfig.fontSize}
            onChange={(e) => onConfigChange({ fontSize: Number(e.target.value) })}
            className="w-full accent-blue-500"
          />
          <div className="text-xs text-white/40 text-center mt-1">{toolConfig.fontSize}px</div>
        </div>
      )}

      {/* Spacer */}
      <div className="flex-1" />

      {/* Actions */}
      <div className="flex flex-col gap-0.5 p-2 border-t border-white/8">
        <div className="text-[10px] uppercase tracking-wider text-white/30 px-2 py-1 font-medium">
          Actions
        </div>
        <button
          onClick={onUndo}
          className="flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-white/60 hover:bg-white/8 hover:text-white/90 transition-all"
          title="Undo (Cmd+Z)"
        >
          <Undo2 size={16} />
          <span className="text-xs">Undo</span>
        </button>
        <button
          onClick={onClear}
          className="flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-white/60 hover:bg-white/8 hover:text-white/90 transition-all"
          title="Clear all annotations"
        >
          <Trash2 size={16} />
          <span className="text-xs">Clear</span>
        </button>

        <div className="mx-1 my-1 border-t border-white/8" />

        <button
          onClick={onCopy}
          className="flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm bg-accent-blue/20 text-accent-blue hover:bg-accent-blue/30 transition-all"
          title="Copy to clipboard (Cmd+C)"
        >
          <Copy size={16} />
          <span className="text-xs font-medium">Copy</span>
        </button>
        <button
          onClick={onSave}
          className="flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm bg-accent-green/20 text-accent-green hover:bg-accent-green/30 transition-all"
          title="Save to file (Cmd+S)"
        >
          <Download size={16} />
          <span className="text-xs font-medium">Save</span>
        </button>
      </div>
    </div>
  )
}
