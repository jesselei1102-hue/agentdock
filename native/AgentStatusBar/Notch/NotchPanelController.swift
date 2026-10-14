import AppKit
import SwiftUI

/// Fixed-size borderless panel at screen top-center (under the camera notch).
/// Expand/collapse is SwiftUI-only — never resize the NSPanel (that crashed on layout).
@MainActor
final class NotchPanelController {
    private var panel: IslandPanel?
    private let store: StatusStore
    /// Room for expanded island + notch offset. Transparent outside the pill/bar.
    private let panelSize = NSSize(width: 400, height: 190)

    init(store: StatusStore) {
        self.store = store
    }

    func show() {
        if panel == nil {
            panel = makePanel()
        }
        reposition()
        panel?.orderFrontRegardless()
        store.startPolling()
    }

    func hide() {
        panel?.orderOut(nil)
        store.stopPolling()
    }

    private func makePanel() -> IslandPanel {
        let root = NotchIslandHost(store: store)
        let hosting = FirstMouseHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: panelSize)
        hosting.appearance = NSAppearance(named: .darkAqua)

        let p = IslandPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.contentView = hosting
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = false
        return p
    }

    private func reposition() {
        guard let panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let full = screen.frame
        let x = full.midX - panelSize.width / 2
        // Hang from physical top so the island sits in the notch band.
        let y = full.maxY - panelSize.height
        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
    }
}

private struct NotchIslandHost: View {
    @ObservedObject var store: StatusStore
    @State private var expanded = false

    var body: some View {
        NotchIslandView(store: store, expanded: $expanded)
            .preferredColorScheme(.dark)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.clear)
    }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
