import { useEffect, useRef, useState, useCallback } from 'react'
import * as fabric from 'fabric'
import type { AnnotationTool, ToolConfig } from '../types'

interface AnnotationEditorProps {
  imageDataUrl: string | null
  activeTool: AnnotationTool
  toolConfig: ToolConfig
  counterValue: number
  onCounterIncrement: () => void
}

export function AnnotationEditor({
  imageDataUrl,
  activeTool,
  toolConfig,
  counterValue,
  onCounterIncrement
}: AnnotationEditorProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const fabricRef = useRef<fabric.Canvas | null>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const drawingRef = useRef<{
    isDrawing: boolean
    startX: number
    startY: number
    activeObject: fabric.Object | null
  }>({
    isDrawing: false,
    startX: 0,
    startY: 0,
    activeObject: null
  })

  // Initialize Fabric canvas
  useEffect(() => {
    if (!canvasRef.current) return

    const canvas = new fabric.Canvas(canvasRef.current, {
      backgroundColor: '#1a1a2e',
      selection: true,
      preserveObjectStacking: true
    })

    fabricRef.current = canvas

    return () => {
      canvas.dispose()
      fabricRef.current = null
    }
  }, [])

  // Load image when provided
  useEffect(() => {
    const canvas = fabricRef.current
    if (!canvas || !imageDataUrl) return

    const imgEl = new Image()
    imgEl.onload = () => {
      const container = containerRef.current
      if (!container) return

      const containerW = container.clientWidth
      const containerH = container.clientHeight

      // Scale image to fit container
      const scale = Math.min(
        containerW / imgEl.naturalWidth,
        containerH / imgEl.naturalHeight,
        1
      )

      const canvasW = Math.round(imgEl.naturalWidth * scale)
      const canvasH = Math.round(imgEl.naturalHeight * scale)

      canvas.setDimensions({ width: canvasW, height: canvasH })

      const fabricImg = new fabric.FabricImage(imgEl, {
        scaleX: scale,
        scaleY: scale,
        selectable: false,
        evented: false,
        erasable: false
      })

      canvas.backgroundImage = fabricImg
      canvas.renderAll()
    }
    imgEl.src = imageDataUrl
  }, [imageDataUrl])

  // Update canvas interaction mode based on active tool
  useEffect(() => {
    const canvas = fabricRef.current
    if (!canvas) return

    if (activeTool === 'select') {
      canvas.isDrawingMode = false
      canvas.selection = true
      canvas.defaultCursor = 'default'
      canvas.hoverCursor = 'move'
      canvas.forEachObject((obj) => {
        obj.selectable = true
        obj.evented = true
      })
    } else if (activeTool === 'freehand') {
      canvas.isDrawingMode = true
      canvas.freeDrawingBrush = new fabric.PencilBrush(canvas)
      canvas.freeDrawingBrush.color = toolConfig.color
      canvas.freeDrawingBrush.width = toolConfig.strokeWidth
      canvas.selection = false
    } else {
      canvas.isDrawingMode = false
      canvas.selection = false
      canvas.defaultCursor = 'crosshair'
      canvas.hoverCursor = 'crosshair'
      canvas.forEachObject((obj) => {
        obj.selectable = false
        obj.evented = false
      })
    }

    canvas.renderAll()
  }, [activeTool, toolConfig.color, toolConfig.strokeWidth])

  // Handle mouse events for shape drawing
  const handleMouseDown = useCallback(
    (e: fabric.TPointerEventInfo) => {
      const canvas = fabricRef.current
      if (!canvas || activeTool === 'select' || activeTool === 'freehand') return

      const pointer = canvas.getScenePoint(e.e)
      drawingRef.current.isDrawing = true
      drawingRef.current.startX = pointer.x
      drawingRef.current.startY = pointer.y

      let obj: fabric.Object | null = null

      switch (activeTool) {
        case 'rectangle': {
          obj = new fabric.Rect({
            left: pointer.x,
            top: pointer.y,
            width: 0,
            height: 0,
            fill: 'transparent',
            stroke: toolConfig.color,
            strokeWidth: toolConfig.strokeWidth,
            strokeUniform: true
          })
          break
        }
        case 'ellipse': {
          obj = new fabric.Ellipse({
            left: pointer.x,
            top: pointer.y,
            rx: 0,
            ry: 0,
            fill: 'transparent',
            stroke: toolConfig.color,
            strokeWidth: toolConfig.strokeWidth,
            strokeUniform: true
          })
          break
        }
        case 'arrow':
        case 'line': {
          const points: [number, number, number, number] = [pointer.x, pointer.y, pointer.x, pointer.y]
          obj = new fabric.Line(points, {
            stroke: toolConfig.color,
            strokeWidth: toolConfig.strokeWidth,
            strokeUniform: true
          })
          break
        }
        case 'highlight': {
          obj = new fabric.Rect({
            left: pointer.x,
            top: pointer.y,
            width: 0,
            height: 0,
            fill: toolConfig.color,
            opacity: 0.3,
            stroke: '',
            strokeWidth: 0
          })
          break
        }
        case 'blur': {
          obj = new fabric.Rect({
            left: pointer.x,
            top: pointer.y,
            width: 0,
            height: 0,
            fill: 'rgba(128, 128, 128, 0.7)',
            stroke: '',
            strokeWidth: 0,
            rx: 4,
            ry: 4
          })
          // Store metadata for blur rendering
          ;(obj as any).__isBlur = true
          break
        }
        case 'text': {
          const text = new fabric.IText('Click to edit', {
            left: pointer.x,
            top: pointer.y,
            fill: toolConfig.color,
            fontSize: toolConfig.fontSize,
            fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
            fontWeight: 'bold',
            editable: true
          })
          canvas.add(text)
          canvas.setActiveObject(text)
          text.enterEditing()
          text.selectAll()
          drawingRef.current.isDrawing = false
          return
        }
        case 'counter': {
          const group = createCounterBadge(pointer.x, pointer.y, counterValue, toolConfig.color)
          canvas.add(group)
          onCounterIncrement()
          drawingRef.current.isDrawing = false
          return
        }
      }

      if (obj) {
        canvas.add(obj)
        drawingRef.current.activeObject = obj
      }
    },
    [activeTool, toolConfig, counterValue, onCounterIncrement]
  )

  const handleMouseMove = useCallback(
    (e: fabric.TPointerEventInfo) => {
      const canvas = fabricRef.current
      if (!canvas || !drawingRef.current.isDrawing) return

      const pointer = canvas.getScenePoint(e.e)
      const { startX, startY, activeObject } = drawingRef.current
      if (!activeObject) return

      const width = pointer.x - startX
      const height = pointer.y - startY

      switch (activeTool) {
        case 'rectangle':
        case 'highlight':
        case 'blur': {
          const rect = activeObject as fabric.Rect
          if (width < 0) rect.set({ left: pointer.x })
          if (height < 0) rect.set({ top: pointer.y })
          rect.set({
            width: Math.abs(width),
            height: Math.abs(height)
          })
          break
        }
        case 'ellipse': {
          const ellipse = activeObject as fabric.Ellipse
          ellipse.set({
            rx: Math.abs(width) / 2,
            ry: Math.abs(height) / 2,
            left: Math.min(startX, pointer.x),
            top: Math.min(startY, pointer.y)
          })
          break
        }
        case 'arrow':
        case 'line': {
          const line = activeObject as fabric.Line
          line.set({ x2: pointer.x, y2: pointer.y })
          break
        }
      }

      canvas.renderAll()
    },
    [activeTool]
  )

  const handleMouseUp = useCallback(() => {
    const canvas = fabricRef.current
    if (!canvas || !drawingRef.current.isDrawing) return

    const { activeObject } = drawingRef.current
    drawingRef.current.isDrawing = false
    drawingRef.current.activeObject = null

    if (!activeObject) return

    // For arrows, add arrowhead after line is drawn
    if (activeTool === 'arrow' && activeObject instanceof fabric.Line) {
      addArrowHead(canvas, activeObject, toolConfig.color, toolConfig.strokeWidth)
    }

    // For blur, apply pixelation effect
    if ((activeObject as any).__isBlur) {
      applyBlurEffect(canvas, activeObject as fabric.Rect)
    }

    // Make the object selectable
    activeObject.selectable = activeTool === 'select'
    activeObject.evented = activeTool === 'select'
    canvas.renderAll()
  }, [activeTool, toolConfig])

  // Attach canvas events
  useEffect(() => {
    const canvas = fabricRef.current
    if (!canvas) return

    canvas.on('mouse:down', handleMouseDown)
    canvas.on('mouse:move', handleMouseMove)
    canvas.on('mouse:up', handleMouseUp)

    return () => {
      canvas.off('mouse:down', handleMouseDown)
      canvas.off('mouse:move', handleMouseMove)
      canvas.off('mouse:up', handleMouseUp)
    }
  }, [handleMouseDown, handleMouseMove, handleMouseUp])

  // Delete key handler
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const canvas = fabricRef.current
      if (!canvas) return

      if (e.key === 'Delete' || e.key === 'Backspace') {
        // Don't delete if editing text
        const activeObj = canvas.getActiveObject()
        if (activeObj instanceof fabric.IText && activeObj.isEditing) return

        const activeObjects = canvas.getActiveObjects()
        activeObjects.forEach((obj) => canvas.remove(obj))
        canvas.discardActiveObject()
        canvas.renderAll()
      }

      // Ctrl/Cmd+Z undo
      if ((e.metaKey || e.ctrlKey) && e.key === 'z') {
        const objects = canvas.getObjects()
        if (objects.length > 0) {
          canvas.remove(objects[objects.length - 1])
          canvas.renderAll()
        }
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [])

  return (
    <div
      ref={containerRef}
      className="flex-1 flex items-center justify-center bg-[#111122] overflow-hidden p-4"
    >
      <canvas ref={canvasRef} />
    </div>
  )
}

// Helper: create counter badge (numbered circle)
function createCounterBadge(
  x: number,
  y: number,
  num: number,
  color: string
): fabric.Group {
  const radius = 16
  const circle = new fabric.Circle({
    radius,
    fill: color,
    originX: 'center',
    originY: 'center'
  })

  const text = new fabric.FabricText(String(num), {
    fontSize: 16,
    fill: '#ffffff',
    fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
    fontWeight: 'bold',
    originX: 'center',
    originY: 'center'
  })

  return new fabric.Group([circle, text], {
    left: x - radius,
    top: y - radius
  })
}

// Helper: add arrowhead to a line
function addArrowHead(
  canvas: fabric.Canvas,
  line: fabric.Line,
  color: string,
  strokeWidth: number
): void {
  const x1 = line.x1!
  const y1 = line.y1!
  const x2 = line.x2!
  const y2 = line.y2!

  const angle = Math.atan2(y2 - y1, x2 - x1)
  const headLen = Math.max(12, strokeWidth * 4)

  const p1x = x2 - headLen * Math.cos(angle - Math.PI / 6)
  const p1y = y2 - headLen * Math.sin(angle - Math.PI / 6)
  const p2x = x2 - headLen * Math.cos(angle + Math.PI / 6)
  const p2y = y2 - headLen * Math.sin(angle + Math.PI / 6)

  const arrowHead = new fabric.Polygon(
    [
      { x: x2, y: y2 },
      { x: p1x, y: p1y },
      { x: p2x, y: p2y }
    ],
    {
      fill: color,
      stroke: color,
      strokeWidth: 1,
      selectable: false,
      evented: false
    }
  )

  canvas.add(arrowHead)
}

// Helper: apply blur/pixelation effect to area
function applyBlurEffect(canvas: fabric.Canvas, rect: fabric.Rect): void {
  // Create a pixelated overlay by rendering small blocks
  const left = rect.left!
  const top = rect.top!
  const width = rect.width!
  const height = rect.height!

  // Use a mosaic pattern for the blur effect
  const blockSize = 8
  const rects: fabric.Rect[] = []

  for (let y = 0; y < height; y += blockSize) {
    for (let x = 0; x < width; x += blockSize) {
      // Random gray values for pixelation appearance
      const gray = Math.floor(Math.random() * 60) + 140
      const block = new fabric.Rect({
        left: left + x,
        top: top + y,
        width: Math.min(blockSize, width - x),
        height: Math.min(blockSize, height - y),
        fill: `rgb(${gray}, ${gray}, ${gray})`,
        selectable: false,
        evented: false,
        strokeWidth: 0
      })
      rects.push(block)
    }
  }

  // Remove the original rect and add the group
  canvas.remove(rect)
  const group = new fabric.Group(rects, {
    left,
    top,
    selectable: false,
    evented: false
  })
  canvas.add(group)
}

// Export canvas as data URL
export function exportCanvas(canvas: fabric.Canvas): string {
  return canvas.toDataURL({
    format: 'png',
    quality: 1,
    multiplier: 2 // Retina quality
  })
}
