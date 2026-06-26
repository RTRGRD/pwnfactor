# Risk tiers

One classification, used everywhere: it sets reasoning effort, whether to orchestrate, the review panel's model tier, and whether Codex runs adversarially. **When in doubt, treat as HIGH.**

## Signals → tier

A change is **HIGH** risk if it touches any of:
- Authentication / authorization, session or token logic
- Credentials, secrets, keys, vault, crypto
- Database migrations; schema or shared-contract changes (e.g. `packages/shared` pydantic ↔ TS)
- Fleet- / host- / data-mutating actions; deletes; payments; anything irreversible
- Parsing or deserializing untrusted input; shell-out; dynamic SQL; file / path / symlink handling
- Anything explicitly named a safety rail in the project's `CLAUDE.md` / rules

Otherwise it is **ROUTINE**: UI, internal refactors, docs, additive pure functions, test-only changes.

## What the tier drives

| Dimension | ROUTINE | HIGH |
|---|---|---|
| Reasoning effort | medium-high | high-max |
| Review-panel model | Sonnet | Opus |
| Codex review | regular (if available) | adversarial (if available) |
| Panel verdict bar | block on CRITICAL | block on CRITICAL **or** HIGH on the risky surface |
| Safety rails | as applicable | dry-run + checkpoint + rollback, always, for any mutation |
| Orchestration | usually solo | decompose only if parallel-safe; isolate in worktrees |

## Notes
- Tier is about **blast radius and reversibility**, not size. A 3-line change to an authz check is HIGH; a 300-line UI refactor is ROUTINE.
- A change can be mostly ROUTINE with one HIGH file - tier the **riskiest** surface and review that part at HIGH.
