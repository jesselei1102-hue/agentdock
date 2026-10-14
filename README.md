# AgentDock

A tiny macOS notch island that shows which of your AI coding agents are working, on this Mac and on your other Macs.

![screenshot](docs/screenshot.png) <!-- TODO: add screenshot -->

Collapsed, it hangs under the camera notch as a row of dots. Click it to expand a Dynamic-Island-style panel with the 6 most active agents.

## Zero-intrusion detection

AgentDock never hooks into agents, never asks them to write status, and spends no tokens. Every 10 s `lib/detect.py` reads:

- **processes**: `ps`/`pgrep -f` substring match against `process_patterns`
- **session files**: newest mtime among `session_globs` (transcripts, session logs)

Remote hosts get the same read-only probe over SSH (one multiplexed connection).

| Dot | Status | Meaning |
|---|---|---|
| green | running | process alive and a session file was written < 2 min ago |
| yellow | idle | process alive, no session writes for > 2 min (process-only agents never go above idle) |
| orange | stale | no process, session written < 1 h ago |
| gray | offline | no process, nothing recent (or host unreachable) |

Agents with neither a process nor session files are hidden. The rest are sorted by status, then recency, and the top `max_dots` are shown.

## Install / build

Requires macOS 14+, Xcode 15+, and `python3` (system python is fine; PyYAML is optional).

```sh
cd native
xcodebuild -project AgentStatusBar.xcodeproj -scheme AgentStatusBar \
  -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Release/AgentStatusBar.app
```

The app is unsigned, so on first launch right-click it and choose Open. CI also uploads an unsigned `AgentDock.zip` artifact for each build. `detect.py` and `agents.yaml` are bundled inside the app. To use a checkout instead, set `AGENTDOCK_DETECT=/path/to/lib/detect.py`.

CLI: `python3 lib/detect.py --format json` (`--demo` prints fake data).

## Config

Lives at `~/.config/agentdock/config.yaml`; override the path with `AGENTDOCK_CONFIG`. A commented template is written on first run. See [`config.example.yaml`](config.example.yaml).

```yaml
local:
  label: "MacBook"        # blank = show agent names without a suffix
hosts:                    # zero or more remote Macs
  - id: studio
    label: "Studio"
    ssh: mac-studio       # Host alias in ~/.ssh/config, e.g. a Tailscale name
idle_after_sec: 120
stale_after_sec: 3600
max_dots: 6
```

Remote hosts need key-based, non-interactive SSH (`BatchMode=yes`). Tailscale SSH works well. If a host is unreachable, the probe times out after 3 s and the host shows as a single gray dot.

## Adding agents

The catalog is [`lib/agents.yaml`](lib/agents.yaml):

```yaml
- id: myagent
  name: My Agent
  process_patterns: ["bin/myagent"]
  session_globs: ["~/.myagent/sessions/*.jsonl"]
```

To add or override entries locally (same `id` overrides), put them under `agents:` in your config. PRs that extend the catalog are welcome. Keep each list on one line so the no-PyYAML fallback parser can read it.

## Limitations

- Activity is a heuristic: a recent session-file write counts as "running".
- Codex app-server and some desktop apps stay alive in the background, so they show idle even when nothing is open (optimistic).
- Plain Claude desktop chat (non-Cowork) writes no reliable activity file, so it shows idle. Desktop apps (Qoder, Devin, Amazon Quick…) may write caches or IndexedDB while idle, which can keep them green longer than real work.
- Process-only agents (Ollama, Agent Zero) cap at idle.
- Remote probe runs `ps` and `stat` over SSH. macOS/Linux only.

## License

MIT
