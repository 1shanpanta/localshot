import { contextBridge, ipcRenderer } from 'electron'

export interface LocalShotAPI {
  // Selection overlay
  onSetScreenshot: (callback: (dataUrl: string) => void) => void
  sendAreaSelected: (croppedDataUrl: string) => void
  sendSelectionCancelled: () => void

  // Overlay
  onSetOverlayImage: (callback: (dataUrl: string, bounds: { width: number; height: number }) => void) => void
  openEditor: (imageDataUrl?: string) => void
  closeOverlay: () => void
  copyFromOverlay: (imageDataUrl: string) => void

  // Editor
  onLoadImage: (callback: (dataUrl: string) => void) => void
  getPendingScreenshot: () => Promise<string | null>
  copyImage: (imageDataUrl: string) => void
  saveImage: (imageDataUrl: string) => Promise<boolean>
}

const api: LocalShotAPI = {
  // Selection overlay
  onSetScreenshot: (callback) => {
    ipcRenderer.on('selection:set-screenshot', (_event, dataUrl) => callback(dataUrl))
  },
  sendAreaSelected: (croppedDataUrl) => {
    ipcRenderer.send('selection:area-selected', croppedDataUrl)
  },
  sendSelectionCancelled: () => {
    ipcRenderer.send('selection:cancelled')
  },

  // Overlay
  onSetOverlayImage: (callback) => {
    ipcRenderer.on('overlay:set-image', (_event, dataUrl, bounds) => callback(dataUrl, bounds))
  },
  openEditor: (imageDataUrl) => {
    ipcRenderer.send('overlay:open-editor', imageDataUrl)
  },
  closeOverlay: () => {
    ipcRenderer.send('overlay:close')
  },
  copyFromOverlay: (imageDataUrl) => {
    ipcRenderer.send('overlay:copy', imageDataUrl)
  },

  // Editor
  onLoadImage: (callback) => {
    ipcRenderer.on('editor:load-image', (_event, dataUrl) => callback(dataUrl))
  },
  getPendingScreenshot: () => {
    return ipcRenderer.invoke('editor:get-pending')
  },
  copyImage: (imageDataUrl) => {
    ipcRenderer.send('editor:copy', imageDataUrl)
  },
  saveImage: (imageDataUrl) => {
    return ipcRenderer.invoke('editor:save', imageDataUrl)
  }
}

contextBridge.exposeInMainWorld('localshot', api)
