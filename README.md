# pwnfactor

A shared agentic engineering harness, distributed as a **Claude Code plugin** via this marketplace. Install it once per repo and every agent (and teammate) follows the same build-and-verify discipline.

## The three legs

The `pwnfactor` plugin adds three composable skills:

- **`/pwnfactor:run`** - the lifecycle spine: **Frame → Plan → Build → Verify → Integrate**. The default path for any non-trivial change.
- **`/pwnfactor:swarm`** - *deliberate* subagent orchestration (the **build loop**) for substantial features: how to decompose, choose topology (parallel / pipeline / solo), pick effort + model tier, and isolate parallel work. Invoked by choice - **not** an always-on mode.
- **`/pwnfactor:gg`** - a risk-routed multi-agent **verify gate**: independent code-review + simplifier + security Claude subagents, plus an optional Codex cross-model review, cross-checked into a single **ship / fix-then-ship / block** verdict.

Mental model: **orchestration is the build loop, the panel is the verify gate, both hang off the lifecycle spine.**

## The rest of the loadout

Around that core sit four supporting skills:

- **`/pwnfactor:boot`** - onboard a repo once: it builds the orchestration profile, the `CLAUDE.md` gate contract, CI, and the security toolchain, then proves value on a real diff.
- **`/pwnfactor:validate`** - the proof gate: check a change against a **ground-truth oracle** (did the REAL thing accept it?), not just review the diff. A green test suite is a claim until the real runtime, staging URL, or data store confirms it.
- **`/pwnfactor:sweep`** - a read-only **pre-prod security battery**: stack-aware static scan, SBOM + CVE, secret scan, optional Codex adversarial review, and (for a shipping binary) a local-AV-gated malware-reputation check, ending in GO / NO-GO.
- **`/pwnfactor:ci`** - wire and verify CI/CD: tests tailored to your stack, an actor-gated `@claude` handler, and a weekly security scan.
- **`/pwnfactor:cards`** - **system cards**: a versioned, per-subsystem decision-and-contract layer (contract, invariants, consumers, decisions with the WHY, known traps) with an auto-loaded index and a staleness checker that fails loudly when a card goes out of date. Sessions stop re-deriving decisions the repo already made.
- **`/pwnfactor:help`** - the loadout screen: every command, what it does, when to use it, and how the pieces fit into one lifecycle.

## Install (in any project)

```
/plugin marketplace add RTRGRD/pwnfactor
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

`version` in `plugins/pwnfactor/.claude-plugin/plugin.json` is **explicit**, so updates are predictable - commits without a version bump do **not** propagate (no surprise upgrades). To ship a change:

1. Edit the plugin.
2. Bump `version` (semver).
3. Commit + push.
4. Teammates run `/plugin marketplace update pwnfactor`.

## Onboarding a new project

Run **`/pwnfactor:boot`** - it interviews the repo and sets up the orchestration profile, the `CLAUDE.md` gate contract, CI, and the security toolchain, then teaches the full command loadout and proves value on a real diff.
