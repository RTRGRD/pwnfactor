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
- Run `/pwnfactor:gg` on the diff. Address CRITICAL/HIGH before integrating.
- Run `/pwnfactor:validate` to prove the change ACTUALLY works against the ground-truth oracle (not just that the diff is good or tests passed) - it writes the `.pwnfactor/gate.json` artifact the Stop-hook enforces. (Needs `ground_truth_oracle:` in the profile.)
- Run the project's real tests/lint. Capture the **actual command and output** - never claim a green you didn't see.

### 5. Integrate
- **Before a production push or big build, OFFER `/pwnfactor:sweep`** (the pre-prod security audit) - the operator decides whether to run it.
- Commit (single agent / integration phase only). Describe the change, not the tooling.
- Report what you ran and what it produced. If verification was impossible (missing toolchain, Docker down), say so plainly - don't imply success.

## See also
- `risk-tiers.md` - the risk rubric used here and by the panel.
- `model-economics.md` - **where to spend the frontier main-loop model vs tier subagents down**
  (operator directive 2026-07-02: best results for the least money; never silent model inheritance;
  operator-requested audits stay in the main loop, routine reviews tier down).
- `documentation-standards.md` - writing docs/comments without burning tokens.
- `swarm` - the build-loop playbook (deliberate subagent fan-out).
- `gg` - the verify gate.
