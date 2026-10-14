#!/usr/bin/env bash
# <xbar.title>Agent Status</xbar.title>
# <xbar.version>v0.1.0</xbar.version>
# <xbar.author>AgentDock</xbar.author>
# <xbar.desc>Zero-intrusion status dots for local + Studio agents (running/idle/stale/offline).</xbar.desc>
# <xbar.dependencies>python3,ssh</xbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>false</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>false</swiftbar.hideLastUpdated>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$PLUGIN_DIR/.." && pwd)"
DETECT="$ROOT/lib/detect.py"

# Prefer project config.yaml; allow override
export AGENT_STATUS_CONFIG="${AGENT_STATUS_CONFIG:-$ROOT/config.yaml}"

# Demo override for Linux box / first smoke: AGENT_STATUS_DEMO=1
if [[ "${AGENT_STATUS_DEMO:-}" == "1" ]] || [[ "${1:-}" == "--demo" ]]; then
  export AGENT_STATUS_DEMO=1
fi

if [[ ! -f "$DETECT" ]]; then
  echo "Agents ⚪"
  echo "---"
  echo "detect.py missing at $DETECT"
  exit 0
fi

# Fall back to example config if user has not copied yet
if [[ ! -f "$AGENT_STATUS_CONFIG" ]]; then
  export AGENT_STATUS_CONFIG="$ROOT/config.example.yaml"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Agents ⚪"
  echo "---"
  echo "python3 not found"
  exit 0
fi

# Soft-fail: never blank the menu bar on detector errors
set +e
out="$(python3 "$DETECT" --format swiftbar 2>&1)"
code=$?
set -e
if [[ $code -ne 0 ]] || [[ -z "$out" ]]; then
  echo "Agents ⚪"
  echo "---"
  echo "detector error ($code)"
  echo "$out" | head -n 5 | while IFS= read -r line; do
    echo "$line"
  done
  exit 0
fi
printf '%s\n' "$out"
