import { useState, useRef, useCallback } from 'react'

interface SelectionRect {
  startX: number
  startY: number
  endX: number
  endY: number
}

export function SelectionOverlay() {
  const [screenshot, setScreenshot] = useState<string | null>(null)
  const [selection, setSelection] = useState<SelectionRect | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const imgRef = useRef<HTMLImageElement | null>(null)

  // Listen for screenshot data from main process
  useState(() => {
    window.localshot.onSetScreenshot((dataUrl) => {
      const img = new Image()
      img.onload = () => {
        imgRef.current = img
        setScreenshot(dataUrl)
      }
      img.src = dataUrl
    })
  })

  const getNormalizedRect = useCallback(
    (sel: SelectionRect) => ({
      x: Math.min(sel.startX, sel.endX),
      y: Math.min(sel.startY, sel.endY),
      width: Math.abs(sel.endX - sel.startX),
      height: Math.abs(sel.endY - sel.startY)
    }),
    []
  )

  const handleMouseDown = useCallback(
    (e: React.MouseEvent) => {
      setIsDragging(true)
      setSelection({
        startX: e.clientX,
        startY: e.clientY,
        endX: e.clientX,
        endY: e.clientY
      })
    },
    []
  )

  const handleMouseMove = useCallback(
    (e: React.MouseEvent) => {
      if (!isDragging || !selection) return
      setSelection((prev) =>
        prev ? { ...prev, endX: e.clientX, endY: e.clientY } : null
      )
    },
    [isDragging, selection]
  )

  const handleMouseUp = useCallback(() => {
    if (!isDragging || !selection || !imgRef.current) return
    setIsDragging(false)

    const rect = getNormalizedRect(selection)
    if (rect.width < 10 || rect.height < 10) {
      // Too small, cancel
      setSelection(null)
      return
    }

    // Crop the screenshot to the selection area
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')!
    const img = imgRef.current

    // Account for device pixel ratio
    const dpr = window.devicePixelRatio || 1
    const scaleX = img.naturalWidth / window.innerWidth
    const scaleY = img.naturalHeight / window.innerHeight

    canvas.width = rect.width * scaleX
    canvas.height = rect.height * scaleY

    ctx.drawImage(
      img,
      rect.x * scaleX,
      rect.y * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
      0,
      0,
      canvas.width,
      canvas.height
    )

    const croppedDataUrl = canvas.toDataURL('image/png')
    window.localshot.sendAreaSelected(croppedDataUrl)
  }, [isDragging, selection, getNormalizedRect])

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      window.localshot.sendSelectionCancelled()
    }
  }, [])

  const rect = selection ? getNormalizedRect(selection) : null

  return (
    <div
      className="fixed inset-0"
      style={{ cursor: 'crosshair' }}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onKeyDown={handleKeyDown}
      tabIndex={0}
      autoFocus
    >
      {/* Screenshot as background */}
      {screenshot && (
        <img
          src={screenshot}
          className="fixed inset-0 w-full h-full object-cover"
          draggable={false}
          alt=""
        />
      )}

      {/* Dark overlay with hole for selection */}
      <div className="fixed inset-0" style={{ background: 'rgba(0, 0, 0, 0.4)' }}>
        {rect && rect.width > 0 && rect.height > 0 && (
          <div
            className="absolute"
            style={{
              left: rect.x,
              top: rect.y,
              width: rect.width,
              height: rect.height,
              background: 'transparent',
              boxShadow: '0 0 0 9999px rgba(0, 0, 0, 0.4)',
              border: '2px solid rgba(255, 255, 255, 0.8)',
              zIndex: 10
            }}
          />
        )}
      </div>

      {/* Dimension indicator */}
      {rect && rect.width > 0 && rect.height > 0 && (
        <div
          className="absolute px-2 py-1 rounded text-xs font-mono text-white"
          style={{
            left: rect.x,
            top: rect.y - 28,
            background: 'rgba(0, 0, 0, 0.75)',
            backdropFilter: 'blur(4px)',
            zIndex: 20
          }}
        >
          {Math.round(rect.width)} x {Math.round(rect.height)}
        </div>
      )}

      {/* Crosshair guides */}
      {!isDragging && (
        <div className="fixed inset-0 pointer-events-none" style={{ zIndex: 5 }}>
          <div className="fixed text-white/50 text-sm bottom-8 left-1/2 -translate-x-1/2 bg-black/60 px-4 py-2 rounded-lg backdrop-blur-sm">
            Drag to select area. Press <kbd className="bg-white/20 px-1.5 py-0.5 rounded text-xs ml-1">Esc</kbd> to cancel.
          </div>
        </div>
      )}
    </div>
  )
}
