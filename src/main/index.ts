import { app, BrowserWindow, globalShortcut, ipcMain, screen } from 'electron'
import { join } from 'path'
import { setupTray } from './tray'
import { setupIPC } from './ipc'
import { captureFullScreen, captureScreen } from './capture'

let editorWindow: BrowserWindow | null = null
let selectionWindow: BrowserWindow | null = null
let overlayWindow: BrowserWindow | null = null

function createEditorWindow(): BrowserWindow {
  const { width, height } = screen.getPrimaryDisplay().workAreaSize

  const win = new BrowserWindow({
    width: Math.min(1400, width - 100),
    height: Math.min(900, height - 100),
    show: false,
    center: true,
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 16, y: 16 },
    backgroundColor: '#1a1a2e',
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  })

  if (process.env.ELECTRON_RENDERER_URL) {
    win.loadURL(`${process.env.ELECTRON_RENDERER_URL}/index.html`)
  } else {
    win.loadFile(join(__dirname, '../renderer/editor.html'))
  }

  win.on('closed', () => {
    editorWindow = null
  })

  return win
}

function createSelectionWindow(): BrowserWindow {
  const primaryDisplay = screen.getPrimaryDisplay()
  const { width, height } = primaryDisplay.size

  const win = new BrowserWindow({
    x: 0,
    y: 0,
    width,
    height,
    transparent: true,
    frame: false,
    fullscreen: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    hasShadow: false,
    enableLargerThanScreen: true,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  })

  win.setVisibleOnAllWorkspaces(true)
  win.setAlwaysOnTop(true, 'screen-saver')

  if (process.env.ELECTRON_RENDERER_URL) {
    win.loadURL(`${process.env.ELECTRON_RENDERER_URL}/selection.html`)
  } else {
    win.loadFile(join(__dirname, '../renderer/selection.html'))
  }

  win.on('closed', () => {
    selectionWindow = null
  })

  return win
}

function createOverlayWindow(
  imageDataUrl: string,
  bounds: { width: number; height: number }
): BrowserWindow {
  const primaryDisplay = screen.getPrimaryDisplay()
  const { width: screenW, height: screenH } = primaryDisplay.workAreaSize

  const thumbW = 280
  const thumbH = Math.round((bounds.height / bounds.width) * thumbW)

  const win = new BrowserWindow({
    x: screenW - thumbW - 20,
    y: screenH - thumbH - 80,
    width: thumbW,
    height: thumbH + 50,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    hasShadow: true,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  })

  win.setVisibleOnAllWorkspaces(true)

  if (process.env.ELECTRON_RENDERER_URL) {
    win.loadURL(`${process.env.ELECTRON_RENDERER_URL}/overlay.html`)
  } else {
    win.loadFile(join(__dirname, '../renderer/overlay.html'))
  }

  win.webContents.on('did-finish-load', () => {
    win.webContents.send('overlay:set-image', imageDataUrl, bounds)
  })

  win.on('closed', () => {
    overlayWindow = null
  })

  // Auto-close after 8 seconds
  setTimeout(() => {
    if (win && !win.isDestroyed()) {
      win.close()
    }
  }, 8000)

  return win
}

async function startAreaCapture(): Promise<void> {
  // First capture the screen, then show selection overlay
  const screenshotDataUrl = await captureFullScreen()
  if (!screenshotDataUrl) return

  selectionWindow = createSelectionWindow()
  selectionWindow.webContents.on('did-finish-load', () => {
    selectionWindow?.webContents.send('selection:set-screenshot', screenshotDataUrl)
  })
}

async function startFullScreenCapture(): Promise<void> {
  const screenshotDataUrl = await captureFullScreen()
  if (!screenshotDataUrl) return

  showOverlayAndEditor(screenshotDataUrl)
}

function showOverlayAndEditor(imageDataUrl: string): void {
  // Get image dimensions from data URL
  const base64 = imageDataUrl.split(',')[1]
  const buffer = Buffer.from(base64, 'base64')

  // Show overlay
  if (overlayWindow && !overlayWindow.isDestroyed()) {
    overlayWindow.close()
  }
  overlayWindow = createOverlayWindow(imageDataUrl, { width: 800, height: 600 })

  // Store for editor
  global.pendingScreenshot = imageDataUrl
}

function openEditorWithScreenshot(imageDataUrl: string): void {
  if (!editorWindow || editorWindow.isDestroyed()) {
    editorWindow = createEditorWindow()
  }

  editorWindow.webContents.on('did-finish-load', () => {
    editorWindow?.webContents.send('editor:load-image', imageDataUrl)
  })

  if (editorWindow.webContents.isLoading()) {
    // Wait for load
  } else {
    editorWindow.webContents.send('editor:load-image', imageDataUrl)
  }

  editorWindow.show()
  editorWindow.focus()
}

// Extend global to store pending screenshot
declare global {
  // eslint-disable-next-line no-var
  var pendingScreenshot: string | null
}
global.pendingScreenshot = null

app.whenReady().then(() => {
  // Register global shortcuts
  globalShortcut.register('CommandOrControl+Shift+1', () => {
    startFullScreenCapture()
  })

  globalShortcut.register('CommandOrControl+Shift+2', () => {
    startAreaCapture()
  })

  // Setup IPC
  setupIPC({
    onAreaSelected: (imageDataUrl: string) => {
      if (selectionWindow && !selectionWindow.isDestroyed()) {
        selectionWindow.close()
      }
      showOverlayAndEditor(imageDataUrl)
    },
    onSelectionCancelled: () => {
      if (selectionWindow && !selectionWindow.isDestroyed()) {
        selectionWindow.close()
      }
    },
    onOpenEditor: (imageDataUrl?: string) => {
      const img = imageDataUrl || global.pendingScreenshot
      if (img) {
        openEditorWithScreenshot(img)
        global.pendingScreenshot = null
      }
    },
    onCloseOverlay: () => {
      if (overlayWindow && !overlayWindow.isDestroyed()) {
        overlayWindow.close()
      }
    }
  })

  // Setup system tray
  setupTray({
    onCaptureArea: () => startAreaCapture(),
    onCaptureFullScreen: () => startFullScreenCapture(),
    onOpenEditor: () => {
      if (!editorWindow || editorWindow.isDestroyed()) {
        editorWindow = createEditorWindow()
      }
      editorWindow.show()
      editorWindow.focus()
    },
    onQuit: () => app.quit()
  })

  // Don't show dock icon (menu bar only app)
  app.dock?.hide()
})

app.on('will-quit', () => {
  globalShortcut.unregisterAll()
})

app.on('window-all-closed', () => {
  // Keep app running in tray
})
