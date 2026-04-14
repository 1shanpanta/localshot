import { ipcMain, clipboard, nativeImage, dialog, BrowserWindow } from 'electron'
import { writeFileSync } from 'fs'
import { join } from 'path'

interface IPCActions {
  onAreaSelected: (imageDataUrl: string) => void
  onSelectionCancelled: () => void
  onOpenEditor: (imageDataUrl?: string) => void
  onCloseOverlay: () => void
}

export function setupIPC(actions: IPCActions): void {
  // Selection overlay -> main: area was selected
  ipcMain.on('selection:area-selected', (_event, croppedDataUrl: string) => {
    actions.onAreaSelected(croppedDataUrl)
  })

  // Selection overlay -> main: cancelled
  ipcMain.on('selection:cancelled', () => {
    actions.onSelectionCancelled()
  })

  // Overlay -> main: open editor with the screenshot
  ipcMain.on('overlay:open-editor', (_event, imageDataUrl?: string) => {
    actions.onOpenEditor(imageDataUrl)
    actions.onCloseOverlay()
  })

  // Overlay -> main: close overlay
  ipcMain.on('overlay:close', () => {
    actions.onCloseOverlay()
  })

  // Overlay -> main: copy image to clipboard
  ipcMain.on('overlay:copy', (_event, imageDataUrl: string) => {
    copyImageToClipboard(imageDataUrl)
    actions.onCloseOverlay()
  })

  // Editor -> main: copy annotated image to clipboard
  ipcMain.on('editor:copy', (_event, imageDataUrl: string) => {
    copyImageToClipboard(imageDataUrl)
  })

  // Editor -> main: save annotated image to file
  ipcMain.handle('editor:save', async (_event, imageDataUrl: string) => {
    const win = BrowserWindow.getFocusedWindow()
    if (!win) return false

    const result = await dialog.showSaveDialog(win, {
      title: 'Save Screenshot',
      defaultPath: join(
        require('os').homedir(),
        'Desktop',
        `localshot-${Date.now()}.png`
      ),
      filters: [
        { name: 'PNG', extensions: ['png'] },
        { name: 'JPEG', extensions: ['jpg', 'jpeg'] }
      ]
    })

    if (result.canceled || !result.filePath) return false

    const base64 = imageDataUrl.replace(/^data:image\/\w+;base64,/, '')
    const buffer = Buffer.from(base64, 'base64')
    writeFileSync(result.filePath, buffer)
    return true
  })

  // Editor -> main: request pending screenshot
  ipcMain.handle('editor:get-pending', () => {
    const img = global.pendingScreenshot
    global.pendingScreenshot = null
    return img
  })
}

function copyImageToClipboard(dataUrl: string): void {
  const base64 = dataUrl.replace(/^data:image\/\w+;base64,/, '')
  const buffer = Buffer.from(base64, 'base64')
  const image = nativeImage.createFromBuffer(buffer)
  clipboard.writeImage(image)
}
