# pwnfactor stop-hook - the ultracode gate

`hooks.json` registers a **Stop** hook → `gate-check.py`. It's the **enforcement layer** of pwnfactor's three-part gate, so even an always-on (ultracode-style) workflow can't quietly skip review:

1. **Contract** - onboarding adds to `CLAUDE.md`: *code-touching changes run `/pwnfactor:gg` before integrate.*
2. **Gate** - `/pwnfactor:gg` reviews the diff and writes `.pwnfactor/gate.json` (`head`, `dirty_sha256`, `verdict`, `executed`, `ts`).
3. **Hook (this)** - on Stop, verifies a fresh passing gate exists for the current HEAD *and content*.

## What it does
On stop, if the working tree has **uncommitted code changes** with no fresh `.pwnfactor/gate.json` matching the current HEAD and diff hash (verdict `ship`/`fix-then-ship`), it says so **once**. Then it gets out of the way.

**It reports a state; it does not hand out a task.** The message says the gate closes at **commit** time, and that a lead with a build in flight should acknowledge it in one line and keep orchestrating. That wording is load-bearing: the earlier "run `/pwnfactor:gg` to review this diff" read as an order, and a conscientious lead obeyed it mid-build - ran the panel, reported, ended the turn with nothing in flight, and went silent. See `../skills/swarm/SKILL.md` section 7c.

When the gate is stale or missing, it also prints one line naming what the **last** gate recorded as `executed` (or "review-only - no execution recorded"), so you can see at a glance whether the previous ship was tested or argued. A missing or malformed field just omits the line.

## It cannot wedge a session (fail-open by design)
- Any error, a non-git dir, or missing input → **allow** (exit 0).
- `stop_hook_active` (already re-blocking this turn) → **allow** - one nudge per turn, never a loop.
- `PWNFACTOR_GATE_BYPASS=1` in the environment → **allow**.
- Claude Code's own block cap (8 consecutive blocks) is a hard backstop on top of all this.

## Turn it off
- This run only: `PWNFACTOR_GATE_BYPASS=1`.
- Permanently: `claude plugin disable pwnfactor` - the hook fires **only** where pwnfactor is enabled, never in unrelated projects.

## Scope & limits
It nudges on uncommitted **code** changes (`.py/.ts/.rs/.go/...`); once you commit or the gate passes, it's silent. It's a **backstop nudge**, not a cryptographic gate - the contract + the agent's own discipline are the primary layers. Requires `python` on PATH; if absent, the hook simply no-ops (fail-open).

## swarm-budget.py (v0.9.3)

The cost discipline as a mechanism: refuses a third live mutating builder (or a second Opus one),
refuses a SendMessage resume to an agent whose transcript exceeds about 600 KB (about 150K tokens), and
refuses a brief that points a builder at a reports/loop-*.md ledger without naming reports/CURRENT.md.
Exit 2 blocks with the reason; any internal error exits 0 so a hook bug cannot stall a session.
Tunables: PWNFACTOR_MAX_BUILDERS, PWNFACTOR_MAX_OPUS_BUILDERS, PWNFACTOR_RESUME_MAX_BYTES, or
.pwnfactor/budget.json; PWNFACTOR_BUDGET_RESET=1 clears the live count after a dead agent.
