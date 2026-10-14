import Foundation

/// One agent row. Decodes detect.py JSON (`--format json`).
struct AgentSnapshot: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let host: String
    let hostLabel: String
    let runtime: String
    let status: AgentStatus
    let evidence: String
    let ts: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id, name, host, runtime, status, evidence, ts
        case hostLabel = "host_label"
    }

    init(
        id: String,
        name: String,
        host: String,
        hostLabel: String = "",
        runtime: String,
        status: AgentStatus,
        evidence: String,
        ts: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.hostLabel = hostLabel
        self.runtime = runtime
        self.status = status
        self.evidence = evidence
        self.ts = ts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? "local"
        hostLabel = try c.decodeIfPresent(String.self, forKey: .hostLabel) ?? ""
        runtime = try c.decodeIfPresent(String.self, forKey: .runtime) ?? ""
        let statusRaw = try c.decode(String.self, forKey: .status)
        status = AgentStatus(rawValue: statusRaw) ?? .unknown
        evidence = try c.decodeIfPresent(String.self, forKey: .evidence) ?? ""
        ts = try c.decodeIfPresent(TimeInterval.self, forKey: .ts) ?? Date().timeIntervalSince1970
    }

    /// Short display name without host suffix clutter.
    var shortName: String {
        guard !hostLabel.isEmpty else { return name }
        let suffix = " (\(hostLabel))"
        return name.hasSuffix(suffix) ? String(name.dropLast(suffix.count)) : name
    }

    /// Host chip text (user-set label; empty when unlabeled).
    var hostChip: String { hostLabel }

    /// Trimmed evidence for dense rows (~28 chars).
    var shortEvidence: String {
        let t = evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= 28 { return t }
        let head = t.prefix(12)
        let tail = t.suffix(12)
        return "\(head)…\(tail)"
    }
}

/// Top-level detect.py JSON envelope.
struct DetectPayload: Codable {
    let agents: [AgentSnapshot]
    let title: String?
}

extension AgentSnapshot {
    /// Demo fixture matching `detect.py --demo` (Claude running, Codex idle, Studio Claude stale, Studio Codex offline).
    static let demo: [AgentSnapshot] = [
        AgentSnapshot(
            id: "claude-local",
            name: "Claude",
            host: "local", hostLabel: "Mac",
            runtime: "claude",
            status: .running,
            evidence: "pid 4242"
        ),
        AgentSnapshot(
            id: "codex-local",
            name: "Codex",
            host: "local", hostLabel: "Mac",
            runtime: "codex",
            status: .idle,
            evidence: "idle >2m"
        ),
        AgentSnapshot(
            id: "claude-studio",
            name: "Claude",
            host: "remote", hostLabel: "Remote",
            runtime: "claude",
            status: .stale,
            evidence: "session stale"
        ),
        AgentSnapshot(
            id: "codex-studio",
            name: "Codex",
            host: "remote", hostLabel: "Remote",
            runtime: "codex",
            status: .offline,
            evidence: "no process"
        ),
    ]
}
