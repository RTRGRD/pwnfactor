---
name: swarm
description: Deliberate multi-agent BUILD loop for one chosen feature. Invoked BY CHOICE by a lead agent at high/max reasoning effort — NOT always-on. Decomposes a feature into parallel-safe units, isolates mutating builders in worktrees, runs build->self-verify->refine loops, and hands a clean, conflict-free, self-verified diff to the gg verify gate. Use when an operator decides to invest in a substantial feature and asks how to roll it out, orchestrate it, or fan out subagents.
---

# Orchestrate a Feature (deliberate fan-out)

> **Say this first:** "`/pwnfactor:swarm` fans out a squad of subagents to build a big feature in parallel — deliberately, when the work splits into independent units. Big features only; skip small stuff."

The lead's control loop for ONE chosen feature: **shape → (scout if blind) → barrier-land shared/migrations → fan out builders → self-verify (loop-until-green) → integrate → hand to the VERIFY panel.** This is the BUILD half. The verify gate is the separate `gg` skill (§6) — don't rebuild it here.

> **Load this project's profile first.** Read `.claude/orchestration-profile.md` for THIS repo's component seams, shared-contract barrier, migration ritual, mutation/rollback model, hotspots, single-slot constraints, and test commands. **No profile? Run `/pwnfactor:boot`** to generate one (or infer the equivalents from the repo + `CLAUDE.md` and offer to write one). The method below is project-agnostic — it reads your profile for specifics; the one concrete instance is the labeled **Worked example** at the end.

## 0. Two laws

1. **DELIBERATE MUTATION, DYNAMIC EXPLORATION.** Opposite of Ultracode (auto-fans-out everything). The discipline here governs agents that **write**: parallel *builders* are an earned exception that names its signal and isolates (§5); **default _mutating_ topology is SOLO**. But **read-only fan-out (research, scouts, verification skeptics) is the lead's standing discretion — spawn it dynamically as the work demands**; read-only agents can't race the index or merge-conflict, so they carry none of §5's cost. Avoid reflexive *mutating* swarms, not exploration.
2. **TWO ORTHOGONAL DIALS, set from different signals — they MULTIPLY, never substitute.**
   - **EFFORT** (medium/high/max) = how hard ONE agent thinks. Operator-set per feature; risk-driven per unit. The lead must NOT silently downgrade it.
   - **TOPOLOGY** (solo / N builders; pipeline vs parallel) = shape of the work. Graph-driven; capped by edge-free unit count.
   - "Do this at max effort" means *invest more* — deeper thinking, and at the lead's discretion wider **read-only** exploration; it neither mandates nor forbids parallelism. Raise EFFORT first (cheap, no coordination tax). Reach for parallel **builders** only for genuinely disjoint *mutating* work. A parallel *building* run costs ~an order of magnitude more than a solo chat — the expensive mistake is reaching for mutating topology when one tier of effort (or a read-only scout) was the fix.

## 1. Solo vs orchestrate (this governs *mutating builders*)

> **Read-only fan-out is not gated here.** Scouts, parallel research, and verification skeptics are the lead's dynamic discretion — no worktree, no conflict, no "name your signal" ceremony. The rules below decide only when to split *builders* that write.

**Build the unit graph (§2) FIRST. The graph decides — not how the feature "feels."**

Go **SOLO** if ANY holds:
- Can't name **≥2 units with disjoint files and no edge between them** → one unit.
- Every candidate-pair shares a file or a contract/migration/ordering edge.
- Cohesive/novel design needing one coherent mind (fan-out fragments it).
- Mechanical edit with obvious shape (rename, thread a param, add a field).
- Combined context fits the lead's window without compaction.

**Fan-out GATE — parallel builders ONLY if ALL hold:**
- (a) ≥2 units with **disjoint files** in different components;
- (b) no unit depends on another's *code* (contract/migration edges already resolved at a barrier);
- (c) combined exploration exceeds what the lead holds without compaction, OR each unit's verification is independent.

Any fail → solo. If your project enforces one-component-per-task, a cross-component seam is usually the only legitimate fan-out boundary.

**Theater test:** if the lead already holds (or can cheaply load) the few files a unit touches, spawning a subagent for it is net-negative — judge by overlap with context already loaded, not a token count.

## 2. Decomposition — shape before any code

Produce a **one-screen unit graph** (no graph ⇒ not ready to fan out). Per candidate unit tag: `{component, files-touched, shared-contract? migration? mutating? risk}`. Edge **A→B** if they share a file, B imports A's new contract, or B depends on A's migration/ordering.

**Cut along the repo-enforced seams in your profile** (its *Components & parallel seams*). **A unit editing two components is mis-cut** — split it, coordinate via the shared contract.

**Barriers (these collapse parallelism to one agent — they are not lanes):**

- **Shared-contract barrier (hard).** Any new/changed cross-cutting contract ⇒ **ONE agent lands it FIRST and MERGES before any consumer starts.** Two agents in the shared-contract area corrupt it even in separate worktrees — a **merge conflict, not an index race, so worktrees don't save you.** Your profile's **Shared-contract barrier** names the location + sync rule (mirrored types, barrels, parity test).
- **Migration barrier (hard).** At most ONE migrating unit per feature; sequence it FIRST and ALONE. A schema-diff check is rarely sufficient — follow your profile's **Migration ritual** (explicit rev id, bump the head pointer, pass the migration test), then run any required refresh before consumers validate the live backend.
- **Same-file edge.** Two units that must edit one file are **ONE unit** (or strictly sequenced) — worktrees give a merge conflict, not a save. Check your profile's **Hotspot files** before splitting.
- **Single-slot components.** Some dirs look like separate components but share one toolchain / build / lockfile (your profile's **Single-slot constraints**). Treat each as **ONE parallel slot** unless the operator relaxes it.
- **Mutating-rail triad.** dry-run + checkpoint + rollback live in **ONE indivisible unit** (one state machine). Never split apply from rollback/checkpoint across agents. Add new variants at the existing extension seam your profile names; don't fan a new rail out across agents.

**Budget cap:** max useful builders = number of edge-free units, NOT your token budget. Builders past that manufacture merge conflicts. **Scale EFFORT before agent count.**

**Re-plan on contract surprise:** a builder that discovers mid-unit it needs an un-barriered shared-type change **STOPS at the component boundary**, returns the contract delta, and the lead **reopens the shared barrier (serialize it)** — the builder never reaches into the shared-contract area itself.

## 3. Topology

| Topology | Use when | Mechanics |
|---|---|---|
| **SOLO / SEQUENTIAL** | 1 unit, or a linear chain A→B→C (different components, each depends on prior) | One agent at a time. No worktrees. Default. |
| **PIPELINE** (no barrier) | ≥2 independent units; each flows build→self-verify→**merge as it lands** | **Default for multi-stage fan-out.** A topologically-ready unit merges after a stale-base reconcile; don't idle it waiting for siblings. |
| **PARALLEL** (await-all) | A step genuinely needs ALL prior results at once — a shared-contract synthesis, or final integration wiring | Idles agents — reserve for true all-inputs dependencies only. |

- Pipeline-merge ready units as they land. Await-all is **only** for the shared-contract decision and final whole-diff integration (§6).
- A linear cross-component chain is **sequential handoffs, not parallel** — no concurrency, no worktrees.
- **Width:** spawn no more parallel returns than the lead can reconcile in one synthesis pass — treat **~4 as a soft ceiling**, wave the rest.

## 4. Effort & model tiers

**EFFORT (operator-set; risk-driven per unit):**
- **max** — irreversible/mutating path (deploy, destructive op, migration, auth/RBAC, secrets/vault) OR genuinely novel design. Safety-rail wiring on any irreversible surface is max regardless of topology.
- **high** — real design surface, security-sensitive, multi-unit, or a well-specified addition with clear precedent (the typical invocation tier).
- **medium** — ONLY a shape-obvious **leaf unit** (one read-only endpoint, one leaf view) or a mechanical fixer sub-role. NEVER the feature-level or lead tier.

**MODEL:**
- **Opus** — novel/ambiguous/security-sensitive reasoning (tool-use loops, authz logic, the state machine, contract design).
- **Sonnet-high** — well-specified breadth (boilerplate, exhaustive tests, repetitive wrappers) **ONLY if the unit touches none of: auth/RBAC, vault/credentials/secret-stripping, command/SQL construction, untrusted-data egress, migrations, or a destructive/mutating path.** Anything touching those is **Opus regardless of how mechanical it looks.** Unsure ⇒ in scope ⇒ Opus.

**Operator's "extra/high/max mode"** is the EFFORT dial: deep thinking + generous per-agent token budget. It does NOT license fan-out. Max-effort can be SOLO (a security-sensitive refactor); a wide feature can run with medium leaves if its units are independent and low-risk.

**Combining:** DEFAULT = solo lead, high effort, Opus; escalate only when a rule fires. The LEAD runs at the feature's tier or higher (it synthesizes + re-plans), may **PROPOSE** a downgrade to the operator (surfacing cost) but **never apply one silently**.

## 5. Isolation & safety (physical, not polite)

1. **Worktree isolation is the LEAD's job.** Prefer the harness-native primitive — spawn each parallel builder with **`isolation: "worktree"`** (the Agent/Workflow tool auto-creates a fresh worktree and cleans it up). If creating worktrees by hand instead, the **lead** runs `git worktree add .claude/worktrees/<unit> <base>` BEFORE spawning and launches each builder pinned to its own path. Either way the invariant is the same: **each builder's first action is `git rev-parse --show-toplevel`; it ABORTS if its toplevel equals the lead's repo root or another unit's path.** Distinct toplevel per concurrent builder, **asserted not assumed**. Read-only scouts get NO worktree.
2. **Builders NEVER `git add`/`commit`** (hard rule — index races). They return a distilled summary + diff; the **LEAD** pulls each worktree's diff, integrates on the feature branch, and makes checkpoint commits at barriers.
3. **Rebase a stale base before measuring green.** A worktree cut from an older commit is reconciled onto current HEAD *before* its self-verify.
4. **Topological order:** shared-contract barrier → migration barrier → **run your profile's refresh step (rebuild/redeploy) and assert the new schema + code path are live** → release builders that smoke-test the live backend → independent builders (pipeline) → lead integrates → VERIFY panel. (Unit-test-only builders may start earlier.)
5. **Refresh non-hot-reloading services at server/migration checkpoints.** If your stack builds an artifact that does NOT hot-reload (e.g. a container image), rebuild+recreate it after the relevant merge — your profile's **Build/refresh** step. A stale artifact fakes green.
6. **Safety rails are unit-integrity constraints — and confirm your project's rollback MODEL (often checkpoint-FIRST, not auto-undo).** Many systems don't auto-roll-back a failed apply: rollback is a *separate, operator-initiated, checkpoint-driven* action, and a failed unit may not even be rollback-eligible (your profile's **Mutation & rollback model**). So a mutating unit is **green only when an automated test proves: (a) dry-run yields a plan with no side effects; (b) apply records a checkpoint; (c) the rollback path restores prior state from that checkpoint, confirmed by readback; (d) audit/records are metadata-only.** Run against real test targets or faithful transport mocks (mocks must decode/route exactly like the real transport). **Asserting rollback merely exists, or assuming a mid-apply failure auto-rolls-back, is RED.** Effort never buys past a HITL gate before an irreversible action.
7. **Secrets never enter the loop's artifacts.** Keys/passwords/tokens/provider-creds never appear in a brief, a distilled return, the plan file, a fixture, a log, or a payload — only credential *names*. A unit that would serialize a secret is mis-designed; stop it.

## 6. The build → verify loop

Hand the panel an **already green coherent diff**. The panel is the GATE, not the loop's first QA.

**Trust no subagent's "done."** Every agent returns a 1–2k-token distillation: files touched, exact command + output, residual risks. Treat it as a **CLAIM**.
- **Re-verify proportionally.** Independently re-run the exact cited command for every claim a merge/safety decision RESTS ON (riskiest unit's green, any safety-rail assertion, any contract consumers depend on). Spot-check low-risk units (read the diff, confirm the test exists). **Never act on a mutating or credential claim without re-running its cited proof.**
- **"Verbatim output" means TEST-RUNNER output** (pytest/tsc/ruff/etc). **Host-command output can carry secrets — never paste it verbatim; record redacted proof + the redaction reason.**

**Re-plan from synthesis, don't stream-merge decisions.** When N agents return, read all N and reconcile *conflicts* (incompatible contracts) before committing those; but **independent, non-conflicting units merge as they land** (§3). Prefer a framework/DB-enforced invariant a subagent surfaced (a deny-by-default check; an FK `ON DELETE` cascade) over a brittle hardcoded list.

**Two bounded loops:**
- **LOOP-UNTIL-GREEN:** build → run the unit's tests/typecheck/lint → on red, feed the **verbatim test failure** to a fixer (one tier lower) → re-run. **K = auto-fix attempts before escalating: default 3; 2 for shape-obvious units.** Repeated auto-fix on the same red is a spec/contract gap — STOP and escalate the failure + your hypothesis.
- **SKEPTIC PASS (opt-in, not reflexive):** for a risk-bearing unit, the lead runs ITS OWN fresh-context skeptic at the unit boundary. Trigger it **after a red finding, or on the single highest-risk unit** — NOT as a default loop on every boundary (that's theater and burns rate limits). One clean pass for reversible work; up to 2–3 for irreversible/mutating/secret/authz.

**The verify gate (`gg`) — runs ONCE, on the assembled whole diff, after green:**
- Mechanical first (tests/lint/typecheck), then the 3 Claude reviewers, then **Codex** (`/codex:review` routine; `/codex:adversarial-review` for any unit touching credentials/vault, authz/RBAC, command construction, untrusted-data egress, migrations, file upload, or a destructive/mutating path). **Codex runs once per feature — don't hammer it**, and leave its Stop-hook gate OFF. Read only its final result.
- Do **not** invoke the panel mid-loop. The boundary skeptic (above) is the lead's own, not the panel.

## 7. Note-taking & compaction

Persist `reports/loop-<feature>.md` **only when fan-out width ≥2 OR compaction is likely.** Store **IDENTIFIERS, not contents**: unit DAG + file-contention map; per-unit status (`pending→building→self-verified→panel-passed→merged`); open questions + **paths/queries to pull returns back on demand**; safety-rail decisions. Never paste full transcripts or diffs.

Use a **git-tracked** path for resumable state — NOT a git-ignored report subdir. The file may contain only credential *names* (§5.7). A re-invoked/compacted lead resumes from the file without re-deriving the DAG.

## 8. Smells

- **Theater spawn** — a subagent whose context the lead already holds or could cheaply load.
- **Stream-merge of conflicting work** — committing incompatible contracts without reconciling all N.
- **Auto-rollback assumption** — believing a failed apply self-heals; confirm your rollback model (§5.6).
- **Stale-base / un-refreshed-artifact green** — measuring green before rebase or the build/refresh step.
- **Split triad** — apply in one unit, rollback/checkpoint in another.
- **Secret in notes/returns/host-output** — any secret material or raw host-command output on disk or in a payload.
- **Down-tier creep** — running below the operator's chosen effort, or routing an auth/secret/command unit to the cheap tier because it "looks mechanical."
- **Two failed fan-outs** — when a boundary collides twice, STOP-LOSS: finish solo.

## Worked example (Webcart)

*The one place repo specifics live — your project's instance differs; the method above is what ports.*

**"Add partial refunds"** (extends the refund flow; **payment-mutating** ⇒ full rails). Deliberate, **high effort**.
1. **SHAPE** (familiar subsystem, lead maps edges itself — no scout). **U0** `packages/shared`: `PartialRefundRequest` + a new `OrderStatus` value + both barrels + parity test. **U1** `apps/api`: the refund service's partial path behind **idempotency-key + checkpoint + reversal**, reuse amount-validation, metadata-only audit. **U2** `apps/web`: the refund UI + confirm-on-irreversible. Edges U1→U0, U2→U0; **U1 ⊥ U2** (api vs web — a real seam). New status ⇒ a migration. **Checkpoint design:** a refund records a **`RefundLog` (metadata, never card data)** and is **idempotency-keyed** — re-invoking with the same key is a no-op, never a double refund.
2. **CONTRACT BARRIER.** ONE builder lands U0 (high) → returns diff → lead runs the parity test, commits the shared checkpoint, merges.
3. **FAN-OUT.** Lead spawns **U1 (high, Opus)** + **U2 (medium, Sonnet)** each with `isolation: "worktree"`; each asserts a distinct toplevel; neither commits. U1 green = unit tests **AND** the rail proof: dry-run/preview (no charge) → the refund records a `RefundLog` → re-invoking the same idempotency-key is a no-op → the processor's sandbox state reads back as refunded.
4. **SELF-VERIFY.** Lead pulls both diffs, **re-runs U1's rail proof itself**, runs one boundary skeptic on U1 ("any path double-charging or putting card data in a log/payload?"), spot-checks U2, scrubs notes.
5. **HANDOFF.** Whole diff → mechanical checks → Claude panel (`/pwnfactor:gg`) → **`/codex:adversarial-review`** (U1 payment-mutating + security-sensitive), once → **`/pwnfactor:validate`** against the staging oracle.

*Counterfactual A:* a new refunds **table** ⇒ split into **U0** (`packages/shared` contract) and a **separate `U-mig`** (`apps/api` Prisma migration + `migration.test.ts`) — two sequential barriers, never one unit (a shared unit must not own a server migration). Re-seed the demo DB after `U-mig` before U1 validates the live backend. *Counterfactual B:* if partial and full refund share one service function, they are **ONE unit** — collapse, don't fan out.

## Decision table

| Signals (size · risk · parallelizability · reversibility) | Topology | Effort × model | Panel |
|---|---|---|---|
| 1 unit · low · n/a · reversible (rename, field plumbing, leaf UI) | SOLO | medium × Sonnet | routine |
| 1 unit · low/med · n/a · reversible (clear precedent) | SOLO | high × Opus (Sonnet-high if pure boilerplate, no sensitive surface) | routine |
| 1 unit · HIGH · cohesive/novel (security refactor, tool-use loop, authz redesign) | **SOLO** (don't fragment) | **max × Opus** | adversarial |
| 1 unit · HIGH · **irreversible/mutating** | SOLO; triad indivisible | **max × Opus**; green = dry-run + checkpoint + **separate rollback restores, readback-verified** | adversarial |
| Multi-unit · disjoint (contract frozen) · reversible | **PIPELINE**, worktree per builder, merge as each lands | per-unit (backend Opus, UI Sonnet) | routine unless a unit is sensitive |
| Multi-unit · one unit security-sensitive | PIPELINE; lead's own boundary skeptic on that unit | that unit high/max × Opus | whole-diff, adversarial |
| Multi-unit · **new shared contract** | **Contract barrier (1 agent, merge) → pipeline consumers** | barrier high × Opus | per highest risk |
| Multi-unit · **needs a migration** | **Migration barrier (1 agent, explicit rev id, refresh) → fan out** | barrier high/max × Opus | adversarial |
| Any **single-slot component** (shared toolchain/build) | **that component = one slot** (never two agents) | per risk | per risk |
| Entangled (share a file / state machine) | **SOLO or strict SEQUENTIAL** (order by dependency) | high/max × Opus | per riskiest unit |
| Large/novel · **genuinely unmapped** | **Read-only SCOUTS first (no worktree) → synthesize → choose topology** | scouts high × Opus | decide after shape |

## Open tensions (operator-tunable)

- **K / R are defaults, not measured constants** — risk-scale per surface.
- **Width ~4 vs many disjoint units** — waves under one lead vs sub-leads (another untrusted distillation layer). Default to waves.
- **Worktree break-even** is machine-specific (worktree + per-tree dependency setup is non-trivial); below ~2 substantial parallel diffs, solo-sequential wins.
- **Max-effort × wide** is the most expensive cell — the operator sets the budget ceiling and whether the lead may PROPOSE a down-tier.
