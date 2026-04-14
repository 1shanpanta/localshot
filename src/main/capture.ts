import { execSync } from 'child_process'
import { readFileSync, unlinkSync, existsSync } from 'fs'
import { join } from 'path'
import { app } from 'electron'

const TEMP_DIR = app?.getPath('temp') || '/tmp'

export async function captureFullScreen(): Promise<string | null> {
  const tempPath = join(TEMP_DIR, `localshot-capture-${Date.now()}.png`)

  try {
    // Use macOS native screencapture - silent (-x), full screen
    execSync(`screencapture -x -t png "${tempPath}"`, {
      timeout: 5000,
      stdio: 'pipe'
    })

    if (!existsSync(tempPath)) return null

    const buffer = readFileSync(tempPath)
    const base64 = buffer.toString('base64')
    const dataUrl = `data:image/png;base64,${base64}`

    // Clean up temp file
    try { unlinkSync(tempPath) } catch {}

    return dataUrl
  } catch (err) {
    console.error('Screen capture failed:', err)
    try { unlinkSync(tempPath) } catch {}
    return null
  }
}

export async function captureScreen(): Promise<string | null> {
  return captureFullScreen()
}

export function cropImage(
  fullImageDataUrl: string,
  rect: { x: number; y: number; width: number; height: number }
): string {
  // Cropping is done on the renderer side using canvas
  // This is a placeholder - actual cropping happens in selection overlay
  return fullImageDataUrl
}
