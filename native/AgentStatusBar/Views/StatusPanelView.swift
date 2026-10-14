import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var store: StatusStore
    var onCollapse: (() -> Void)? = nil

    static let islandWidth: CGFloat = 340
    static let islandHeight: CGFloat = 98

    private var orderedAgents: [AgentSnapshot] {
        Array(store.agents.prefix(6))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("AgentDock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
                Spacer(minLength: 4)
                Text(store.relativeRefresh)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.4))
                Button {
                    onCollapse?()
                } label: {
                    Text("收回")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), alignment: .leading, spacing: 2) {
                ForEach(orderedAgents) { agent in
                    AgentRowView(agent: agent)
                }
                if orderedAgents.isEmpty {
                    Text("No agents")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 10)
        }
        .frame(width: Self.islandWidth)
        .preferredColorScheme(.dark)
    }
}
