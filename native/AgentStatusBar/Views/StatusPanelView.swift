import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var store: StatusStore
    var onCollapse: (() -> Void)? = nil

    static let islandWidth: CGFloat = 340
    static let islandHeight: CGFloat = 98
    static let pillHeight: CGFloat = 20

    private var orderedAgents: [AgentSnapshot] {
        Array(store.agents.prefix(6))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("AgentDock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(0)
                Spacer(minLength: 4)
                Text(store.relativeRefresh)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(0)
                Button {
                    store.localOnly.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: store.localOnly ? "laptopcomputer" : "network")
                            .font(.system(size: 9, weight: .semibold))
                        Text(store.localOnly ? "This Mac" : "All Macs")
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .foregroundStyle(Color.white.opacity(store.localOnly ? 0.95 : 0.7))
                    .padding(.horizontal, 7)
                    .frame(height: Self.pillHeight)
                    .background(Capsule().fill(Color.white.opacity(store.localOnly ? 0.22 : 0.08)))
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .help("Toggle SSH hosts on/off")
                .layoutPriority(2)
                .padding(.leading, 6)
                Button {
                    onCollapse?()
                } label: {
                    Text("Collapse")
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .frame(height: Self.pillHeight)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .layoutPriority(2)
                .padding(.leading, 4)
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(width: Self.pillHeight, height: Self.pillHeight)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Quit AgentDock")
                .layoutPriority(2)
                .padding(.leading, 4)
            }
            .frame(height: Self.pillHeight)
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
