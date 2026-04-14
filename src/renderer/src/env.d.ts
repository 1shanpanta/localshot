/// <reference types="vite/client" />

interface LocalShotAPI {
  onSetScreenshot: (callback: (dataUrl: string) => void) => void
  sendAreaSelected: (croppedDataUrl: string) => void
  sendSelectionCancelled: () => void
  onSetOverlayImage: (callback: (dataUrl: string, bounds: { width: number; height: number }) => void) => void
  openEditor: (imageDataUrl?: string) => void
  closeOverlay: () => void
  copyFromOverlay: (imageDataUrl: string) => void
  onLoadImage: (callback: (dataUrl: string) => void) => void
  getPendingScreenshot: () => Promise<string | null>
  copyImage: (imageDataUrl: string) => void
  saveImage: (imageDataUrl: string) => Promise<boolean>
}

declare global {
  interface Window {
    localshot: LocalShotAPI
  }
}

export {}
