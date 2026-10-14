import SwiftUI

/// Canonical agent lifecycle status. Matches `lib/detect.py` STATUSES.
enum AgentStatus: String, Codable, CaseIterable, Identifiable {
    case running
    case idle
    case stale
    case offline
    case unknown

    var id: String { rawValue }

    /// Semantic status color — quiet luxury palette.
    var color: Color {
        switch self {
        case .running: return Color(hex: 0x30D158)
        case .idle:    return Color(hex: 0xFFD60A)
        case .stale:   return Color(hex: 0xFF9F0A)
        case .offline: return Color(hex: 0x636366)
        case .unknown: return Color(hex: 0x8E8E93)
        }
    }

    var label: String { rawValue }

    /// Running dots breathe; others stay still.
    var shouldPulse: Bool { self == .running }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
