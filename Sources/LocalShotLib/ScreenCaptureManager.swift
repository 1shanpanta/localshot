import AppKit
import CoreGraphics

public class ScreenCaptureManager {

    public init() {}

    /// Capture the entire primary display
    public func captureFullScreen() -> NSImage? {
        guard let mainDisplay = CGMainDisplayID() as CGDirectDisplayID? else { return nil }

        guard let cgImage = CGDisplayCreateImage(mainDisplay) else {
            print("CGDisplayCreateImage failed -- check Screen Recording permission")
            return nil
        }

        let size = NSSize(
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )
        return NSImage(cgImage: cgImage, size: size)
    }

    /// Capture a specific rect of the screen (in screen coordinates)
    public func captureRect(_ rect: CGRect) -> NSImage? {
        guard let mainDisplay = CGMainDisplayID() as CGDirectDisplayID? else { return nil }

        guard let cgImage = CGDisplayCreateImage(mainDisplay, rect: rect) else {
            return nil
        }

        let size = NSSize(
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )
        return NSImage(cgImage: cgImage, size: size)
    }
}
