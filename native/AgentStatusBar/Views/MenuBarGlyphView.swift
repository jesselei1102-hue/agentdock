import SwiftUI

/// Horizontal row of status orbs — collapsed Dynamic Island pill content (not a 2×2 grid).
struct MenuBarGlyphView: View {
    let agents: [AgentSnapshot]
    var dotSize: CGFloat = 5
    var spacing: CGFloat = 6

    private var dots: [AgentStatus] {
        let ordered = agents
        var statuses = ordered.map(\.status)
        if statuses.isEmpty {
            return [.unknown, .unknown, .unknown, .unknown]
        }
                return Array(statuses.prefix(6))
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(dots.enumerated()), id: \.offset) { _, status in
                MicroDot(status: status, size: dotSize)
            }
        }
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let counts = Dictionary(grouping: agents, by: \.status)
        let parts = AgentStatus.allCases.compactMap { s -> String? in
            guard let n = counts[s]?.count, n > 0 else { return nil }
            return "\(n) \(s.rawValue)"
        }
        return parts.isEmpty ? "No agents" : parts.joined(separator: ", ")
    }
}

private struct MicroDot: View {
    let status: AgentStatus
    var size: CGFloat = 5
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .opacity(status.shouldPulse ? (pulse ? 1.0 : 0.55) : (status == .offline ? 0.7 : 1.0))
            .onAppear {
                guard status.shouldPulse else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

#Preview {
    MenuBarGlyphView(agents: AgentSnapshot.demo)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black))
}
