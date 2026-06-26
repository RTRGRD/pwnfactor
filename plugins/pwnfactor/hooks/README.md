# pwnfactor stop-hook — the ultracode gate

`hooks.json` registers a **Stop** hook → `gate-check.py`. It's the **enforcement layer** of pwnfactor's three-part gate, so even an always-on (ultracode-style) workflow can't quietly skip review:

1. **Contract** — onboarding adds to `CLAUDE.md`: *code-touching changes run `/pwnfactor:gg` before integrate.*
2. **Gate** — `/pwnfactor:gg` reviews the diff and writes `.pwnfactor/gate.json` (`head`, `verdict`, `ts`).
3. **Hook (this)** — on Stop, verifies a fresh passing gate exists for the current HEAD.

## What it does
On stop, if the working tree has **uncommitted code changes** with no fresh `.pwnfactor/gate.json` matching the current HEAD (verdict `ship`/`fix-then-ship`), it **nudges once**: "run `/pwnfactor:gg`." Then it gets out of the way.

## It cannot wedge a session (fail-open by design)
- Any error, a non-git dir, or missing input → **allow** (exit 0).
- `stop_hook_active` (already re-blocking this turn) → **allow** — one nudge per turn, never a loop.
- `PWNFACTOR_GATE_BYPASS=1` in the environment → **allow**.
- Claude Code's own block cap (8 consecutive blocks) is a hard backstop on top of all this.

## Turn it off
- This run only: `PWNFACTOR_GATE_BYPASS=1`.
- Permanently: `claude plugin disable pwnfactor` — the hook fires **only** where pwnfactor is enabled, never in unrelated projects.

## Scope & limits
It nudges on uncommitted **code** changes (`.py/.ts/.rs/.go/...`); once you commit or the gate passes, it's silent. It's a **backstop nudge**, not a cryptographic gate — the contract + the agent's own discipline are the primary layers. Requires `python` on PATH; if absent, the hook simply no-ops (fail-open).
