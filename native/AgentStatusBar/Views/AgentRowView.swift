import SwiftUI

/// Compact cell for the horizontal island bar (not a tall list row).
struct AgentRowView: View {
    let agent: AgentSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                StatusOrbView(status: agent.status)
                Text(agent.shortName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            Text(agent.hostChip)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.leading, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(agent.shortName), \(agent.status.label), \(agent.hostChip)")
    }
}

#Preview {
    HStack(spacing: 0) {
        ForEach(AgentSnapshot.demo) { AgentRowView(agent: $0) }
    }
    .padding(8)
    .frame(width: 340, height: 68)
    .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.92)))
}
