"""pwnfactor swarm-budget hook - the cost discipline as a MECHANISM, not prose (v0.9.3).

Enforces three rules from `skills/run/model-economics.md` (third mechanical rule) and
`skills/swarm/SKILL.md` sections 4-5, all field-measured on 2026-09-02 when 5-7 concurrent Opus
builders, resumed at 400-650K tokens each, emptied an operator's five-hour window in minutes:

  1. CONCURRENCY CAP  - PreToolUse(Agent): refuse a MUTATING builder spawn (a `builder-*` agent
                        type, or any Agent with `isolation: worktree`) when the live count is at the
                        cap (default 2), or when it would be a second live OPUS builder (default 1).
  2. RESUME WEIGHT    - PreToolUse(SendMessage): refuse a resume of an agent whose transcript on
                        disk exceeds the threshold (default 600 KB, about 150K tokens) - a resume
                        re-sends the whole transcript; spawn fresh with the diff path, or fix it yourself.
  3. LEDGER READS     - PreToolUse(Agent): refuse a brief that points a builder at the project's
                        loop ledger (`reports/loop-*.md`) without naming `reports/CURRENT.md`.

Book-keeping: PreToolUse(Agent) records a spawn, SubagentStop records a stop, both in
`<transcript dir>/pwnfactor-swarm-budget.json`. The count can drift UP if an agent dies without a
stop event (a spend-limit kill); the refusal message says how to reset. It never drifts down, so it
fails toward refusing a spawn, never toward allowing one.

Exit codes per Claude Code hooks: 0 = allow, 2 = BLOCK (stderr is shown to the model). Any internal
error exits 0 - a broken budget hook must not stall the session.

Tunables (environment, or `.pwnfactor/budget.json` in the project):
  PWNFACTOR_MAX_BUILDERS=2  PWNFACTOR_MAX_OPUS_BUILDERS=1  PWNFACTOR_RESUME_MAX_BYTES=600000
  PWNFACTOR_BUDGET_RESET=1 (clears the live count on the next Agent call)
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

DEFAULTS = {"max_builders": 2, "max_opus_builders": 1, "resume_max_bytes": 600_000}


def _tunables(cwd: str) -> dict[str, int]:
    out = dict(DEFAULTS)
    cfg = Path(cwd) / ".pwnfactor" / "budget.json"
    try:
        if cfg.is_file():
            loaded = json.loads(cfg.read_text())
            out.update({k: int(v) for k, v in loaded.items() if k in out})
    except Exception:  # noqa: BLE001 - a bad config file must not stall the session
        pass
    for key, env in (
        ("max_builders", "PWNFACTOR_MAX_BUILDERS"),
        ("max_opus_builders", "PWNFACTOR_MAX_OPUS_BUILDERS"),
        ("resume_max_bytes", "PWNFACTOR_RESUME_MAX_BYTES"),
    ):
        if os.environ.get(env, "").isdigit():
            out[key] = int(os.environ[env])
    return out


def _state_path(transcript_path: str) -> Path:
    return Path(transcript_path).parent / "pwnfactor-swarm-budget.json"


def _load(p: Path) -> dict:
    try:
        return json.loads(p.read_text()) if p.is_file() else {"live": []}
    except Exception:  # noqa: BLE001
        return {"live": []}


def _save(p: Path, state: dict) -> None:
    try:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(state))
    except Exception:  # noqa: BLE001
        pass


def _is_mutating_builder(tool_input: dict) -> bool:
    kind = str(tool_input.get("subagent_type", ""))
    return kind.startswith("builder") or tool_input.get("isolation") == "worktree"


def _block(msg: str) -> None:
    sys.stderr.write("pwnfactor swarm-budget: " + msg + "\n")
    sys.exit(2)


def on_agent(payload: dict, tun: dict[str, int]) -> None:
    tool_input = payload.get("tool_input") or {}
    state_p = _state_path(payload.get("transcript_path", ""))
    state = _load(state_p)
    if os.environ.get("PWNFACTOR_BUDGET_RESET") == "1":
        state = {"live": []}
    prompt = str(tool_input.get("prompt", ""))
    if "reports/loop-" in prompt and "CURRENT.md" not in prompt:
        _block(
            "the brief points a builder at a loop ledger (reports/loop-*.md). Ledgers grow without bound "
            "and are the context bill. Point it at reports/CURRENT.md (one page) plus the exact files, or "
            "name a ledger SECTION by heading and say CURRENT.md is the entry point."
        )
    if not _is_mutating_builder(tool_input):
        return
    live = state.get("live", [])
    if len(live) >= tun["max_builders"]:
        _block(
            f"{len(live)} mutating builders are live (cap {tun['max_builders']}). Wait for one to return "
            "and integrate it first. If a builder died without a stop event, set PWNFACTOR_BUDGET_RESET=1 "
            f"for one call or delete {state_p}."
        )
    model = str(tool_input.get("model", "")).lower()
    opus_live = sum(1 for a in live if a.get("model") == "opus")
    if model == "opus" and opus_live >= tun["max_opus_builders"]:
        _block(
            f"{opus_live} Opus builder(s) live (cap {tun['max_opus_builders']}). Use Sonnet for this unit "
            "unless it is an authz / migration / credential surface - then wait for the Opus builder."
        )
    live.append({"ts": time.time(), "type": tool_input.get("subagent_type"), "model": model})
    state["live"] = live
    _save(state_p, state)


def on_subagent_stop(payload: dict) -> None:
    state_p = _state_path(payload.get("transcript_path", ""))
    state = _load(state_p)
    live = state.get("live", [])
    if live:
        live.pop(0)  # FIFO - the count is what the cap reads, not which one finished
    state["live"] = live
    _save(state_p, state)


def on_send_message(payload: dict, tun: dict[str, int]) -> None:
    tool_input = payload.get("tool_input") or {}
    to = str(tool_input.get("to", ""))
    if not to.startswith("a") or " " in to:
        return  # a teammate name or "main" - not a background agent id
    tasks = Path(payload.get("transcript_path", "")).parent / "tasks"
    out = tasks / f"{to}.output"
    try:
        size = out.stat().st_size if out.is_file() else 0
    except Exception:  # noqa: BLE001
        size = 0
    if size > tun["resume_max_bytes"]:
        _block(
            f"agent {to} has a {size // 1000} KB transcript (> {tun['resume_max_bytes'] // 1000} KB, "
            "about 150K tokens). A resume re-sends all of it. Do the fix yourself if it is small, or spawn "
            "a FRESH agent with a short brief and the diff path. Never resume an agent to wait."
        )


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:  # noqa: BLE001
        sys.exit(0)
    event = payload.get("hook_event_name", "")
    tun = _tunables(payload.get("cwd", os.getcwd()))
    try:
        if event == "PreToolUse" and payload.get("tool_name") == "Agent":
            on_agent(payload, tun)
        elif event == "PreToolUse" and payload.get("tool_name") == "SendMessage":
            on_send_message(payload, tun)
        elif event == "SubagentStop":
            on_subagent_stop(payload)
    except SystemExit:
        raise
    except Exception:  # noqa: BLE001 - never stall the session on a hook bug
        sys.exit(0)
    sys.exit(0)


if __name__ == "__main__":
    main()
