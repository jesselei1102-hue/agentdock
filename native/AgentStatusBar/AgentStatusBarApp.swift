import SwiftUI
import AppKit

@main
struct AgentStatusBarApp: App {
    @StateObject private var store: StatusStore
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let env = ProcessInfo.processInfo.environment
        let demoEnv = (env["AGENTDOCK_DEMO"] ?? env["AGENT_STATUS_DEMO"])?.lowercased()
        let useDemo = demoEnv != nil && ["1", "true", "yes"].contains(demoEnv!)
        let store = StatusStore(demo: useDemo)
        AppDelegate.pendingStore = store
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        // Primary: center-notch NSPanel (Dynamic Island — horizontal expand).
        // MenuBarExtra cannot occupy the physical notch — fallback launcher only.
        MenuBarExtra {
            Button("Show / Focus Notch Island") {
                appDelegate.attachAndShow(store: store)
            }
            Button("Refresh") { store.refresh() }
            Toggle("This Mac Only (skip SSH)", isOn: $store.localOnly)
            Divider()
            Button("Quit AgentDock") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "capsule.portrait.fill")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.menu)

        #if DEBUG
        Window("AgentDock — Island Review", id: "design-review") {
            NotchReviewCanvas(store: store)
        }
        .defaultSize(width: 720, height: 380)
        #endif
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notch: NotchPanelController?
    private weak var storeRef: StatusStore?
    static var pendingStore: StatusStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            if let store = self?.storeRef ?? AppDelegate.pendingStore {
                self?.attachAndShow(store: store)
            }
        }
    }

    func attachAndShow(store: StatusStore) {
        storeRef = store
        if notch == nil {
            notch = NotchPanelController(store: store)
        }
        notch?.show()
    }
}

struct NotchReviewCanvas: View {
    @ObservedObject var store: StatusStore
    @State private var expanded = true

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 32)
                    // Fake MacBook camera notch — island parks here.
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 126, height: 26)

                    NotchIslandView(store: store, expanded: $expanded)
                        .padding(.top, 2)
                }
                Spacer()
                Text("Center notch · Dynamic Island · horizontal expand")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 16)
            }
        }
        .onAppear { store.startPolling() }
    }
}
