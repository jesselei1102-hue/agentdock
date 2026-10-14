import SwiftUI

struct StatusOrbView: View {
    let status: AgentStatus
    @State private var pulse = false
    private let diameter: CGFloat = 6

    var body: some View {
        ZStack {
            if status.shouldPulse {
                Circle()
                    .fill(status.color.opacity(0.4))
                    .frame(width: diameter + 4, height: diameter + 4)
                    .blur(radius: 2)
                    .opacity(pulse ? 0.85 : 0.3)
            }
            Circle()
                .fill(status.color)
                .frame(width: diameter, height: diameter)
                .opacity(status.shouldPulse ? (pulse ? 1.0 : 0.55) : 1.0)
        }
        .frame(width: 10, height: 10)
        .onAppear {
            guard status.shouldPulse else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityLabel(status.label)
    }
}
