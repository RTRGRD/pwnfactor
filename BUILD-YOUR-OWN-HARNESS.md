# Build your own pwnfactor-style harness for THIS repo

Paste this whole file as a prompt to a Claude Code agent running **in the target repo**, with the reference `pwnfactor` plugin available at a path you provide. The agent studies the proven structure, then builds a **bespoke** engineering-harness plugin tailored to THIS repo - carrying none of the reference project's internals.

---

## Your mission
Build a Claude Code **plugin** (a self-contained marketplace) packaging THIS repo's engineering discipline: a feature lifecycle, deliberate subagent orchestration, a risk-routed multi-agent review panel, a ground-truth validation gate, interactive onboarding, and (if applicable) a pre-prod security sweep. Model it on the reference harness `pwnfactor` at `<PATH-TO-PWNFACTOR-REPO>` - copy its **structure and method, NOT its content**. Every example, barrier, and path must come from THIS repo.

## Reference (study first; do not copy verbatim)
Read `<PATH>/plugins/pwnfactor/`:
- `skills/{boot,run,swarm,gg,validate,sweep}/SKILL.md` - the skills + their method.
- `agents/*.md` - the review-panel reviewers.
- `skills/boot/orchestration-profile.template.md` - the per-project profile schema.
- `hooks/` - the fail-open stop-hook gate. `ci/` + `.github/workflows/` - portable CI. `scripts/validate_plugin.py` - the validator.

The reference is another project's instance. **Treat its specifics (component names, file paths, migration numbers, the rollback model) as examples to REPLACE, not facts.**

## Step 1 - Inspect THIS repo (never ask what you can detect)
Stack; component layout + the parallel-safe seams; shared-contract location + sync rule; migration ritual; the mutation/rollback model + safety rails; hotspot files; single-slot constraints (shared toolchain/build); test/lint/typecheck commands; CI; git host. Read `CLAUDE.md`/`AGENTS.md` if present.

## Step 2 - Interview the operator for the gaps only
What's *risky* here (auth / secrets / money / data-mutating / migrations); solo or team; GitHub?; the plugin name (default `<repo>-harness`).

## Step 3 - Decisions (recommend, then confirm)
- **Packaging:** plugin + marketplace (team can `/plugin install`).
- **Review-panel cost: risk-routed** - routine diffs = Sonnet panel + regular Codex; high-risk (auth/secrets/migrations/mutating) = Opus panel + adversarial Codex.
- **CI:** always-on tests + on-demand `@claude` (**actor-gated**).

## Step 4 - Build the plugin (tailored to THIS repo)
Layout (forward slashes; ONLY `plugin.json` in `.claude-plugin/`; skills/agents/hooks at plugin root; plugin skills namespace as `/<plugin>:<skill>`):
```
<repo>-harness/
  .claude-plugin/marketplace.json
  plugins/<name>/
    .claude-plugin/plugin.json
    skills/<onboard|lifecycle|orchestrate|review|validate|sweep>/SKILL.md
    agents/<code-review|simplifier|security>.md
    hooks/hooks.json + gate-check.py        # optional gate
    ci/...
  scripts/validate_plugin.py
```
1. **marketplace.json + plugin.json** - your plugin name + description.
2. **Orchestration profile** - fill `.claude/orchestration-profile.md` in THIS repo from Step 1 (components/seams, shared-contract barrier, migration ritual, mutation/rollback model, hotspots, single-slot constraints, build/refresh, test commands, risk signals). This makes the harness correct *here*.
3. **Skills** (SKILL.md each <500 lines; third-person triggered `description`; references one level deep):
   - **onboard** - inspect → set up profile/CI/contract/toolchain → teach → prove on a real diff.
   - **lifecycle** - Frame → Plan → Build → Verify → Integrate.
   - **orchestrate** - deliberate subagent fan-out: **default SOLO for *mutating* work**; **read-only fan-out (scouts/research/skeptics) is the lead's free discretion**; worktree isolation (`isolation:"worktree"`); builders never `git commit`; barriers serialize shared-contract + migration units; **don't trust subagent output - re-verify load-bearing claims against the code**; pipeline-merge ready units; hand a green diff to the review gate. Load specifics from the profile.
   - **review** (the panel) - classify risk → fan out 3 reviewers (code-review/simplifier/security) **in parallel** on the diff → optional Codex (`/codex:review` or `/codex:adversarial-review` for high-risk) → dedupe + cross-verify (a finding survives only if it holds against the code) → **ship / fix-then-ship / block** + written report.
   - **validate** (the proof gate) - prove the change WORKS against a project-defined ground-truth oracle (the real runtime / staging / data-store accepts it), not just that the diff reads right. The differentiator over a pure code review; bind the oracle at onboard.
   - **sweep** (only if you have a security battery) - pre-prod; offered before prod/big builds; GO/NO-GO; read-only.
4. **Agents** - code-review (logic bugs / races / boundaries / contract drift), simplifier (reuse / dead code / altitude - NOT bug-hunting), security (injection / authz / secrets / traversal / rails). Read-only tools; `model: inherit` (the panel chooses the tier).
5. **CI** - a reusable workflow (auto-detect this stack's test/lint) + an `@claude` handler **gated to trusted actors** (`OWNER`/`MEMBER`/`COLLABORATOR`) with least-privilege permissions.
6. **Optional gate** - the review writes a small gate artifact; a **fail-open, loop-safe** Stop hook nudges on a stop with unreviewed code changes (guard on `stop_hook_active`, honor a bypass env var, allow on ANY error).

## Hard lessons to honor (learned the expensive way)
- **Verify load-bearing claims against the actual code.** An adversarial critic can be confidently wrong; a cross-model (Codex) check caught a rollback-model bug three Claude reviewers had blessed. If a finding rests a merge/safety call, re-run its proof.
- **`@claude` CI must be actor-gated.** An ungated `@claude` trigger on a public/forkable repo is a write-scoped, key-bearing run any commenter can fire via prompt injection.
- **Token-efficient docs:** assume the reader is smart; progressive disclosure; SKILL.md <500 lines; references one level deep; third-person triggered descriptions; no time-sensitive phrasing.
- **Plugin gotchas:** only `plugin.json` in `.claude-plugin/`; everything else at plugin root; agents support `name/description/tools/model` but NOT `hooks/mcpServers/permissionMode`.
- **Codex:** prefer the official `openai/codex-plugin-cc` plugin; run it **once per feature**, never hammer it (rate limits), leave its Stop-gate OFF.
- **Effort ≠ topology:** high/max reasoning effort means *think harder*, not *spawn a mutating swarm*.

## Step 5 - Dogfood it (verify, don't claim green)
Run YOUR new review panel (3 reviewer agents in parallel + Codex if available) **on the new plugin itself**. Fix every CRITICAL/HIGH. Then validate: JSON parses; every SKILL.md has a `description` and is <500 lines; agents have `name`+`description`; no broken cross-references; **no leftover content from the reference project**. Test: `claude --plugin-dir ./plugins/<name>` → run the onboarding skill.

## Step 6 - Report
What you built, the command list, how to install (`--plugin-dir` or marketplace), and what's left. Keep the reference project's name out of every file.
