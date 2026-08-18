---
name: run
description: The default lifecycle for any non-trivial change - Frame, Plan, Build, Verify, Integrate. Sets the risk tier, points to the orchestration playbook for the build loop and the review panel for the verify gate, and enforces safety rails (dry-run/checkpoint/rollback, worktree isolation, no parallel commits). Use when starting a feature, fix, or refactor beyond a trivial size, or when the user asks how to approach a change.
---

# Feature Workflow

> **Say this first:** "`/pwnfactor:run` is the standard path for any real change - Frame, Plan, Build, Verify, Ship. Use it whenever a change has design choices, multiple files, or risk."

The spine every non-trivial change follows. Five phases; two delegate to sibling skills - **Build** uses `swarm`, **Verify** uses `gg` (is-the-diff-good) **+ `validate`** (does-it-actually-work).

Trivial change (typo, one-liner, obvious fix)? Skip this and just do it. This is for anything with design choices, multiple files, or risk.

```
- [ ] 1. Frame     - what & why, done-criteria, risk tier
- [ ] 2. Plan      - approach, files, decompose, sign-off if non-obvious
- [ ] 3. Build     - implement (solo or orchestrated); self-verify as you go
- [ ] 4. Verify    - review panel (`gg`) + prove-it-works (`validate`); tests green
- [ ] 5. Integrate - commit, report exactly what you ran and saw
```

### 1. Frame
- State the change and the why in 2-3 lines. Define done-criteria (what proves it works).
- Set the **risk tier** now (`risk-tiers.md`) - it drives effort, orchestration, and how hard the panel reviews.
- Read the project's `CLAUDE.md` / `AGENTS.md` and relevant feature docs before touching code.

### 2. Plan
- Sketch the approach and files to touch. For real design choices or >2-3 files, get operator sign-off (plan mode) before building.
- Decide **solo vs orchestrated** (`swarm`): most changes are solo; fan out only when the work splits into genuinely parallel-safe units and the coordination earns its cost.
- If the change crosses a shared contract (`packages/shared` or equivalent), coordinate that surface first.

### 3. Build
- **Solo:** implement directly, matching surrounding idioms. Keep a running note of decisions/open items for long features (so context stays compaction-friendly).
- **Orchestrated:** follow `swarm` - worktree isolation for parallel mutation, no commits from parallel agents.
- **Self-verify continuously:** run the narrowest test/build that proves each step. Don't accumulate unverified work.
- **Safety rails (hard):** any fleet- / host- / data-mutating capability ships with dry-run + per-unit checkpoint + rollback. No exceptions.

### 4. Verify
- Run `/pwnfactor:gg` on the diff - it scales review depth to the footprint on a five-rung ladder
  (docs-only skips, a mechanical diff gets Codex alone, small real-logic gets Codex + 1, a feature
  gets the panel, any HIGH signal goes adversarial regardless of size). You do not pick the depth;
  gg reads the diff and picks it. Address CRITICAL/HIGH before integrating.
- Run `/pwnfactor:validate` to prove the change ACTUALLY works against the ground-truth oracle (not just that the diff is good or tests passed) - it writes the `.pwnfactor/gate.json` artifact the Stop-hook checks (the hook verifies A gate passed for this
  exact content - it cannot tell a review from an oracle validation, so running BOTH here is the discipline that
  makes the gate mean anything). (Needs `ground_truth_oracle:` in the profile.)
- Run the project's real tests/lint. Capture the **actual command and output** - never claim a green you didn't see.

### 5. Integrate
- **Before a production push or big build, OFFER `/pwnfactor:sweep`** (the pre-prod security audit) - the operator decides whether to run it.
- Commit (single agent / integration phase only). Describe the change, not the tooling.
- **Documentation wrap-up - non-optional when the change is major.** A change that alters
  architecture, contracts, guarantees, or scope is NOT integrated until the project's governing
  documents assert the new facts too: update the docs that state what changed, follow the
  project's amendment ritual if it defines one, then GREP for dependents and read every hit -
  the same fact usually lives in several places (a spec, an architecture reference, a harness
  profile, a CI config, the reason string on a skipped test), and amending only the definition
  leaves the rest asserting the old world with full authority. A doc update the operator has to
  ask for is a doc update that was late.
  **If the repo has system cards** (a `cards/` directory - see `../cards/SKILL.md`): a change
  that touched a carded subsystem's contract, invariant, decision, or known trap updates THAT
  CARD in the same commit, and `tools/card_check.py` runs green before integrate. Routine
  changes that alter none of those touch no card - cards are contracts, not a changelog.
- **Antipattern harvest.** Before closing, ask: did anything here survive a plausible-looking
  check, and would it recur? If the project keeps an antipattern log, write the entry NOW -
  symptom, why it bites, what to do instead, where it was found. Closing a unit includes this
  question; green tests alone do not close it.
- Report what you ran and what it produced. If verification was impossible (missing toolchain, Docker down), say so plainly - don't imply success.

## Long-horizon work: checkpoint each phase

A run spanning hours or many units does NOT execute end to end and report at the finish. Break it
into phases and close each one before opening the next:

1. **State the phase's done-criteria before starting it** - what evidence will show it worked.
2. **Validate against that evidence, not against "the code looks finished."** A phase that cannot
   show its evidence is not done; say so and stop rather than rolling forward.
3. **Compress and hand the checkpoint forward** - what landed, what it cost, what is carried, and
   any agent ids still live. A few lines, not a transcript. This is what survives compaction.
   A checkpoint that changed architecture or scope carries its documentation wrap-up WITH it -
   batching doc updates to the end of a long run is how canon drifts mid-run.
4. **Never begin a phase whose predecessor is unvalidated.** A failure discovered three phases later
   costs all three.

The checkpoint is also where reuse happens: it is the record of which subagents already hold which
context, so the next phase continues them instead of paying for a cold start.

## See also
- `risk-tiers.md` - the risk rubric used here and by the panel.
- `model-economics.md` - **where to spend the frontier main-loop model vs tier subagents down**
  (operator directive 2026-07-02: best results for the least money; never silent model inheritance;
  operator-requested audits stay in the main loop, routine reviews tier down).
- `documentation-standards.md` - writing docs/comments without burning tokens.
- `swarm` - the build-loop playbook (deliberate subagent fan-out).
- `gg` - the verify gate.
