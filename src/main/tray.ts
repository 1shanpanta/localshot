import { Tray, Menu, nativeImage } from 'electron'
import { join } from 'path'

let tray: Tray | null = null

interface TrayActions {
  onCaptureArea: () => void
  onCaptureFullScreen: () => void
  onOpenEditor: () => void
  onQuit: () => void
}

export function setupTray(actions: TrayActions): void {
  // Create a simple 16x16 tray icon using nativeImage
  const icon = createTrayIcon()
  tray = new Tray(icon)
  tray.setToolTip('LocalShot')

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Capture Area',
      accelerator: 'CommandOrControl+Shift+2',
      click: actions.onCaptureArea
    },
    {
      label: 'Capture Full Screen',
      accelerator: 'CommandOrControl+Shift+1',
      click: actions.onCaptureFullScreen
    },
    { type: 'separator' },
    {
      label: 'Open Editor',
      click: actions.onOpenEditor
    },
    { type: 'separator' },
    {
      label: 'Shortcuts',
      enabled: false
    },
    {
      label: '  Full Screen: Cmd+Shift+1',
      enabled: false
    },
    {
      label: '  Area Select: Cmd+Shift+2',
      enabled: false
    },
    { type: 'separator' },
    {
      label: 'Quit LocalShot',
      click: actions.onQuit
    }
  ])

  tray.setContextMenu(contextMenu)
}

function createTrayIcon(): nativeImage {
  // Create a simple crosshair icon for the menu bar (16x16, template image)
  // Template images on macOS auto-adapt to dark/light menu bar
  const size = 22
  const canvas = Buffer.alloc(size * size * 4)

  // Draw a simple camera/crosshair icon
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const idx = (y * size + x) * 4
      const cx = size / 2
      const cy = size / 2
      const dist = Math.sqrt((x - cx) ** 2 + (y - cy) ** 2)

      // Rounded square outline
      const inSquare = x >= 3 && x <= size - 4 && y >= 5 && y <= size - 4
      const onBorder =
        (x >= 3 && x <= size - 4 && (y === 5 || y === size - 4)) ||
        (y >= 5 && y <= size - 4 && (x === 3 || x === size - 4))

      // Lens circle
      const onCircle = dist >= 4.5 && dist <= 5.5

      // Crosshair lines
      const onCrosshair =
        ((x === Math.floor(cx) || x === Math.ceil(cx)) && y >= 2 && y <= size - 3 && !inSquare) ||
        ((y === Math.floor(cy) || y === Math.ceil(cy)) && x >= 0 && x <= size - 1 && !inSquare)

      if (onBorder || onCircle) {
        canvas[idx] = 0       // R
        canvas[idx + 1] = 0   // G
        canvas[idx + 2] = 0   // B
        canvas[idx + 3] = 255 // A
      } else {
        canvas[idx + 3] = 0   // Transparent
      }
    }
  }

  const icon = nativeImage.createFromBuffer(canvas, { width: size, height: size })
  icon.setTemplateImage(true)
  return icon
}
