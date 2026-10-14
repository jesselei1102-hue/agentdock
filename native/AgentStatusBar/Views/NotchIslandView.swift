import SwiftUI

struct NotchIslandView: View {
    @ObservedObject var store: StatusStore
    @Binding var expanded: Bool

    private let collapsedSize = CGSize(width: 156, height: 46)
    private let expandedSize = CGSize(width: 360, height: 140)

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .frame(height: expanded ? expandedSize.height + 8 : collapsedSize.height + 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tap empty chrome collapses when expanded
                    if expanded { collapse() }
                }

            Group {
                if expanded {
                    VStack(spacing: 0) {
                        // Keep a slim notch strip with dots so it still feels attached
                        HStack {
                            Spacer(minLength: 0)
                            MenuBarGlyphView(agents: store.agents, dotSize: 5, spacing: 6)
                                .padding(.horizontal, 16)
                                .frame(height: 28)
                            Spacer(minLength: 0)
                        }
                        .frame(height: 28)
                        .contentShape(Rectangle())
                        .onTapGesture { collapse() }

                        StatusPanelView(store: store, onCollapse: collapse)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                    .frame(width: expandedSize.width)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.black.opacity(0.94))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                } else {
                    MenuBarGlyphView(agents: store.agents, dotSize: 6, spacing: 6)
                        .padding(.bottom, 7)
                        .frame(width: collapsedSize.width, height: collapsedSize.height, alignment: .bottom)
                        .padding(.bottom, 0)
                        .background(
                            UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous)
                                .fill(Color.black)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { expand() }
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: expanded)
        }
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func expand() {
        store.refresh()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            expanded = true
        }
    }

    private func collapse() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            expanded = false
        }
    }
}

struct NotchChipView: View {
    let agents: [AgentSnapshot]
    var body: some View {
        MenuBarGlyphView(agents: agents, dotSize: 5, spacing: 7)
            .frame(width: 120, height: 28)
    }
}
