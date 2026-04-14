import { useState, useCallback, useRef, useEffect } from 'react'
import { AnnotationEditor, exportCanvas } from './components/AnnotationEditor'
import { Toolbar } from './components/Toolbar'
import type { AnnotationTool, ToolConfig } from './types'
import { DEFAULT_TOOL_CONFIG, TOOL_SHORTCUTS } from './types'
import * as fabric from 'fabric'
import { Camera } from 'lucide-react'

export function App() {
  const [imageDataUrl, setImageDataUrl] = useState<string | null>(null)
  const [activeTool, setActiveTool] = useState<AnnotationTool>('rectangle')
  const [toolConfig, setToolConfig] = useState<ToolConfig>(DEFAULT_TOOL_CONFIG)
  const [counterValue, setCounterValue] = useState(1)
  const [toast, setToast] = useState<string | null>(null)

  // Get reference to the Fabric canvas via a hacky but effective approach
  const canvasAccessor = useRef<(() => fabric.Canvas | null) | null>(null)

  // Listen for image from main process
  useEffect(() => {
    window.localshot.onLoadImage((dataUrl) => {
      setImageDataUrl(dataUrl)
      setActiveTool('rectangle') // Default to rectangle tool
      setCounterValue(1) // Reset counter
    })

    // Check for pending screenshot
    window.localshot.getPendingScreenshot().then((dataUrl) => {
      if (dataUrl) {
        setImageDataUrl(dataUrl)
      }
    })
  }, [])

  // Keyboard shortcuts for tools
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Don't trigger shortcuts when typing in text fields
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement
      ) {
        return
      }

      // Check if we're editing text in Fabric
      const canvas = document.querySelector('canvas')
      if (canvas) {
        const fabricCanvas = (canvas as any).__fabric
        if (fabricCanvas) {
          const activeObj = fabricCanvas.getActiveObject()
          if (activeObj instanceof fabric.IText && activeObj.isEditing) return
        }
      }

      const tool = TOOL_SHORTCUTS[e.key.toLowerCase()]
      if (tool) {
        e.preventDefault()
        setActiveTool(tool)
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [])

  const showToast = useCallback((message: string) => {
    setToast(message)
    setTimeout(() => setToast(null), 2000)
  }, [])

  const handleConfigChange = useCallback((partial: Partial<ToolConfig>) => {
    setToolConfig((prev) => ({ ...prev, ...partial }))
  }, [])

  const getCanvasDataUrl = useCallback((): string | null => {
    const canvasEl = document.querySelector('.fabric-canvas-wrapper canvas') as HTMLCanvasElement
    if (!canvasEl) {
      // Fallback: find the fabric canvas
      const allCanvases = document.querySelectorAll('canvas')
      for (const c of allCanvases) {
        const fabricCanvas = (c as any).__fabric || (c as any).fabric
        if (fabricCanvas) {
          return exportCanvas(fabricCanvas)
        }
      }
      // Last resort: use the upper canvas
      if (allCanvases.length > 0) {
        // Try to access through Fabric's global
        return imageDataUrl
      }
    }
    return imageDataUrl
  }, [imageDataUrl])

  const handleCopy = useCallback(() => {
    const dataUrl = getCanvasDataUrl()
    if (dataUrl) {
      window.localshot.copyImage(dataUrl)
      showToast('Copied to clipboard')
    }
  }, [getCanvasDataUrl, showToast])

  const handleSave = useCallback(async () => {
    const dataUrl = getCanvasDataUrl()
    if (dataUrl) {
      const saved = await window.localshot.saveImage(dataUrl)
      if (saved) showToast('Saved')
    }
  }, [getCanvasDataUrl, showToast])

  const handleUndo = useCallback(() => {
    // Dispatch a keyboard event to trigger undo
    window.dispatchEvent(
      new KeyboardEvent('keydown', { key: 'z', metaKey: true })
    )
  }, [])

  const handleClear = useCallback(() => {
    const allCanvases = document.querySelectorAll('canvas')
    for (const c of allCanvases) {
      const fabricCanvas = (c as any).__fabric || (c as any).fabric
      if (fabricCanvas && fabricCanvas.getObjects) {
        const objects = fabricCanvas.getObjects()
        objects.forEach((obj: fabric.Object) => fabricCanvas.remove(obj))
        fabricCanvas.renderAll()
        break
      }
    }
    setCounterValue(1)
  }, [])

  return (
    <div className="h-screen w-screen flex flex-col bg-[#111122] text-white">
      {/* Title bar drag region */}
      <div className="drag-region h-10 flex items-center px-20 bg-[#1a1a2e] border-b border-white/8 shrink-0">
        <div className="flex items-center gap-2 text-white/50 text-xs font-medium">
          <Camera size={14} className="text-accent-red" />
          <span>LocalShot</span>
          {imageDataUrl && (
            <span className="text-white/25 ml-2">
              Press <kbd className="bg-white/10 px-1 py-0.5 rounded text-[10px]">V</kbd> to select,{' '}
              <kbd className="bg-white/10 px-1 py-0.5 rounded text-[10px]">R</kbd> for rectangle
            </span>
          )}
        </div>
      </div>

      {/* Main content */}
      <div className="flex-1 flex min-h-0">
        {/* Sidebar toolbar */}
        <Toolbar
          activeTool={activeTool}
          toolConfig={toolConfig}
          onToolChange={setActiveTool}
          onConfigChange={handleConfigChange}
          onCopy={handleCopy}
          onSave={handleSave}
          onUndo={handleUndo}
          onClear={handleClear}
        />

        {/* Canvas area */}
        {imageDataUrl ? (
          <AnnotationEditor
            imageDataUrl={imageDataUrl}
            activeTool={activeTool}
            toolConfig={toolConfig}
            counterValue={counterValue}
            onCounterIncrement={() => setCounterValue((v) => v + 1)}
          />
        ) : (
          <EmptyState />
        )}
      </div>

      {/* Toast notification */}
      {toast && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 animate-bounce">
          <div className="bg-white/10 backdrop-blur-lg text-white text-sm px-4 py-2 rounded-full border border-white/10 shadow-xl">
            {toast}
          </div>
        </div>
      )}
    </div>
  )
}

function EmptyState() {
  return (
    <div className="flex-1 flex items-center justify-center">
      <div className="text-center max-w-md">
        <div className="w-20 h-20 mx-auto mb-6 rounded-2xl bg-white/5 flex items-center justify-center">
          <Camera size={36} className="text-white/20" />
        </div>
        <h2 className="text-lg font-semibold text-white/70 mb-2">No screenshot loaded</h2>
        <p className="text-sm text-white/30 leading-relaxed mb-6">
          Use the global shortcuts to capture your screen, or the menu bar icon to get started.
        </p>
        <div className="space-y-2 text-xs text-white/25">
          <div className="flex items-center justify-center gap-3">
            <kbd className="bg-white/8 px-2 py-1 rounded font-mono">Cmd+Shift+1</kbd>
            <span>Full screen capture</span>
          </div>
          <div className="flex items-center justify-center gap-3">
            <kbd className="bg-white/8 px-2 py-1 rounded font-mono">Cmd+Shift+2</kbd>
            <span>Area selection</span>
          </div>
        </div>
      </div>
    </div>
  )
}
