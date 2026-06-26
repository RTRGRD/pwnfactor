# pwnfactor

A shared agentic engineering harness, distributed as a **Claude Code plugin** via this marketplace. Install it once per repo and every agent (and teammate) follows the same build-and-verify discipline.

## The three legs

The `pwnfactor` plugin adds three composable skills:

- **`/pwnfactor:run`** — the lifecycle spine: **Frame → Plan → Build → Verify → Integrate**. The default path for any non-trivial change.
- **`/pwnfactor:swarm`** — *deliberate* subagent orchestration (the **build loop**) for substantial features: how to decompose, choose topology (parallel / pipeline / solo), pick effort + model tier, and isolate parallel work. Invoked by choice — **not** an always-on mode.
- **`/pwnfactor:gg`** — a risk-routed multi-agent **verify gate**: independent code-review + simplifier + security Claude subagents, plus an optional Codex cross-model review, cross-checked into a single **ship / fix-then-ship / block** verdict.

Mental model: **orchestration is the build loop, the panel is the verify gate, both hang off the lifecycle spine.**

## Install (in any project)

```
/plugin marketplace add sleppelm/pwnfactor
/plugin install pwnfactor@pwnfactor
```

Skills then appear as `/pwnfactor:gg`, `/pwnfactor:run`, etc.

## Local development / testing (before pushing)

Test the plugin directly, no marketplace needed:

```
claude --plugin-dir ./plugins/pwnfactor
```

Or register this repo as a **local** marketplace:

```
/plugin marketplace add ./
/plugin install pwnfactor@pwnfactor
/reload-plugins        # re-run after each edit
```

## Pushing updates to the team

`version` in `plugins/pwnfactor/.claude-plugin/plugin.json` is **explicit**, so updates are predictable — commits without a version bump do **not** propagate (no surprise upgrades). To ship a change:

1. Edit the plugin.
2. Bump `version` (semver).
3. Commit + push.
4. Teammates run `/plugin marketplace update pwnfactor`.

## Onboarding a new project

Run **`/pwnfactor:boot`** — it interviews the repo and sets up the orchestration profile, the `CLAUDE.md` gate contract, and CI, then teaches the three commands and proves value on a real diff.
