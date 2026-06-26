---
name: validate
description: The validation conductor - prove a change ACTUALLY works, not that a harness said PASS. Selects validation lanes by change footprint, reads the project's ground-truth oracle (not its own classifier), triangulates (transcript -> oracle -> cross-model -> diverse judges), applies the vacuous-pass + blast-radius checks, and writes the HEAD-pinned gate artifact the Stop-hook enforces. Use to close any non-trivial change before integrate, or when asked "validate it" / "prove it works" / "is this actually done".
---

# /pwnfactor:validate - does it ACTUALLY work?

> **Say this first:** "`/pwnfactor:validate` is the does-it-actually-work gate. `gg` reviews the *diff*;
> `validate` proves the *real thing* accepts the change against your ground-truth oracle. Both are the
> Verify step of `run`; `validate` is the sibling of `gg`, not a restatement of it."

The governing rule: **the audit/test harness's own PASS/FAIL is an INPUT, not the answer.** A green suite,
a 200 response, a "N/N ready" log line - each is a CLAIM until the real thing confirms it.

## 0. The one thing you must have: a ground-truth oracle

`validate` reads your project's **`ground_truth_oracle:`** (from the orchestration profile, bound at `boot`):
the cheapest external authority that answers *"did the REAL thing accept this?"* - e.g. a native runtime's
accept-reject, a staging URL's real response, a query against the ingested store (RETRIEVE it; don't trust
"ingested"), or a real consumer call's result. Read ITS verdict, not your classifier's; never a mock.

**Doctrine:** read the oracle's verdict, not your classifier's; round UP on uncertainty; where the oracle is
unreachable, downgrade to **"verified to limit available"** - never fabricate certainty. No
`ground_truth_oracle:` in your profile? Bind one (`boot`) - without it you can only review the diff (`gg`).

**Two tiers, one conductor.** Validation = a **deterministic tier** (your tests/CI - portable, runs
anywhere) + this **ground-truth tier** (the oracle). The CI/local boundary **moves by oracle reachability**:
a cloud-reachable oracle (a staging URL) -> mostly CI; a local/hardware-only oracle -> CI + a local live
step. `validate` routes: run the deterministic tier, then read the oracle wherever it lives.

## 1. Scope the change -> select lanes (proportional)

`git diff --name-only` (vs the merge-base, or `HEAD~1` for one commit) -> map each path through the profile's
**`footprint_to_validation:`** map. Round UP on uncertainty.

- **Narrow** (one surface, no shared infra) -> that surface's single lane.
- **Shared infra / contract / `_SYNC`** -> FULL - but **FULL != "build".** Pick lanes proportionate to the
  change KIND (data -> live query; UI -> live drive; API -> staging request), and **validation is DEV-FIRST**:
  a production build/package run is for RELEASE only - never spin one to validate a non-release change.
- **Release / packaging** -> the build/package chain + the security sweep (`sweep`).

State the lanes + WHY. Don't run a FULL battery on a docs diff; don't run one narrow lane on a shared change.

**BLAST RADIUS (the trap that hides as a green):** for a SHARED-INFRA change, validation must prove the
change didn't regress the OTHER CONSUMERS - not just that the changed thing works. Spot-check the other
consumers against the oracle (the callers/inputs you DIDN'T change), and confirm the change didn't perturb
shared state (a regenerated manifest's hashes, a shared cache, a collision in a shared keyspace).
**Validating only the changed thing is a vacuous pass for shared infra.**

## 2. Triangulate (the validated verdict beats the harness verdict)

In this order, stopping when the verdict is unambiguous:
1. **Transcript-first** - read the RAW evidence (the actual stream / runtime output / test stdout), not a
   script's summary line. "PASS" / "N/N ready" is a CLAIM. Too-fast-to-be-real = a stale match.
2. **Ground-truth oracle** - read the oracle's verdict (§0); for shared infra, read it for the OTHER
   consumers too (blast radius). The non-circular authority.
3. **Cross-model (codex) - REQUIRED when available; VERIFY availability (health-check), never assume** - a
   wrapper error is NOT "codex unavailable"; only SKIP after a FAILED health-check, reporting "codex
   unavailable (verified)". Challenge the DECISION, not just defects; cite paths. (Mechanics, plugin-vs-CLI,
   setup + limits: `gg`'s `codex-integration.md` - `validate` doesn't re-specify them.)
4. **2-3 perspective-diverse judges** - only for HIGH-risk / contested findings; distinct lenses, not N
   identical refuters.

## 3. The vacuous-pass checklist (reject these - a green that proves nothing)

- **Non-deploy != pass** - "generated / wrote it" is not "the real thing accepted it."
- **No-op != fail** - an idempotent action that lands as a no-op IS success.
- **Reject-that-lands != fail** - a rejection log line is not a failure if the end state is right.
- **200-with-empty-row != pass** - a success status with an empty/placeholder payload is not proof.
- **Empty-diff-vs-empty-golden != pass** - nothing-vs-nothing is vacuous.
- **My-own-instruction-caused-it** - check whether an "issue" came from YOUR prompt before calling it a bug.

## 4. Write the gate artifact (makes the gate ENFORCED, not prose)

Write `.pwnfactor/gate.json` - the SAME artifact `gg` and the fail-open Stop-hook already use, with the SAME
verdict vocabulary (`ship | fix-then-ship | block`) so a clean `validate` actually satisfies the hook:

```json
{ "head": "<current HEAD sha>", "verdict": "ship|fix-then-ship|block",
  "lanes": ["<lane>", ...], "oracle": "<what was read + its verdict>",
  "vacuous_checked": true, "codex": "ran|unavailable",
  "baseline_delta": "<capability % vs last, if measured>", "ts": "<iso8601 UTC>" }
```

The Stop-hook treats a `ship`/`fix-then-ship` whose `head` == the current commit as a passing gate; `block`,
or a stale/missing artifact, means the gate hasn't passed. The hook reads only `head`+`verdict` - it CANNOT
tell a `gg` artifact (diff-reviewed) from a `validate` one (oracle-validated); both write this same file. So
the hook enforces *"a gate passed for this HEAD,"* and the DISCIPLINE of running `validate` (not just `gg`)
at Verify is what makes that gate mean *does-it-work*. `validate`'s artifact is a superset of `gg`'s (extra
`lanes`/`oracle`/... fields the hook ignores). **`.pwnfactor/` is gitignored / ephemeral - keep RAW oracle
output in the report, not this file (metadata only).**

## 5. Baseline / regression ledger

When the change touches a measured capability (%, recall, latency, pass-rate), append the validated number to
a DURABLE, tracked ledger - `{date, metric, value, head}` in a committed file (e.g. `reports/baseline-ledger.jsonl`),
NOT the ephemeral `gate.json` - and compare to the prior entry. A drop is a finding even if every test is
green. (gate.json carries only the `baseline_delta`; the tracked ledger is where history accumulates.)

## 6. Verdict

- **block** - the oracle rejected, a vacuous-pass trap is unresolved, or a HIGH finding stands.
- **fix-then-ship** - works, but reviewer/codex findings worth fixing first.
- **ship** - oracle-confirmed against the exit condition, vacuous checklist clean, blast radius clear.

Report: lanes run + WHY · the RAW oracle evidence (not a claim) · codex ran/skipped · the verdict · baseline
delta. If validation was impossible (oracle unreachable, codex absent), say so - downgrade to "verified to
limit available," never fabricate certainty.

## When to run it (cadence - match the check's COST to its frequency)

`validate` is the *final* gate, not the only check: **self-verify** after every chunk (cheap -> always);
**review checkpoint** (`gg` + codex) at each major decision, BEFORE it's baked in - not after the commit;
**validate** at Integrate, on the whole, re-run after fixes. Reviews-at-decisions and the final gate catch
DIFFERENT failures (a wrong fork found after three commits vs a vacuous green) - you need both.

## See also
- `gg` - the diff-review panel (the sibling Verify gate; `validate` does NOT restate it).
- `run` - the lifecycle whose Verify step runs `gg` + `validate`.
- `boot` - binds your `ground_truth_oracle:` + `footprint_to_validation:` (without them, `validate` can't run).
