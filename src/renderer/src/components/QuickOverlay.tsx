import { useState } from 'react'
import {
  Copy,
  Pencil,
  Download,
  X
} from 'lucide-react'

export function QuickOverlay() {
  const [imageDataUrl, setImageDataUrl] = useState<string | null>(null)

  useState(() => {
    window.localshot.onSetOverlayImage((dataUrl) => {
      setImageDataUrl(dataUrl)
    })
  })

  if (!imageDataUrl) {
    return (
      <div className="w-full h-full flex items-center justify-center bg-black/80 rounded-xl">
        <div className="animate-pulse text-white/40 text-sm">Capturing...</div>
      </div>
    )
  }

  return (
    <div className="w-full h-full flex flex-col bg-[#1a1a2e] rounded-xl overflow-hidden shadow-2xl border border-white/10">
      {/* Screenshot thumbnail */}
      <div className="flex-1 relative overflow-hidden">
        <img
          src={imageDataUrl}
          className="w-full h-full object-cover"
          alt="Screenshot"
          draggable={false}
        />
        {/* Gradient fade at bottom */}
        <div className="absolute inset-x-0 bottom-0 h-8 bg-gradient-to-t from-[#1a1a2e] to-transparent" />
      </div>

      {/* Action bar */}
      <div className="flex items-center gap-1 px-2 py-2 bg-[#1a1a2e]">
        <button
          onClick={() => {
            window.localshot.copyFromOverlay(imageDataUrl)
          }}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-md bg-white/10 hover:bg-white/20 text-white text-xs transition-colors"
          title="Copy to clipboard"
        >
          <Copy size={12} />
          Copy
        </button>
        <button
          onClick={() => {
            window.localshot.openEditor(imageDataUrl)
          }}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-md bg-white/10 hover:bg-white/20 text-white text-xs transition-colors"
          title="Open in editor"
        >
          <Pencil size={12} />
          Annotate
        </button>
        <button
          onClick={() => {
            window.localshot.saveImage(imageDataUrl)
          }}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-md bg-white/10 hover:bg-white/20 text-white text-xs transition-colors"
          title="Save to file"
        >
          <Download size={12} />
          Save
        </button>
        <div className="flex-1" />
        <button
          onClick={() => {
            window.localshot.closeOverlay()
          }}
          className="p-1.5 rounded-md hover:bg-white/10 text-white/50 hover:text-white transition-colors"
          title="Close"
        >
          <X size={12} />
        </button>
      </div>
    </div>
  )
}
