import Combine
import Foundation

/// Loads agent snapshots from demo fixtures or `lib/detect.py` JSON stdout.
/// detect.py remains the single detection source of truth.
@MainActor
final class StatusStore: ObservableObject {
    @Published private(set) var agents: [AgentSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefresh: Date?
    @Published var useDemo: Bool

    /// Absolute path to detect.py. Override via AGENT_STATUS_DETECT or bundle-relative default.
    var detectScriptURL: URL?

    /// Poll interval when the panel / app is live.
    var pollInterval: TimeInterval = 10

    private var timer: AnyCancellable?

    init(demo: Bool = true, detectScriptURL: URL? = nil) {
        self.useDemo = demo
        self.detectScriptURL = detectScriptURL ?? StatusStore.defaultDetectURL()
        if demo {
            agents = AgentSnapshot.demo
            lastRefresh = Date()
        }
    }

    static var preview: StatusStore {
        StatusStore(demo: true)
    }

    var relativeRefresh: String {
        guard let lastRefresh else { return "" }
        let s = Int(Date().timeIntervalSince(lastRefresh))
        if s < 5 { return "just now" }
        if s < 60 { return "\(s)s ago" }
        return "\(s / 60)m ago"
    }

    func startPolling() {
        refresh()
        timer = Timer.publish(every: pollInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func stopPolling() {
        timer?.cancel()
        timer = nil
    }

    func refresh() {
        if useDemo {
            agents = AgentSnapshot.demo
            lastRefresh = Date()
            lastError = nil
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil

        let script = detectScriptURL
        Task.detached(priority: .userInitiated) {
            let result = StatusStore.runDetect(script: script)
            await MainActor.run {
                self.isRefreshing = false
                switch result {
                case .success(let payload):
                    self.agents = payload.agents
                    self.lastRefresh = Date()
                    self.lastError = nil
                case .failure(let err):
                    self.lastError = err.message
                    // Keep prior agents visible; calm failure, no red banner.
                }
            }
        }
    }

    // MARK: - detect.py bridge

    nonisolated private static func runDetect(script: URL?) -> Result<DetectPayload, DetectError> {
        guard let script, FileManager.default.fileExists(atPath: script.path) else {
            return .failure(DetectError("detect.py not found"))
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["python3", script.path, "--format", "json"]
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return .failure(DetectError(error.localizedDescription))
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        if proc.terminationStatus != 0 {
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "exit \(proc.terminationStatus)"
            return .failure(DetectError(String(e.prefix(80))))
        }
        do {
            let payload = try JSONDecoder().decode(DetectPayload.self, from: data)
            return .success(payload)
        } catch {
            return .failure(DetectError("bad JSON from detect.py"))
        }
    }

    /// Order: AGENTDOCK_DETECT env → bundled Resources/detect.py → repo checkout.
    private static func defaultDetectURL() -> URL? {
        let env = ProcessInfo.processInfo.environment
        if let p = env["AGENTDOCK_DETECT"] ?? env["AGENT_STATUS_DETECT"] {
            return URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
        }
        let fm = FileManager.default
        if let bundled = Bundle.main.url(forResource: "detect", withExtension: "py"),
           fm.fileExists(atPath: bundled.path) {
            return bundled
        }
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let candidates = [
            cwd.appendingPathComponent("lib/detect.py"),
            cwd.appendingPathComponent("../lib/detect.py"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("agentdock/lib/detect.py"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("agent-status-bar/lib/detect.py"),
        ]
        return candidates.first { fm.fileExists(atPath: $0.path) }
    }
}

struct DetectError: Error { let message: String; init(_ m: String) { message = m } }
