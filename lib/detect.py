"""AgentDock: zero-intrusion agent status detector.

Reads processes + session file mtimes (locally and over SSH). Never asks agents
to write status and never talks to their APIs.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None  # type: ignore


HERE = Path(__file__).resolve().parent
CATALOG_FILE = HERE / "agents.yaml"
CONFIG_PATH = Path(os.path.expanduser("~/.config/agentdock/config.yaml"))
DEFAULT_SSH_OPTS = (
    "-o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "
    "-o ControlMaster=auto -o ControlPath=/tmp/agentdock-%r@%h:%p -o ControlPersist=120"
)

TEMPLATE = """# AgentDock config (generated on first run). See config.example.yaml in the repo.

# This Mac. Fill in a label (e.g. "MacBook") to show rows as "Claude (MacBook)".
# Leave blank to show the agent name alone.
local:
  label: ""

# Remote Macs probed read-only over SSH (e.g. via Tailscale). Zero hosts is fine.
# ssh is a Host alias from ~/.ssh/config. Fill in label yourself (blank = no suffix).
hosts: []
#  - id: studio
#    label: ""
#    ssh: my-other-mac
#    ssh_opts: "-o BatchMode=yes -o ConnectTimeout=3"   # optional

idle_after_sec: 120
stale_after_sec: 3600
discover: true
max_dots: 6

# Extra / overriding catalog entries (same shape as agents.yaml).
agents: []
"""

STATUSES = ("running", "idle", "stale", "offline", "unknown")
EMOJI = {
    "running": "\U0001F7E2",
    "idle": "\U0001F7E1",
    "stale": "\U0001F7E0",
    "offline": "\u26AB",
    "unknown": "\u26AA",
}


def _expand(path: str) -> str:
    return os.path.expanduser(os.path.expandvars(path))


# ---------------------------------------------------------------- YAML

def _strip_comment(line: str) -> str:
    q = None
    for i, ch in enumerate(line):
        if q:
            if ch == q:
                q = None
        elif ch in "\"'":
            q = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t"):
            return line[:i]
    return line


def _scalar(v: str) -> Any:
    v = v.strip()
    if v == "":
        return None
    if v.startswith("["):
        try:
            return json.loads(v)
        except ValueError:
            inner = v.strip("[]")
            return [x.strip().strip("\"'") for x in inner.split(",") if x.strip()]
    if v.startswith("{") and v.endswith("}"):
        return {} if v == "{}" else json.loads(v)
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    if v.lower() in ("true", "false"):
        return v.lower() == "true"
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    return v


def _minimal_yaml(text: str) -> Any:
    """Fallback when PyYAML is missing (e.g. macOS system python3).

    Supports the subset used by AgentDock: nested block mappings, block lists
    (of scalars or mappings), one-line flow lists, quoted/plain scalars.
    """
    lines = []
    for raw in text.splitlines():
        s = _strip_comment(raw).rstrip()
        if s.strip():
            lines.append((len(s) - len(s.lstrip(" ")), s.strip()))

    def parse(i: int, ind: int) -> tuple[Any, int]:
        if i >= len(lines):
            return None, i
        if lines[i][1].startswith("- ") or lines[i][1] == "-":
            out: list[Any] = []
            while i < len(lines) and lines[i][0] == ind and lines[i][1].startswith("-"):
                body = lines[i][1][1:].strip()
                if body and re.match(r"^[\w.-]+:(\s|$)", body):
                    # mapping item: treat body as first key at indent ind+2
                    lines[i] = (ind + 2, body)
                    val, i = parse(i, ind + 2)
                    out.append(val)
                elif body:
                    out.append(_scalar(body)); i += 1
                else:
                    val, i = parse(i + 1, lines[i + 1][0] if i + 1 < len(lines) else ind + 2)
                    out.append(val)
            return out, i
        out_d: dict[str, Any] = {}
        while i < len(lines) and lines[i][0] == ind and not lines[i][1].startswith("- "):
            key, _, val = lines[i][1].partition(":")
            key = key.strip().strip("\"'")
            i += 1
            if val.strip() == "":
                if i < len(lines) and (lines[i][0] > ind or (lines[i][0] == ind and lines[i][1].startswith("- "))):
                    out_d[key], i = parse(i, lines[i][0])
                else:
                    out_d[key] = None
            else:
                out_d[key] = _scalar(val)
        return out_d, i

    data, _ = parse(0, lines[0][0]) if lines else ({}, 0)
    return data


def _load_yaml(path: Path) -> Any:
    text = path.read_text(encoding="utf-8")
    if yaml is not None:
        return yaml.safe_load(text)
    return _minimal_yaml(text)


# ---------------------------------------------------------------- config

def config_path() -> Path:
    env = os.environ.get("AGENTDOCK_CONFIG")
    return Path(_expand(env)) if env else CONFIG_PATH


def load_catalog(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    base = (_load_yaml(CATALOG_FILE) or {}).get("agents") or [] if CATALOG_FILE.is_file() else []
    by_id: dict[str, dict[str, Any]] = {}
    for a in base:
        if isinstance(a, dict) and a.get("id"):
            by_id[str(a["id"])] = dict(a)
    for a in cfg.get("agents") or []:
        if isinstance(a, dict) and a.get("id"):
            by_id.setdefault(str(a["id"]), {}).update(a)
    out = []
    for a in by_id.values():
        a.setdefault("name", a["id"])
        a["process_patterns"] = list(a.get("process_patterns") or [])
        a["session_globs"] = list(a.get("session_globs") or [])
        out.append(a)
    return out


def load_config(path: Path | None = None, demo: bool = False) -> dict[str, Any]:
    cfg_path = path or config_path()
    if not cfg_path.is_file():
        if path is not None:
            raise SystemExit(f"config not found: {cfg_path}")
        try:
            cfg_path.parent.mkdir(parents=True, exist_ok=True)
            cfg_path.write_text(TEMPLATE, encoding="utf-8")
        except OSError:
            pass
    data: Any = {}
    if cfg_path.is_file():
        data = _load_yaml(cfg_path) or {}
    if not isinstance(data, dict):
        raise SystemExit("config root must be a mapping")

    data.setdefault("idle_after_sec", 120)
    data.setdefault("stale_after_sec", 3600)
    data.setdefault("demo_mode", False)
    data.setdefault("discover", True)
    data.setdefault("max_dots", 6)
    data["agents"] = data.get("agents") or []

    local = data.get("local") or {}
    hosts = [{"id": "local", "label": str((local or {}).get("label") or ""), "ssh": None}]
    for h in data.get("hosts") or []:
        if not isinstance(h, dict) or not h.get("ssh"):
            continue
        hid = str(h.get("id") or h["ssh"])
        hosts.append({
            "id": hid,
            "label": str(h.get("label") or ""),
            "ssh": str(h["ssh"]),
            "ssh_opts": str(h.get("ssh_opts") or DEFAULT_SSH_OPTS),
        })
    data["_hosts"] = hosts

    if demo or os.environ.get("AGENTDOCK_DEMO", "").lower() in ("1", "true", "yes"):
        data["demo_mode"] = True
    return data


def _run(cmd: list[str], timeout: float = 5.0) -> tuple[int, str, str]:
    try:
        p = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return p.returncode, p.stdout or "", p.stderr or ""
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except FileNotFoundError as e:
        return 127, "", str(e)


def local_processes(patterns: list[str]) -> list[dict[str, Any]]:
    """Match local processes by simple substring against ps output."""
    if not patterns:
        return []
    # Prefer pgrep if available for each pattern; fall back to ps.
    found: list[dict[str, Any]] = []
    seen: set[int] = set()

    if shutil.which("pgrep"):
        for pat in patterns:
            # -f full cmdline; -a print pid + command (GNU/BSD variants differ)
            code, out, _ = _run(["pgrep", "-lf" if sys.platform == "darwin" else "-af", pat], timeout=3)
            if code not in (0, 1):
                continue
            for line in out.splitlines():
                line = line.strip()
                if not line:
                    continue
                parts = line.split(None, 1)
                try:
                    pid = int(parts[0])
                except ValueError:
                    continue
                # Skip self
                if pid == os.getpid():
                    continue
                cmd = parts[1] if len(parts) > 1 else pat
                if "detect.py" in cmd or "agent-status" in cmd:
                    continue
                if pid in seen:
                    continue
                if not any(p in cmd for p in patterns):
                    # pgrep -f may over-match; keep if pattern in line
                    if not any(p in line for p in patterns):
                        continue
                seen.add(pid)
                found.append({"pid": pid, "cmd": cmd[:400], "host": "local"})
        return found

    code, out, _ = _run(["ps", "ax", "-o", "pid=,command="], timeout=3)
    if code != 0:
        return found
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        try:
            pid = int(parts[0])
        except ValueError:
            continue
        cmd = parts[1] if len(parts) > 1 else ""
        if pid == os.getpid() or "detect.py" in cmd:
            continue
        if any(p in cmd for p in patterns):
            if pid not in seen:
                seen.add(pid)
                found.append({"pid": pid, "cmd": cmd[:400], "host": "local"})
    return found


def remote_processes(
    host: str,
    user: str,
    ssh_opts: str,
    patterns: list[str],
) -> tuple[list[dict[str, Any]], str | None]:
    """Run ps over SSH; fail soft."""
    if not patterns:
        return [], None
    if not shutil.which("ssh"):
        return [], "ssh not found"

    target = f"{user}@{host}" if user else host
    # Quote patterns lightly for remote shell
    pat_re = "|".join(re.escape(p) for p in patterns)
    remote = (
        "ps ax -o pid=,command= 2>/dev/null | "
        f"grep -E {json.dumps(pat_re)} | grep -v grep || true"
    )
    cmd = ["ssh"] + ssh_opts.split() + [target, remote]
    code, out, err = _run(cmd, timeout=8)
    if code != 0:
        msg = (err or out or f"ssh exit {code}").strip()[:160]
        return [], msg or "ssh failed"

    found: list[dict[str, Any]] = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        try:
            pid = int(parts[0])
        except ValueError:
            continue
        cmdstr = parts[1] if len(parts) > 1 else ""
        found.append({"pid": pid, "cmd": cmdstr[:120], "host": host})
    return found, None


def _expand_arg_globs(globs: list[str], procs: list[dict[str, Any]]) -> list[str]:
    """Glob entries like "{arg:gui}/memory/*" take the path after `gui` in each matched command line."""
    out: list[str] = []
    for g in globs:
        m = re.search(r"\{arg:([^}]+)\}", g)
        if not m:
            out.append(g)
            continue
        flag = m.group(1)
        for p in procs:
            mm = re.search(r"(?:^|\s)" + re.escape(flag) + r"\s+(.+?)(?:\s+--|$)", p.get("cmd", ""))
            if mm:
                out.append(g.replace(m.group(0), mm.group(1).strip()))
    return out


def newest_mtime_local(globs: list[str]) -> tuple[float | None, str | None]:
    newest: float | None = None
    path: str | None = None
    for g in globs:
        pattern = _expand(g)
        for p in glob.glob(pattern, recursive=True):
            try:
                m = os.path.getmtime(p)
            except OSError:
                continue
            if newest is None or m > newest:
                newest = m
                path = p
    return newest, path


def newest_mtime_remote(
    host: str,
    user: str,
    ssh_opts: str,
    globs: list[str],
) -> tuple[float | None, str | None, str | None]:
    if not globs:
        return None, None, None
    if not shutil.which("ssh"):
        return None, None, "ssh not found"
    target = f"{user}@{host}" if user else host
    # Expand globs remotely; print epoch mtime and path
    parts = " ".join(_expand(g).replace(" ", "\\ ") for g in globs)
    remote = (
        "setopt nullglob 2>/dev/null; shopt -s nullglob 2>/dev/null; "
        f"for f in {parts}; do "
        '[ -f "$f" ] && { stat -f "%m %N" "$f" 2>/dev/null || stat -c "%Y %n" "$f"; }; '
        "done | sort -nr | head -1"
    )
    cmd = ["ssh"] + ssh_opts.split() + [target, remote]
    code, out, err = _run(cmd, timeout=8)
    if code != 0:
        return None, None, (err or f"ssh exit {code}").strip()[:160]
    line = out.strip().splitlines()[-1] if out.strip() else ""
    if not line:
        return None, None, None
    bits = line.split(None, 1)
    try:
        m = float(bits[0])
    except ValueError:
        return None, None, None
    p = bits[1] if len(bits) > 1 else None
    return m, p, None


def classify(
    has_proc: bool,
    last_activity: float | None,
    now: float,
    idle_after: int,
    stale_after: int,
) -> str:
    if has_proc:
        if last_activity is None:
            return "running"
        age = now - last_activity
        if age <= idle_after:
            return "running"
        return "idle"
    if last_activity is not None:
        age = now - last_activity
        if age <= stale_after:
            return "stale"
        return "offline"
    return "offline"


def _row_name(name: str, label: str) -> str:
    return f"{name} ({label})" if label else name


def demo_snapshot(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    now = time.time()
    rows = [("claude", "Claude", "local", "Mac", "running"), ("codex", "Codex", "local", "Mac", "idle"),
            ("claude", "Claude", "remote", "Remote", "stale"), ("codex", "Codex", "remote", "Remote", "offline")]
    return [{"id": f"{r}-{h}", "name": _row_name(n, l), "agent": n, "host": h, "host_label": l,
             "runtime": r, "status": st, "evidence": "demo", "ts": now, "last": 0}
            for r, n, h, l, st in rows]


def detect_one(agent: dict[str, Any], host: dict[str, Any], cfg: dict[str, Any], now: float) -> dict[str, Any]:
    patterns = list(agent.get("process_patterns") or [])
    globs = list(agent.get("session_globs") or [])
    idle_after = int(cfg.get("idle_after_sec", 120))
    stale_after = int(cfg.get("stale_after_sec", 3600))

    procs: list[dict[str, Any]] = []
    mtime: float | None = None
    mpath: str | None = None
    err: str | None = None

    if not host.get("ssh"):
        procs = local_processes(patterns)
        globs = _expand_arg_globs(globs, procs)
        mtime, mpath = newest_mtime_local(globs)
    else:
        ssh, opts = host["ssh"], host.get("ssh_opts") or DEFAULT_SSH_OPTS
        procs, err = remote_processes(ssh, "", opts, patterns)
        for pr in procs:
            pr["host"] = host["id"]
        if globs:
            mtime, mpath, err2 = newest_mtime_remote(ssh, "", opts, globs)
            if err is None and err2:
                err = err2

    has_proc = len(procs) > 0
    last_activity = mtime
    if has_proc and last_activity is None:
        # No session file to prove work: alive but not provably busy -> idle.
        last_activity = now - idle_after - 1

    if err and not has_proc and mtime is None:
        status = "offline"
        evidence = f"ssh:{err}"
    else:
        status = classify(has_proc, last_activity, now, idle_after, stale_after)
        if has_proc:
            p0 = procs[0]
            evidence = f"pid={p0['pid']} {p0.get('cmd', '')[:60]}"
        elif mpath:
            age = int(now - (mtime or now))
            evidence = f"session {mpath} ({age}s ago)"
        else:
            evidence = "no process / no recent session"

    name = str(agent.get("name") or agent.get("id", "?"))
    return {
        "id": f"{agent.get('id', '?')}-{host['id']}",
        "name": _row_name(name, host["label"]),
        "agent": name,
        "host": host["id"],
        "host_label": host["label"],
        "runtime": agent.get("id", ""),
        "status": status,
        "evidence": evidence,
        "ts": now,
        "last": last_activity or 0,
        "_found": has_proc or mtime is not None,
        "_hasmtime": mtime is not None,
        "_sshfail": bool(err) and not has_proc and mtime is None,
    }


RANK = {"running": 0, "idle": 1, "stale": 2, "offline": 3, "unknown": 4}


def _clean(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    for r in rows:
        r.pop("_found", None); r.pop("_sshfail", None); r.pop("_hasmtime", None)
    return rows


def snapshot(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    if cfg.get("demo_mode"):
        return demo_snapshot(cfg)
    now = time.time()
    catalog = load_catalog(cfg)
    rows: list[dict[str, Any]] = []
    for host in cfg["_hosts"]:
        hrows = [detect_one(a, host, cfg, now) for a in catalog]
        if host.get("ssh") and hrows and all(r["_sshfail"] for r in hrows):
            rows.append({"id": host["id"], "name": host["label"] or host["id"], "agent": host["label"] or host["id"],
                         "host": host["id"], "host_label": host["label"], "runtime": "",
                         "status": "offline", "evidence": "ssh unreachable", "ts": now, "last": 0,
                         "_found": True})
            continue
        rows.extend(hrows)
    if not cfg.get("discover"):
        return _clean(rows)
    found = [r for r in rows if r.get("_found")]
    found.sort(key=lambda r: (RANK.get(r["status"], 9), -(r["last"] if r.get("_hasmtime") else 0)))
    return _clean(found[: int(cfg.get("max_dots", 6))])


def title_line(rows: list[dict[str, Any]]) -> str:
    counts = {s: 0 for s in STATUSES}
    for r in rows:
        counts[r.get("status", "unknown")] = counts.get(r.get("status", "unknown"), 0) + 1
    # Compact: Agents 2●1○0◌ — use emoji short form
    parts = []
    if counts["running"]:
        parts.append(f"{counts['running']}🟢")
    if counts["idle"]:
        parts.append(f"{counts['idle']}🟡")
    if counts["stale"]:
        parts.append(f"{counts['stale']}🟠")
    if counts["offline"]:
        parts.append(f"{counts['offline']}⚫")
    if counts["unknown"]:
        parts.append(f"{counts['unknown']}⚪")
    body = "".join(parts) if parts else "—"
    return f"Agents {body}"


def print_swiftbar(rows: list[dict[str, Any]]) -> None:
    print(title_line(rows))
    print("---")
    by_host: dict[str, list[dict[str, Any]]] = {}
    for r in rows:
        by_host.setdefault(r.get("host", "?"), []).append(r)

    for host in sorted(by_host.keys(), key=lambda h: (h != "local", h)):
        hr = by_host[host]
        print(hr[0].get("host_label") or host)
        for r in hr:
            em = EMOJI.get(r["status"], "\u26AA")
            print(f"-- {em} {r['agent']}  {r['status']}  | {r['evidence']}")
    print("---")
    print("Refresh | refresh=true")


def print_json(rows: list[dict[str, Any]]) -> None:
    json.dump({"agents": rows, "title": title_line(rows)}, sys.stdout, indent=2)
    sys.stdout.write("\n")


def main() -> None:
    ap = argparse.ArgumentParser(description="AgentDock detector (zero intrusion)")
    ap.add_argument("--config", type=Path, default=None)
    ap.add_argument("--demo", action="store_true", help="Fake agents (no pgrep/SSH)")
    ap.add_argument(
        "--format",
        choices=("swiftbar", "json"),
        default="json",
        help="Output format (default json for CLI)",
    )
    args = ap.parse_args()
    cfg = load_config(args.config, demo=args.demo)
    rows = snapshot(cfg)
    if args.format == "swiftbar":
        print_swiftbar(rows)
    else:
        print_json(rows)


if __name__ == "__main__":
    main()
