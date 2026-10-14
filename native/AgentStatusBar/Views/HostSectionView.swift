import SwiftUI

/// Legacy vertical section — unused by the horizontal island.
/// Kept so the Xcode project still compiles; prefer AgentRowView cells in StatusPanelView.
struct HostSectionView: View {
    let kind: String
    let agents: [AgentSnapshot]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(agents) { AgentRowView(agent: $0) }
            if agents.isEmpty {
                Text(kind != "local" ? "Unreachable" : "No agents")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
