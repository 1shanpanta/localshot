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
