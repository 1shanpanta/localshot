import AppKit

public enum AnnotationToolType: String, CaseIterable {
    case select
    case rectangle
    case ellipse
    case arrow
    case line
    case text
    case freehand
    case highlight
    case blur
    case counter

    public var label: String {
        switch self {
        case .select: return "Select"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .arrow: return "Arrow"
        case .line: return "Line"
        case .text: return "Text"
        case .freehand: return "Pencil"
        case .highlight: return "Highlight"
        case .blur: return "Blur"
        case .counter: return "Counter"
        }
    }

    public var shortcut: String {
        switch self {
        case .select: return "V"
        case .rectangle: return "R"
        case .ellipse: return "E"
        case .arrow: return "A"
        case .line: return "L"
        case .text: return "T"
        case .freehand: return "P"
        case .highlight: return "H"
        case .blur: return "B"
        case .counter: return "N"
        }
    }

    public var keyCode: UInt16 {
        switch self {
        case .select: return 9     // V
        case .rectangle: return 15 // R
        case .ellipse: return 14   // E
        case .arrow: return 0      // A
        case .line: return 37      // L
        case .text: return 17      // T
        case .freehand: return 35  // P
        case .highlight: return 4  // H
        case .blur: return 11      // B
        case .counter: return 45   // N
        }
    }

    /// Icon drawing for the toolbar
    public func drawIcon(in rect: NSRect, color: NSColor) {
        let ctx = NSGraphicsContext.current!.cgContext
        let inset = rect.insetBy(dx: 3, dy: 3)
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        switch self {
        case .select:
            // Arrow cursor
            let path = CGMutablePath()
            path.move(to: CGPoint(x: inset.minX + 2, y: inset.maxY - 1))
            path.addLine(to: CGPoint(x: inset.minX + 2, y: inset.minY + 2))
            path.addLine(to: CGPoint(x: inset.maxX - 3, y: inset.midY))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()

        case .rectangle:
            ctx.stroke(inset.insetBy(dx: 1, dy: 1))

        case .ellipse:
            ctx.strokeEllipse(in: inset.insetBy(dx: 1, dy: 1))

        case .arrow:
            let start = CGPoint(x: inset.minX + 2, y: inset.minY + 2)
            let end = CGPoint(x: inset.maxX - 2, y: inset.maxY - 2)
            ctx.move(to: start)
            ctx.addLine(to: end)
            ctx.strokePath()
            // Arrowhead
            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLen: CGFloat = 6
            let p1 = CGPoint(x: end.x - headLen * cos(angle - .pi / 6), y: end.y - headLen * sin(angle - .pi / 6))
            let p2 = CGPoint(x: end.x - headLen * cos(angle + .pi / 6), y: end.y - headLen * sin(angle + .pi / 6))
            ctx.move(to: end)
            ctx.addLine(to: p1)
            ctx.move(to: end)
            ctx.addLine(to: p2)
            ctx.strokePath()

        case .line:
            ctx.move(to: CGPoint(x: inset.minX + 2, y: inset.midY))
            ctx.addLine(to: CGPoint(x: inset.maxX - 2, y: inset.midY))
            ctx.strokePath()

        case .text:
            let font = NSFont.systemFont(ofSize: 14, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let str = "T" as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attrs)

        case .freehand:
            ctx.move(to: CGPoint(x: inset.minX + 1, y: inset.midY + 2))
            ctx.addCurve(
                to: CGPoint(x: inset.maxX - 1, y: inset.midY - 2),
                control1: CGPoint(x: inset.midX - 3, y: inset.maxY - 2),
                control2: CGPoint(x: inset.midX + 3, y: inset.minY + 2)
            )
            ctx.strokePath()

        case .highlight:
            ctx.setFillColor(color.withAlphaComponent(0.3).cgColor)
            ctx.fill(NSRect(x: inset.minX + 1, y: inset.midY - 3, width: inset.width - 2, height: 6))
            ctx.setStrokeColor(color.cgColor)
            ctx.stroke(NSRect(x: inset.minX + 1, y: inset.midY - 3, width: inset.width - 2, height: 6))

        case .blur:
            // Grid pattern
            let step: CGFloat = 4
            for row in 0..<3 {
                for col in 0..<3 {
                    let x = inset.minX + 2 + CGFloat(col) * step
                    let y = inset.minY + 2 + CGFloat(row) * step
                    let gray = CGFloat.random(in: 0.3...0.7)
                    ctx.setFillColor(NSColor(white: gray, alpha: 1).cgColor)
                    ctx.fill(CGRect(x: x, y: y, width: step - 0.5, height: step - 0.5))
                }
            }

        case .counter:
            let r: CGFloat = 7
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: rect.midX - r, y: rect.midY - r, width: r * 2, height: r * 2))
            let font = NSFont.systemFont(ofSize: 10, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
            let str = "1" as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attrs)
        }
    }
}

public let defaultColors: [NSColor] = [
    NSColor(red: 1.0, green: 0.23, blue: 0.23, alpha: 1),   // Red
    NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1),    // Orange
    NSColor(red: 0.98, green: 0.75, blue: 0.15, alpha: 1),   // Yellow
    NSColor(red: 0.2, green: 0.83, blue: 0.6, alpha: 1),     // Green
    NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1),    // Blue
    NSColor(red: 0.65, green: 0.55, blue: 0.98, alpha: 1),   // Purple
    NSColor.white,
    NSColor.black
]
