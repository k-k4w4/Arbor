import SwiftUI

extension Color {
    // Semantic colors for refs
    static let arborBranch = Color.accentColor
    static let arborTag = Color.orange
    static let arborAdded = Color.green
    static let arborDeleted = Color.red
    static let arborModified = Color.blue
    static let arborRenamed = Color.orange

    // Diff background colors
    static let diffAdded = Color.green.opacity(0.15)
    static let diffDeleted = Color.red.opacity(0.12)
    static let diffHunk = Color.accentColor.opacity(0.07)

    // Branch graph color palette (10 colors, cycling by lane index)
    static let graphPalette: [Color] = [
        Color(hex: 0x4B9EFF),
        Color(hex: 0xFF6B6B),
        Color(hex: 0x51CF66),
        Color(hex: 0xFFD43B),
        Color(hex: 0xCC5DE8),
        Color(hex: 0xFF922B),
        Color(hex: 0x20C997),
        Color(hex: 0xF06595),
        Color(hex: 0x74C0FC),
        Color(hex: 0xA9E34B)
    ]

    static func graphColor(forLane lane: Int) -> Color {
        graphPalette[lane % graphPalette.count]
    }

    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
