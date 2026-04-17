import AppKit

// MARK: - Protocol

public protocol Annotation: AnyObject {
    var id: UUID { get }
    var color: NSColor { get set }
    var strokeWidth: CGFloat { get set }
    var isSelected: Bool { get set }
    var bounds: NSRect { get }
    func draw(in ctx: CGContext, viewBounds: NSRect)
    func hitTest(point: NSPoint) -> Bool
    func move(by delta: NSPoint)
}

// MARK: - Rectangle

public class RectAnnotation: Annotation {
    public let id = UUID()
    public var color: NSColor
    public var strokeWidth: CGFloat
    public var isSelected = false
    public var origin: NSPoint
    public var size: NSSize

    public var bounds: NSRect { NSRect(origin: origin, size: size) }

    public init(origin: NSPoint, size: NSSize, color: NSColor, strokeWidth: CGFloat) {
        self.origin = origin
        self.size = size
        self.color = color
        self.strokeWidth = strokeWidth
    }

    public func draw(in ctx: CGContext, viewBounds: NSRect) {
        let rect = bounds
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.stroke(rect)
        if isSelected { drawSelectionHandles(ctx: ctx, rect: rect) }
    }

    public func hitTest(point: NSPoint) -> Bool {
        let expanded = bounds.insetBy(dx: -strokeWidth - 4, dy: -strokeWidth - 4)
        let inner = bounds.insetBy(dx: strokeWidth + 4, dy: strokeWidth + 4)
        return expanded.contains(point) && (size.width < 20 || size.height < 20 || !inner.contains(point))
    }

    public func move(by delta: NSPoint) {
        origin.x += delta.x
        origin.y += delta.y
    }
}

// MARK: - Ellipse

public class EllipseAnnotation: Annotation {
    public let id = UUID()
    public var color: NSColor
    public var strokeWidth: CGFloat
    public var isSelected = false
    public var origin: NSPoint
    public var size: NSSize

    public var bounds: NSRect { NSRect(origin: origin, size: size) }

    public init(origin: NSPoint, size: NSSize, color: NSColor, strokeWidth: CGFloat) {
        self.origin = origin
        self.size = size
        self.color = color
        self.strokeWidth = strokeWidth
    }

    public func draw(in ctx: CGContext, viewBounds: NSRect) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.strokeEllipse(in: bounds)
        if isSelected { drawSelectionHandles(ctx: ctx, rect: bounds) }
    }

    public func hitTest(point: NSPoint) -> Bool {
        let r = bounds
        let cx = r.midX, cy = r.midY
        let rx = r.width / 2 + strokeWidth + 4
        let ry = r.height / 2 + strokeWidth + 4
        let dx = point.x - cx, dy = point.y - cy
        return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1
    }

    public func move(by delta: NSPoint) {
        origin.x += delta.x
        origin.y += delta.y
    }
}

// MARK: - Arrow

public class ArrowAnnotation: Annotation {
    public let id = UUID()
    public var color: NSColor
    public var strokeWidth: CGFloat
    public var isSelected = false
    public var start: NSPoint
    public var end: NSPoint

    public var bounds: NSRect {
        let x = min(start.x, end.x) - 8
        let y = min(start.y, end.y) - 8
        let w = abs(end.x - start.x) + 16
        let h = abs(end.y - start.y) + 16
        return NSRect(x: x, y: y, width: w, height: h)
    }

    public init(start: NSPoint, end: NSPoint, color: NSColor, strokeWidth: CGFloat) {
        self.start = start
        self.end = end
        self.color = color
        self.strokeWidth = strokeWidth
    }

    public func draw(in ctx: CGContext, viewBounds: NSRect) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)

        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLen = max(12, strokeWidth * 4)
        let p1 = CGPoint(x: end.x - headLen * cos(angle - .pi / 6), y: end.y - headLen * sin(angle - .pi / 6))
        let p2 = CGPoint(x: end.x - headLen * cos(angle + .pi / 6), y: end.y - headLen * sin(angle + .pi / 6))

        ctx.move(to: end)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()

        if isSelected { drawSelectionHandles(ctx: ctx, rect: bounds) }
    }

    public func hitTest(point: NSPoint) -> Bool {
        distanceToLine(point: point, from: start, to: end) < strokeWidth + 8
    }

    public func move(by delta: NSPoint) {
        start.x += delta.x; start.y += delta.y
        end.x += delta.x; end.y += delta.y
    }
}

// MARK: - Line

public class LineAnnotation: Annotation {
    public let id = UUID()
    public var color: NSColor
    public var strokeWidth: CGFloat
    public var isSelected = false
    public var start: NSPoint
    public var end: NSPoint

    public var bounds: NSRect {
        let x = min(start.x, end.x) - 4
        let y = min(start.y, end.y) - 4
        let w = abs(end.x - start.x) + 8
        let h = abs(end.y - start.y) + 8
        return NSRect(x: x, y: y, width: w, height: h)
    }

    public init(start: NSPoint, end: NSPoint, color: NSColor, strokeWidth: CGFloat) {
        self.start = start
        self.end = end
        self.color = color
        self.strokeWidth = strokeWidth
    }

    public func draw(in ctx: CGContext, viewBounds: NSRect) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
        if isSelected { drawSelectionHandles(ctx: ctx, rect: bounds) }
    }

    public func hitTest(point: NSPoint) -> Bool {
        distanceToLine(point: point, from: start, to: end) < strokeWidth + 8
    }

    public func move(by delta: NSPoint) {
        start.x += delta.x; start.y += delta.y
        end.x += delta.x; end.y += delta.y
    }
}

// MARK: - Text

public class TextAnnotation: Annotation {
    public let id = UUID()
    public var color: NSColor
    public var strokeWidth: CGFloat = 0
    public var isSelected = false
    public var origin: NSPoint
    public var text: String
    public var fontSize: CGFloat

    public var bounds: NSRect {
        let size = textSize
        return NSRect(origin: origin, size: size)
    }

    private var textSize: NSSize {
        let attrs = textAttributes
        return (text as NSString).size(withAttributes: attrs)
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color
        ]
    }

    public init(origin: NSPoint, text: String, color: NSColor, fontSize: CGFloat) {
        self.origin = origin
        self.text = text
        self.color = color
        self.fontSize = fontSize
    }

    public func draw(in ctx: CGContext, viewBounds: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let attrs = textAttributes
        (text as NSString).draw(at: origin, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
        if isSelected { drawSelectionHandles(ctx: ctx, rect: bounds) }
    }

    public func hitTest(point: NSPoint) -> Bool {
        bounds.insetBy(dx: -4, dy: -4).contains(point)
    }

    public func move(by delta: NSPoint) {
        origin.x += delta.x
        origin.y += delta.y
    }
}

// MARK: - Freehand

public class FreehandAnnotation: Annotation {
    public let id = UUID()
    public var color: NSColor
    public var strokeWidth: CGFloat
    public var isSelected = false
    public var points: [NSPoint] = []

    public var bounds: NSRect {
        guard !points.isEmpty else { return .zero }
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for p in points {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return NSRect(x: minX - 4, y: minY - 4, width: maxX - minX + 8, height: maxY - minY + 8)
    }

    public init(color: NSColor, strokeWidth: CGFloat) {
        self.color = color
        self.strokeWidth = strokeWidth
    }

    public func draw(in ctx: CGContext, viewBounds: NSRect) {
        guard points.count > 1 else { return }
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.move(to: points[0])
        for i in 1..<points.count {
            ctx.addLine(to: points[i])
        }
        ctx.strokePath()
        if isSelected { drawSelectionHandles(ctx: ctx, rect: bounds) }
    }

    public func hitTest(point: NSPoint) -> Bool {
        for i in 1..<points.count {
            if distanceToLine(point: point, from: points[i - 1], to: points[i]) < strokeWidth + 8 {
                return true
            }
        }
        return false
    }

    public func move(by delta: NSPoint) {
        for i in 0..<points.count {
            points[i].x += delta.x
            points[i].y += delta.y
        }
    }
}

// MARK: - Highlight

public class HighlightAnnotation: Annotation {
    public let id = UUID()
    public var color: NSColor
    public var strokeWidth: CGFloat = 0
    public var isSelected = false
    public var origin: NSPoint
    public var size: NSSize

    public var bounds: NSRect { NSRect(origin: origin, size: size) }

    public init(origin: NSPoint, size: NSSize, color: NSColor) {
        self.origin = origin
        self.size = size
        self.color = color
    }

    public func draw(in ctx: CGContext, viewBounds: NSRect) {
        ctx.setFillColor(color.withAlphaComponent(0.3).cgColor)
        ctx.fill(bounds)
        if isSelected { drawSelectionHandles(ctx: ctx, rect: bounds) }
    }

    public func hitTest(point: NSPoint) -> Bool {
        bounds.insetBy(dx: -4, dy: -4).contains(point)
    }

    public func move(by delta: NSPoint) {
        origin.x += delta.x
        origin.y += delta.y
    }
}

// MARK: - Blur

public class BlurAnnotation: Annotation {
    public let id = UUID()
    public var color: NSColor = .gray
    public var strokeWidth: CGFloat = 0
    public var isSelected = false
    public var origin: NSPoint
    public var size: NSSize
    public weak var sourceImageProvider: BlurImageProvider?

    public var bounds: NSRect { NSRect(origin: origin, size: size) }

    public init(origin: NSPoint, size: NSSize) {
        self.origin = origin
        self.size = size
    }

    public func draw(in ctx: CGContext, viewBounds: NSRect) {
        let blockSize: CGFloat = 10
        let rect = bounds
        guard rect.width > 1 && rect.height > 1 else { return }

        // Try to pixelate from actual image data
        if let provider = sourceImageProvider,
           let image = provider.imageForBlur,
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let imageRect = provider.imageDrawRectForBlur

            for y in stride(from: rect.minY, to: rect.maxY, by: blockSize) {
                for x in stride(from: rect.minX, to: rect.maxX, by: blockSize) {
                    let w = min(blockSize, rect.maxX - x)
                    let h = min(blockSize, rect.maxY - y)
                    let sampleX = x + w / 2
                    let sampleY = y + h / 2

                    // Map view coords to image pixel coords
                    let imgX = Int((sampleX - imageRect.minX) / imageRect.width * CGFloat(cgImage.width))
                    let imgY = Int((1.0 - (sampleY - imageRect.minY) / imageRect.height) * CGFloat(cgImage.height))

                    if imgX >= 0 && imgX < cgImage.width && imgY >= 0 && imgY < cgImage.height,
                       let pixelColor = samplePixel(cgImage: cgImage, x: imgX, y: imgY) {
                        ctx.setFillColor(pixelColor)
                    } else {
                        ctx.setFillColor(NSColor(white: 0.5, alpha: 0.85).cgColor)
                    }
                    ctx.fill(CGRect(x: x, y: y, width: w, height: h))
                }
            }
        } else {
            // Fallback: deterministic gray pattern seeded by position
            for y in stride(from: rect.minY, to: rect.maxY, by: blockSize) {
                for x in stride(from: rect.minX, to: rect.maxX, by: blockSize) {
                    let seed = (Int(x) * 73 + Int(y) * 137) & 0xFF
                    let gray = 0.4 + CGFloat(seed) / 255.0 * 0.35
                    ctx.setFillColor(NSColor(white: gray, alpha: 0.85).cgColor)
                    let w = min(blockSize, rect.maxX - x)
                    let h = min(blockSize, rect.maxY - y)
                    ctx.fill(CGRect(x: x, y: y, width: w, height: h))
                }
            }
        }

        if isSelected { drawSelectionHandles(ctx: ctx, rect: bounds) }
    }

    private func samplePixel(cgImage: CGImage, x: Int, y: Int) -> CGColor? {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let offset = y * bytesPerRow + x * bytesPerPixel

        guard offset + 2 < CFDataGetLength(data) else { return nil }

        let rawInfo = cgImage.bitmapInfo
        let byteOrder = CGImageByteOrderInfo(rawValue: rawInfo.rawValue & CGBitmapInfo.byteOrderMask.rawValue) ?? .orderDefault
        let alphaInfo = CGImageAlphaInfo(rawValue: rawInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue) ?? .none

        // macOS screen captures are typically BGRA: 32Little + alpha first-skip or premultiplied-first
        let isBGRA = byteOrder == .order32Little &&
            (alphaInfo == .noneSkipFirst || alphaInfo == .premultipliedFirst || alphaInfo == .first)

        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        if isBGRA {
            b = CGFloat(ptr[offset]) / 255.0
            g = CGFloat(ptr[offset + 1]) / 255.0
            r = CGFloat(ptr[offset + 2]) / 255.0
        } else {
            r = CGFloat(ptr[offset]) / 255.0
            g = CGFloat(ptr[offset + 1]) / 255.0
            b = CGFloat(ptr[offset + 2]) / 255.0
        }
        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    public func hitTest(point: NSPoint) -> Bool {
        bounds.insetBy(dx: -4, dy: -4).contains(point)
    }

    public func move(by delta: NSPoint) {
        origin.x += delta.x
        origin.y += delta.y
    }
}

/// Protocol for BlurAnnotation to access the source image without tight coupling
public protocol BlurImageProvider: AnyObject {
    var imageForBlur: NSImage? { get }
    var imageDrawRectForBlur: NSRect { get }
}

// MARK: - Counter

public class CounterAnnotation: Annotation {
    public let id = UUID()
    public var color: NSColor
    public var strokeWidth: CGFloat = 0
    public var isSelected = false
    public var center: NSPoint
    public var number: Int
    public let radius: CGFloat = 16

    public var bounds: NSRect {
        NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    public init(center: NSPoint, number: Int, color: NSColor) {
        self.center = center
        self.number = number
        self.color = color
    }

    public func draw(in ctx: CGContext, viewBounds: NSRect) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: bounds)

        NSGraphicsContext.saveGraphicsState()
        let str = "\(number)" as NSString
        let font = NSFont.systemFont(ofSize: 14, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let size = str.size(withAttributes: attrs)
        str.draw(
            at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2),
            withAttributes: attrs
        )
        NSGraphicsContext.restoreGraphicsState()

        if isSelected { drawSelectionHandles(ctx: ctx, rect: bounds) }
    }

    public func hitTest(point: NSPoint) -> Bool {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return sqrt(dx * dx + dy * dy) <= radius + 6
    }

    public func move(by delta: NSPoint) {
        center.x += delta.x
        center.y += delta.y
    }
}

// MARK: - Helpers

private func distanceToLine(point: NSPoint, from: NSPoint, to: NSPoint) -> CGFloat {
    let dx = to.x - from.x
    let dy = to.y - from.y
    let lenSq = dx * dx + dy * dy
    guard lenSq > 0 else { return hypot(point.x - from.x, point.y - from.y) }

    var t = ((point.x - from.x) * dx + (point.y - from.y) * dy) / lenSq
    t = max(0, min(1, t))

    let projX = from.x + t * dx
    let projY = from.y + t * dy
    return hypot(point.x - projX, point.y - projY)
}

func drawSelectionHandles(ctx: CGContext, rect: NSRect) {
    let handleSize: CGFloat = 6
    let handles = [
        CGPoint(x: rect.minX, y: rect.minY),
        CGPoint(x: rect.maxX, y: rect.minY),
        CGPoint(x: rect.minX, y: rect.maxY),
        CGPoint(x: rect.maxX, y: rect.maxY)
    ]

    ctx.setFillColor(NSColor.white.cgColor)
    ctx.setStrokeColor(NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1).cgColor)
    ctx.setLineWidth(1.5)

    for handle in handles {
        let r = CGRect(
            x: handle.x - handleSize / 2,
            y: handle.y - handleSize / 2,
            width: handleSize,
            height: handleSize
        )
        ctx.fillEllipse(in: r)
        ctx.strokeEllipse(in: r)
    }
}
