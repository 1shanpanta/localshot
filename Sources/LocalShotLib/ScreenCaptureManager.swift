import AppKit
import CoreGraphics

public class ScreenCaptureManager {

    public init() {}

    /// Capture a single NSScreen. Converts the NSScreen frame (bottom-left
    /// origin, relative to the primary display) into CG global coordinates
    /// (top-left origin, also relative to the primary display).
    public func captureScreen(_ screen: NSScreen) -> NSImage? {
        let rect = Self.cgRect(for: screen)
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else { return nil }
        let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        return NSImage(cgImage: cgImage, size: size)
    }

    public func captureRect(_ rect: CGRect) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else { return nil }
        let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        return NSImage(cgImage: cgImage, size: size)
    }

    /// The primary display is the one whose NSScreen origin is (0,0).
    /// CG global coords have origin at the top-left of that display.
    private static func cgRect(for screen: NSScreen) -> CGRect {
        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero })
            ?? NSScreen.screens.first
            ?? screen
        let primaryHeight = primary.frame.height
        return CGRect(
            x: screen.frame.origin.x,
            y: primaryHeight - screen.frame.origin.y - screen.frame.height,
            width: screen.frame.width,
            height: screen.frame.height
        )
    }
}
