import SwiftUI

extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

enum Theme {
    static let paper = Color(hex: "F7F1E6")
    static let desk = Color(hex: "E6D9C8")
    static let ink = Color(hex: "1A1714")
    static let secondary = Color(hex: "6E675F")
    static let accent = Color(hex: "C6452C")
    static let dock = Color(hex: "FFFBF6")
}

enum BrushColor: String, CaseIterable, Identifiable {
    case ink = "1A1714"
    case vermilion = "C6452C"
    case ochre = "C9842A"
    case moss = "3E6B4F"
    case sea = "2C5D8A"
    case plum = "6E4A86"
    case blush = "D9898C"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ink: return "Ink"
        case .vermilion: return "Vermilion"
        case .ochre: return "Ochre"
        case .moss: return "Moss"
        case .sea: return "Sea"
        case .plum: return "Plum"
        case .blush: return "Blush"
        }
    }
}

enum BrushSize: Double, CaseIterable, Identifiable {
    case fine = 0.008
    case medium = 0.018
    case broad = 0.042

    var id: Double { rawValue }

    var textSize: Double {
        switch self {
        case .fine: return 0.055
        case .medium: return 0.08
        case .broad: return 0.12
        }
    }

    var name: String {
        switch self {
        case .fine: return "Fine"
        case .medium: return "Medium"
        case .broad: return "Broad"
        }
    }
}

enum EditorTool: String, CaseIterable, Identifiable {
    case pen
    case eraser
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen: return "Draw"
        case .eraser: return "Eraser"
        case .text: return "Text"
        }
    }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .eraser: return "eraser"
        case .text: return "textformat"
        }
    }
}
