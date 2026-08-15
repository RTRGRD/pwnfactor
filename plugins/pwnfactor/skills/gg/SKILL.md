---
name: gg
description: Risk- and footprint-routed multi-agent code review for a finished change. Scales review depth to the diff (docs-only skips, small routine diffs get one reviewer, real features get the 3-reviewer panel, risky surfaces get an Opus panel plus adversarial Codex), cross-verifies and dedupes findings, and returns a ship / fix-then-ship / block verdict with a written report. Use after completing a feature, before merging, or when the user asks for a "review panel", "panel review", or "pre-merge review".
---

# Review Panel

> **Say this first:** "`/pwnfactor:gg` is the review gate - three Claude reviewers plus Codex tear through your diff and return ship / fix-then-ship / block. Run it before you merge."

The **verify gate** for a completed change: three independent Claude reviewers plus an optional cross-model (Codex) reviewer, cross-checked and deduped into one verdict. Never trust a single reviewer's raw output - a finding ships only if it survives verification against the actual code.

This is the counterpart to `swarm` (the build loop). Both hang off `run`.

## Workflow

Copy this checklist and work it top to bottom:

```
Review Panel:
- [ ] 1. Scope the diff (base ref + changed files)
- [ ] 2. Classify risk + footprint -> pick DEPTH (SKIP / SOLO / PANEL / ADVERSARIAL)
- [ ] 3. Run the depth's reviewers (parallel, on the tier's model)
- [ ] 4. Codex cross-model review (per depth, if available)
- [ ] 5. Cross-verify + dedupe findings
- [ ] 6. Verdict + written report
```

### 1. Scope the diff
- Default base: the merge-base with the main branch - `git merge-base HEAD <main>` then `git diff <base>...HEAD`. Fall back to `git diff HEAD~1` for a single-commit change. Ask only if the base is genuinely ambiguous.
- Summarize what changed (files, surfaces) in 2-3 lines. If the diff is empty, stop and say so.

### 2. Classify risk → pick tier
Apply this compact rubric (canonical, fuller version: `run/risk-tiers.md`):

| Signal present in the diff | Tier |
|---|---|
| Auth / authz, credentials / secrets / vault, crypto | HIGH |
| DB migrations, schema or shared-contract changes (e.g. `packages/shared`) | HIGH |
| Fleet- / host- / data-mutating actions, deletes, payments, anything irreversible | HIGH |
| Untrusted input parsing, deserialization, shell-out, dynamic SQL, file/path handling | HIGH |
| Everything else (UI, internal refactors, docs, additive pure functions) | ROUTINE |

**ROUTINE → Sonnet reviewers + regular Codex. HIGH → Opus reviewers + adversarial Codex. When in doubt, treat as HIGH.**

**Then scale the DEPTH to the footprint.** Risk sets the model tier; footprint sets how many
reviewers run. Review effort is proportional to what could break - the full panel on every small
diff is theater that burns tokens and rate limits:

| Depth | When | What runs |
|---|---|---|
| **SKIP** | docs / comments / config-typo only; no executable code changed | no reviewers. Note "depth: skip (docs-only)" in chat; still write the gate artifact (verdict `ship`) |
| **SOLO** | ROUTINE, small (roughly <=50 changed lines), one surface, zero HIGH signals | ONE reviewer, and prefer **Codex** (regular review) - it costs zero Claude tokens (`run/model-economics.md`). Only if Codex is unavailable (health-check verified, never assumed) fall back to one `panel-code-review` subagent on the tier's model. No simplifier/security either way |
| **PANEL** | any real feature: multi-file, new surface, or nontrivial logic (ROUTINE) | all 3 reviewers + regular Codex - the default for finished features |
| **ADVERSARIAL** | ANY HIGH signal, regardless of size (a 3-line authz change is ADVERSARIAL) | all 3 reviewers on Opus + adversarial Codex; every CRITICAL/HIGH finding verified against the code |

Rules: a HIGH signal always forces ADVERSARIAL - size never argues down past a risk signal. When
unsure between two depths, round UP one. The operator explicitly asking for a review/audit is a
floor of PANEL (they asked for eyes; give them eyes). SOLO/SKIP exist so that PANEL and
ADVERSARIAL stay affordable where they matter.

### 3. Run the depth's reviewers (parallel, isolated context)
At SKIP there is nothing to spawn - write the gate and stop. At SOLO the single reviewer is
Codex (step 4) - spawn `panel-code-review` only as the verified-unavailable fallback. At
PANEL/ADVERSARIAL spawn all three:
Spawn the depth's subagents **in parallel** via the Agent tool, each with `model` set EXPLICITLY to
the tier's model (ROUTINE = `sonnet`, HIGH = `opus`) - never omit `model:` (it silently inherits
the main-loop model; on a frontier main loop that burns the metered budget - `run/model-economics.md`).
**Reasoning effort rides in each agent's frontmatter, not the call** (code-review and security run
`effort: high`, the simplifier `effort: medium`); extended thinking has no per-agent toggle, so the
`effort:` field is the depth dial. The dials compose per depth: SOLO's fallback reviewer =
tier-model x its frontmatter effort; PANEL = `sonnet` x frontmatter; ADVERSARIAL = `opus` x
frontmatter - the model escalates with risk, the effort profile stays per-role.
The frontier main loop ADJUDICATES the panel's findings; it does not sit on the panel, EXCEPT when
the operator explicitly asked for an audit/deep review - that judgment work stays in the main loop.
Give each reviewer only the **diff scope** (base ref + changed files + your 2-3 line summary) - not
the whole repo; they explore from there.

- `panel-code-review` - correctness, bugs, races, boundaries, contract drift, anti-regression rules.
- `panel-simplifier` - reuse, dead code, premature abstraction, altitude. Quality only; it does not hunt bugs.
- `panel-security` - injection, authz, secret handling, traversal, SSRF, resource leaks, project safety rails.

Each returns a **distilled** findings list (severity, `file:line`, one-line fix), not a transcript.

### 4. Codex cross-model review - per depth, if available
Codex runs at SOLO (regular - as the sole reviewer, saving Claude tokens), PANEL (regular), and
ADVERSARIAL (adversarial); it is skipped only at SKIP. At SOLO, Codex findings still get step
5's scrutiny - a sole reviewer is still a lead, not a fact.
Codex (OpenAI, GPT-5.x) is a different model family, so it catches a different class of mistakes. **Prefer the official OpenAI Codex plugin** (`openai/codex-plugin-cc`, commands `/codex:*`) when installed; fall back to the `codex` CLI skill; otherwise skip.
- **Plugin installed** → ROUTINE: `/codex:review` (auto-detects the diff; `--base <merge-base>` for a branch). HIGH: `/codex:adversarial-review` with a focus line (e.g. "focus on the auth/vault/migration surface; try to refute this change"). Fetch the result with `/codex:result`.
- **CLI skill only** → `/codex code-review`, run headless ("no window").
- **Neither** → **skip silently** (solo-mode friendly) and note the skip in the report.

Read only Codex's final result - don't tail it. Never block the panel on Codex.

### 4b. Re-review after fixes - CONTINUE, never respawn
When findings are applied and the diff needs another look, or when a change lands on a surface an
earlier reviewer already covered, **`SendMessage` the reviewers that ran before** instead of
spawning new ones - a completed agent auto-resumes in the background with its full history, so
this costs one message, not a re-read of the repo. They hold the diff, the constraints and their
own findings - so they can say
whether a fix actually addressed the thing they raised, which a fresh agent structurally cannot.
Respawn only for a genuinely different surface, or when an independent second opinion is the point.
See `run/model-economics.md`, "the second mechanical rule".

### 5. Cross-verify + dedupe (don't trust raw output)
- Merge all findings; dedupe by `(file, line, issue)`.
- For every **CRITICAL/HIGH** finding, open the actual code and confirm it before reporting. Drop anything you can't substantiate; demote speculative items to a "worth a look" list. Subagent output is a **lead, not a fact**.
- Surface genuine disagreements explicitly (reviewer vs reviewer, Claude vs Codex) - don't silently pick a side.

### 6. Verdict + report
Severities: **CRITICAL** (breaks prod) / **HIGH** (breaks a real workflow) / **MEDIUM** (smell or future bug) / **NIT** (style).

Verdict:
- **block** - any unaddressed CRITICAL, or a HIGH on a high-risk surface.
- **fix-then-ship** - HIGH/MEDIUM worth fixing but not merge-blockers once addressed.
- **ship** - only NITs, or clean.

Write the report to the project's reports directory (default `reports/`, create it if absent) as `review-<short-desc>-<base-sha>.md`, including: scope, tier, DEPTH chosen and why, per-reviewer findings, the deduped verdict, and the exact diff range reviewed. Then report the verdict + top findings in chat and offer to apply fixes. (SKIP-depth reviews write no report file - the chat note and gate artifact are the record.)

**Gate artifact (for the ultracode stop-hook).** Also write `.pwnfactor/gate.json`: `{"head": "<current HEAD sha>", "verdict": "ship|fix-then-ship|block", "ts": "<iso8601 UTC>"}`. The stop-hook treats a **ship** or **fix-then-ship** verdict whose `head` matches the current commit as a passing gate; **block**, or a stale/missing artifact, means the gate hasn't passed.

## Notes
- **Read-only by default.** The panel reviews; it does not edit. Apply fixes only when the operator says go.
- **Parallel build context:** if this runs inside a multi-agent build, leave commits to the integration phase - parallel agents must not commit (index-lock races).
- **Cost:** the tier controls the model; the DEPTH controls how many reviewers run. A docs-only diff is SKIP, a small routine diff is SOLO (Codex-first - zero Claude tokens) - the full panel is for real features, the adversarial panel for risk. Depth never argues down past a HIGH signal.
- **Codex setup & limits:** see `codex-integration.md`. Leave the Codex plugin's Stop-hook review-gate **OFF** (`/codex:setup`) - it loops and drains usage limits; the panel calls Codex explicitly, once per feature, after mechanical checks pass.
